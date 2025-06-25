#!/usr/bin/env python3
import os
import sys
import time
import threading
from datetime import datetime
from typing import Optional, Tuple, Dict, Any
import subprocess
import json
import queue
import shutil

import cv2

# Add the src directory to the Python path so we can import our modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from utils import (
    logger,
    supabase,
    queue_upload,
    get_upload_queue,
    clear_upload_queue,
    cleanup_temp_files,
    update_system_status,
    get_storage_used,
    remove_booking,
    save_booking
)
from config import (
    CAMERA_ID,
    RECORD_WIDTH,
    RECORD_HEIGHT,
    RECORD_FPS,
    RECORDING_DIR,
    TEMP_DIR,
    MAX_RECORDING_DURATION,
    UPLOAD_DIR,
    USER_ID,
    LOGO_PATH,
    TRADEMARK_PATH,
    INTRO_VIDEO_PATH
)
from camera_interface import CameraInterface

class CameraService:
    def __init__(self):
        self.camera = None
        self.is_recording = False
        self.current_file = None
        self.recording_start = None
        self.upload_thread = None
        self.stop_event = threading.Event()
        self.intro_video_path = None
        self.interface = None
        self.upload_worker_thread = None
        self.upload_worker_running = False
        self.upload_worker_watchdog_thread = None
        self.upload_queue_lock = threading.Lock()
        self.upload_queue_file = os.path.join(TEMP_DIR, "upload_queue.json")
        self.upload_queue = self._load_upload_queue()
        self.file_booking_map = self._load_file_booking_map()
        self.current_booking: Optional[Dict[str, Any]] = None
        self.logo_cache: Dict[str, Any] = {}
        self._start_upload_worker()
        # The watchdog is problematic for graceful shutdowns, so it's disabled.
        # self._start_upload_worker_watchdog()
        logger.info("[Upload Worker] Upload worker thread started at service init.")

    def start_camera(self) -> bool:
        """Initialize and start the camera using CameraInterface."""
        try:
            self.interface = CameraInterface(
                width=RECORD_WIDTH,
                height=RECORD_HEIGHT,
                fps=RECORD_FPS,
                output_dir=TEMP_DIR
            )
            self.camera = self.interface  # for backward compatibility
            logger.info("CameraInterface initialized successfully")
            return True
        except Exception as e:
            logger.error(f"Error starting camera: {e}")
            return False

    def get_intro_video(self) -> Optional[str]:
        """Download intro video from Supabase storage."""
        try:
            # Get user settings to find intro video path
            response = supabase.table("user_settings").select("intro_video_path").eq(
                "user_id", USER_ID
            ).single().execute()
            
            if not response.data or not response.data.get("intro_video_path"):
                return None
                
            intro_path = response.data["intro_video_path"]
            local_path = os.path.join(TEMP_DIR, "intro.mp4")
            
            # Download intro video
            with open(local_path, "wb") as f:
                response = supabase.storage.from_("usermedia").download(intro_path)
                f.write(response)
                
            return local_path
            
        except Exception as e:
            logger.error(f"Error getting intro video: {e}")
            return None

    def attach_intro_video(self, recording_path: str) -> Optional[str]:
        """Attach intro video to the recording."""
        try:
            if not self.intro_video_path:
                self.intro_video_path = self.get_intro_video()
                
            if not self.intro_video_path:
                return recording_path
                
            # Create output path
            output_path = os.path.join(
                TEMP_DIR,
                f"final_{os.path.basename(recording_path)}"
            )
            
            # Use ffmpeg to concatenate videos
            cmd = [
                "ffmpeg", "-y",
                "-i", self.intro_video_path,
                "-i", recording_path,
                "-filter_complex", "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[outv][outa]",
                "-map", "[outv]",
                "-map", "[outa]",
                output_path
            ]
            
            subprocess.run(cmd, check=True, capture_output=True)
            
            # Remove original recording
            os.remove(recording_path)
            
            return output_path
            
        except Exception as e:
            logger.error(f"Error attaching intro video: {e}")
            return recording_path

    def start_recording(self, booking: Dict[str, Any]) -> bool:
        """Start recording video using CameraInterface."""
        if self.is_recording:
            logger.warning("Already recording.")
            return False
        if not self.interface:
            logger.error("Camera interface not initialized.")
            return False
            
        try:
            self.current_booking = booking
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"recording_{timestamp}_{booking['id']}.mp4"
            
            self.interface.start_recording(filename)
            self.is_recording = True
            self.recording_start = time.time()
            if booking['id']:
                self.file_booking_map[filename] = booking['id']
                logger.info(f"[Booking Map] Associated {filename} with booking {booking['id']}")
            try:
                update_system_status(is_recording=True)
            except Exception as e:
                logger.error(f"Error updating system status after start_recording: {e}", exc_info=True)
            logger.info(f"Started recording for booking {booking['id']} to file {filename}")
            return True
        except Exception as e:
            logger.error(f"Error starting recording: {e}", exc_info=True)
            return False

    def stop_recording(self) -> bool:
        """Stop recording and queue file for upload."""
        if not self.is_recording or not self.interface:
            logger.warning("stop_recording called but not recording or camera interface not initialized")
            return False
        try:
            logger.info("[Camera] Beginning recording stop process")
            self.is_recording = False
            raw_video_path = self.interface.stop_recording()
            self.interface.release()
            logger.info("[Camera] Recording stopped")
            
            if raw_video_path and os.path.exists(raw_video_path):
                logger.info(f"[Camera] Processing recording file: {raw_video_path}")
                if os.path.exists(raw_video_path):
                    size = os.path.getsize(raw_video_path)
                    logger.info(f"[Camera] Recording file exists, size: {size} bytes")
                    
                    # Wait a moment to ensure file is fully written
                    time.sleep(2)
                    
                    try:
                        # Try to attach intro video
                        final_path = self.attach_intro_video(raw_video_path)
                        if final_path and os.path.exists(final_path):
                            logger.info(f"[Camera] Final video created at: {final_path}")
                            booking_id = self.file_booking_map.get(raw_video_path)
                            if booking_id:
                                logger.info(f"[Camera] Adding to upload queue with booking ID: {booking_id}")
                                self.add_to_upload_queue(final_path, booking_id)
                                logger.info(f"[Camera] Successfully queued for upload: {final_path}")
                            else:
                                logger.error(f"[Camera] No booking ID found for file: {raw_video_path}")
                        else:
                            logger.error(f"[Camera] Failed to create final video from: {raw_video_path}")
                    except Exception as e:
                        logger.error(f"[Camera] Error processing recording: {str(e)}", exc_info=True)
                else:
                    logger.error(f"[Camera] Recording file does not exist: {raw_video_path}")
            else:
                logger.warning("[Camera] No current file to process after recording")
            
            # Update status
            try:
                update_system_status(is_recording=False)
                logger.info("[Camera] System status updated to not recording")
            except Exception as e:
                logger.error(f"[Camera] Error updating system status: {str(e)}", exc_info=True)
            
            # Clear recording state
            self.current_file = None
            self.recording_start = None
            self.current_booking = None
            
            remove_booking()
            
            return True
        except Exception as e:
            logger.error(f"[Camera] Error in stop_recording: {str(e)}", exc_info=True)
            return False

    def _start_upload_worker(self):
        if self.upload_worker_thread is None or not self.upload_worker_thread.is_alive():
            self.upload_worker_running = True
            self.upload_worker_thread = threading.Thread(target=self.upload_worker, daemon=True)
            self.upload_worker_thread.start()
            logger.info("[Upload Worker] Upload worker thread (re)started.")

    def _start_upload_worker_watchdog(self):
        if self.upload_worker_watchdog_thread is None or not self.upload_worker_watchdog_thread.is_alive():
            self.upload_worker_watchdog_thread = threading.Thread(target=self.upload_worker_watchdog, daemon=True)
            self.upload_worker_watchdog_thread.start()
            logger.info("[Upload Worker] Watchdog thread started.")

    def upload_worker_watchdog(self):
        while True:
            time.sleep(10)
            if self.upload_worker_thread is None or not self.upload_worker_thread.is_alive():
                logger.error("[Upload Worker] Upload worker thread is dead! Restarting...")
                self._start_upload_worker()
            else:
                logger.debug("[Upload Worker] Watchdog: upload worker is alive.")
            logger.debug(f"[Upload Worker] Watchdog: upload queue state: {self.upload_queue}")

    def _load_upload_queue(self):
        # This method should return a queue object, not a list.
        q = queue.Queue()
        if os.path.exists(self.upload_queue_file):
            try:
                with open(self.upload_queue_file, "r") as f:
                    # Load the list of items from the file
                    items = json.load(f)
                    # Put each item into the queue
                    for item in items:
                        q.put(tuple(item)) # Assuming items are stored as lists/tuples
                logger.info(f"[Upload Worker] Loaded {len(items)} items into upload queue.")
            except Exception as e:
                logger.error(f"[Upload Worker] Failed to load upload queue: {e}")
        return q

    def _save_upload_queue(self):
        try:
            with open(self.upload_queue_file, "w") as f:
                json.dump(self.upload_queue, f)
            logger.info(f"[Upload Worker] Saved upload queue: {self.upload_queue}")
        except Exception as e:
            logger.error(f"[Upload Worker] Failed to save upload queue: {e}")

    def _load_file_booking_map(self):
        map_file = os.path.join(TEMP_DIR, "file_booking_map.json")
        if os.path.exists(map_file):
            try:
                with open(map_file, "r") as f:
                    mapping = json.load(f)
                logger.info(f"[Upload Worker] Loaded file-booking map: {mapping}")
                return mapping
            except Exception as e:
                logger.error(f"[Upload Worker] Failed to load file-booking map: {e}")
        return {}

    def _save_file_booking_map(self):
        map_file = os.path.join(TEMP_DIR, "file_booking_map.json")
        try:
            with open(map_file, "w") as f:
                json.dump(self.file_booking_map, f)
            logger.info(f"[Upload Worker] Saved file-booking map: {self.file_booking_map}")
        except Exception as e:
            logger.error(f"[Upload Worker] Failed to save file-booking map: {e}")

    def add_to_upload_queue(self, file_path, booking_id=None):
        logger.info(f"[Upload Worker] Adding file to upload queue: {file_path} (booking {booking_id})")
        self.upload_queue.put((file_path, booking_id))
        self._save_upload_queue()
        if booking_id:
            self.file_booking_map[file_path] = booking_id
            self._save_file_booking_map()
        logger.info(f"[Upload Worker] Upload queue state: {self.upload_queue}")
        self._start_upload_worker()

    def upload_worker(self):
        """Upload worker thread that processes the upload queue."""
        logger.info("[Upload Worker] Upload worker running.")
        
        while not self.stop_event.is_set():
            try:
                # Use a timeout on get() to prevent it from blocking indefinitely.
                # This allows the loop to check the stop_event periodically.
                file_path, booking_id = self.upload_queue.get(timeout=1.0)
                
                # Check for the 'poison pill' (the signal to stop)
                if file_path is None:
                    logger.info("[Upload Worker] Received stop signal, exiting worker loop.")
                    break
                    
                logger.info(f"[Upload Worker] Processing upload for: {file_path} (booking {booking_id})")
                
                if os.path.exists(file_path):
                    size = os.path.getsize(file_path)
                    logger.info(f"[Upload Worker] File exists, size: {size} bytes")
                    filename = os.path.basename(file_path)
                    storage_path = f"recordings/{filename}"
                    
                    with open(file_path, 'rb') as f:
                        try:
                            # Upload to Supabase storage
                            supabase.storage.from_("recordings").upload(storage_path, f)
                            logger.info(f"[Upload Worker] Upload successful: {storage_path}")
                            
                            # Create video reference in database with local time
                            video_data = {
                                "filename": filename,
                                "storage_path": storage_path,
                                "booking_id": booking_id,
                                "created_at": datetime.now().astimezone().isoformat(),
                                "status": "completed"
                            }
                            supabase.table("videos").insert(video_data).execute()
                            logger.info(f"[Upload Worker] Video reference created in database")
                            
                            # Remove the booking
                            if booking_id:
                                self.remove_booking_for_file(file_path, booking_id)
                            
                            # Update storage usage
                            storage_used = get_storage_used()
                            update_system_status(storage_used=storage_used)
                            logger.info(f"[Upload Worker] Updated storage usage: {storage_used} bytes")
                            
                            # Clean up the local file
                            os.remove(file_path)
                            logger.info(f"[Upload Worker] Removed local file: {file_path}")
                            
                        except Exception as e:
                            logger.error(f"[Upload Worker] Upload failed for {file_path}: {e}", exc_info=True)
                            # Put the file back in the queue for retry
                            self.upload_queue.put((file_path, booking_id))
                            self._save_upload_queue()
                else:
                    logger.error(f"[Upload Worker] File does not exist: {file_path}")
            except queue.Empty:
                # This is a normal occurrence when the queue is empty.
                # The loop will just continue and check the stop_event again.
                continue
            except Exception as e:
                logger.error(f"[Upload Worker] Exception in upload_worker: {e}", exc_info=True)
                # Wait a moment before retrying to avoid spamming logs on persistent errors.
                time.sleep(5)

    def remove_booking_for_file(self, file_path, booking_id=None):
        """Remove booking after successful upload."""
        try:
            if not booking_id:
                booking_id = self.file_booking_map.get(file_path)
            if booking_id:
                logger.info(f"[Upload Worker] Removing booking {booking_id} for file: {file_path}")
                # Update booking status in Supabase
                supabase.table("bookings").update({"status": "completed"}).eq("id", booking_id).execute()
                logger.info(f"[Upload Worker] Updated booking {booking_id} status to completed.")
                
                # Also remove local booking file
                remove_booking()
                
                # Remove the file to booking association
                if file_path in self.file_booking_map:
                    del self.file_booking_map[file_path]
                    self._save_file_booking_map()
            else:
                logger.warning(f"[Upload Worker] No booking ID found for file: {file_path}")
        except Exception as e:
            logger.error(f"[Upload Worker] Failed to remove booking for {file_path}: {e}", exc_info=True)

    def manual_trigger_upload_queue(self):
        logger.info("Manual upload queue trigger received.")
        self._start_upload_worker()

    def start(self):
        return self.start_camera()

    def stop(self):
        """Stops the camera service and all background threads."""
        logger.info("Stopping CameraService...")
        if self.is_recording:
            self.stop_recording()
        
        # Gracefully stop the upload worker first
        self.stop_worker()
        
        if self.interface:
            try:
                # This code is defensive. The recurring AttributeError suggests that
                # an old version of the code might be running. This tries the
                # correct `release()` method first, and falls back to `close()`
                # to prevent crashing if the environment is stale.
                if hasattr(self.interface, 'release'):
                    self.interface.release()
                    logger.info("Camera interface released successfully.")
                elif hasattr(self.interface, 'close'):
                    logger.warning("Interface has 'close' but not 'release'. Calling 'close' as a fallback.")
                    self.interface.close()
                    logger.info("Camera interface closed via fallback.")
                else:
                    logger.error("Camera interface has neither 'release' nor 'close' method.")
            except Exception as e:
                logger.error(f"Failed to cleanly close camera interface: {e}", exc_info=True)
            
        logger.info("CameraService stopped.")

    def stop_worker(self):
        """Stops the upload worker thread gracefully."""
        if not self.upload_worker_running:
            logger.info("Upload worker is not running, no need to stop.")
            return

        logger.info("Stopping upload worker...")
        self.stop_event.set()
        
        # Use a 'poison pill' to unblock the queue.get() call.
        # This sends a special item that the worker loop knows means "stop".
        try:
            self.upload_queue.put((None, None))
        except Exception:
            # The queue might be full or closed, which is fine during shutdown.
            pass
            
        if self.upload_worker_thread and self.upload_worker_thread.is_alive():
            self.upload_worker_thread.join(timeout=10)
            if self.upload_worker_thread.is_alive():
                logger.warning("Upload worker thread did not stop within the 10-second timeout.")
        
        self.upload_worker_running = False
        logger.info("Upload worker stopped.")

    def process_and_queue_video(self, raw_path: str, booking: Dict[str, Any]):
        try:
            logger.info(f"Starting post-processing for {raw_path}")
            
            # 1. Add Overlays (Timestamp, Logo, Trademark)
            processed_path = os.path.join(str(UPLOAD_DIR), f"processed_{os.path.basename(raw_path)}")
            if not self._add_overlays(raw_path, processed_path, booking):
                logger.error("Overlay processing failed. Uploading raw video instead.")
                shutil.copy(raw_path, processed_path)
            
            # 2. Prepend Intro Video
            final_path = os.path.join(str(UPLOAD_DIR), f"final_{os.path.basename(raw_path)}")
            if os.path.exists(INTRO_VIDEO_PATH):
                logger.info("Prepending intro video.")
                if not self._prepend_intro(INTRO_VIDEO_PATH, processed_path, final_path):
                    logger.error("Failed to prepend intro video. Using video without intro.")
                    os.rename(processed_path, final_path)
            else:
                logger.warning("No intro video found. Skipping that step.")
                os.rename(processed_path, final_path)

            # 3. Add to upload queue
            self._add_to_upload_queue(final_path, booking['id'])
            
            # 4. Cleanup intermediate files
            if os.path.exists(raw_path): os.remove(raw_path)
            if os.path.exists(processed_path): os.remove(processed_path)
            logger.info(f"Successfully processed and queued for upload: {final_path}")

        except Exception as e:
            logger.error(f"Critical error in video processing pipeline: {e}", exc_info=True)

    def _add_overlays(self, in_path: str, out_path: str, booking: Dict[str, Any]) -> bool:
        cap = cv2.VideoCapture(in_path)
        if not cap.isOpened():
            logger.error(f"Failed to open video for overlay: {in_path}")
            return False
            
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = cap.get(cv2.CAP_PROP_FPS)

        # Use MP4V codec, which is widely compatible
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(out_path, fourcc, fps, (width, height))
        
        frame_num = 0
        booking_start_time = datetime.fromisoformat(booking['start_time'])

        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            # Add timestamp
            current_time = booking_start_time + (datetime.now().astimezone().utcoffset() or timedelta(0)) + timedelta(seconds=frame_num / fps)
            timestamp_str = current_time.strftime("%Y-%m-%d %H:%M:%S")
            self._overlay_text(frame, timestamp_str, 'top_left')

            # Add main logo
            if os.path.exists(LOGO_PATH):
                frame = self._overlay_image(frame, LOGO_PATH, 'top_right')
            
            # Add trademark
            if os.path.exists(TRADEMARK_PATH):
                frame = self._overlay_image(frame, TRADEMARK_PATH, 'bottom_center')
            
            out.write(frame)
            frame_num += 1

        cap.release()
        out.release()
        logger.info("Successfully added overlays.")
        return True

    def _prepend_intro(self, intro_path: str, main_path: str, out_path: str) -> bool:
        # Use ffmpeg for reliable video concatenation
        list_file = os.path.join(str(TEMP_DIR), "concat_list.txt")
        with open(list_file, "w") as f:
            f.write(f"file '{os.path.abspath(intro_path)}'\n")
            f.write(f"file '{os.path.abspath(main_path)}'\n")
            
        cmd = [
            "ffmpeg", "-y", "-f", "concat", "-safe", "0",
            "-i", list_file, "-c", "copy", out_path
        ]
        try:
            res = subprocess.run(cmd, check=True, capture_output=True, text=True)
            logger.info("Intro video prepended successfully.")
            os.remove(list_file)
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"ffmpeg failed to prepend intro: {e.stderr}")
            os.remove(list_file)
            return False

    def _overlay_image(self, frame, image_path, position):
        # Implementation for overlaying an image (logo/trademark)
        if image_path not in self.logo_cache:
            logo = cv2.imread(image_path, cv2.IMREAD_UNCHANGED)
            if logo is None: 
                self.logo_cache[image_path] = None
                return frame
            self.logo_cache[image_path] = logo
        
        logo = self.logo_cache[image_path]
        if logo is None: return frame

        fh, fw, _ = frame.shape
        lh, lw, _ = logo.shape
        
        # Scale logo to be 15% of frame width
        scale = (fw * 0.15) / lw
        logo = cv2.resize(logo, (0,0), fx=scale, fy=scale)
        lh, lw, _ = logo.shape

        if position == 'top_right':
            x, y = fw - lw - 20, 20
        elif position == 'bottom_center':
            x, y = (fw - lw) // 2, fh - lh - 20
        else: # Default top-left
            x, y = 20, 20

        # Simple alpha blending
        if logo.shape[2] == 4:
            alpha = logo[:,:,3] / 255.0
            for c in range(3):
                frame[y:y+lh, x:x+lw, c] = alpha * logo[:,:,c] + (1-alpha) * frame[y:y+lh, x:x+lw, c]
        else:
            frame[y:y+lh, x:x+lw] = logo
            
        return frame

    def _overlay_text(self, frame, text, position):
        # Implementation for overlaying text (timestamp)
        (w, h), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.8, 2)
        fh, fw, _ = frame.shape
        
        if position == 'top_left':
            x, y = 20, 20 + h
        
        cv2.rectangle(frame, (x-5, y-h-5), (x+w+5, y+5), (0,0,0), -1)
        cv2.putText(frame, text, (x, y), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
        return frame

    def _add_to_upload_queue(self, file_path: str, booking_id: str):
        queue = self._get_upload_queue()
        queue.append({"file_path": file_path, "booking_id": booking_id})
        self._save_upload_queue(queue)
        logger.info(f"Added {file_path} to upload queue.")

    def _get_upload_queue(self) -> list:
        queue_file = os.path.join(str(TEMP_DIR), "upload_queue.json")
        if not os.path.exists(queue_file): return []
        try:
            with open(queue_file, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            return []

    def _save_upload_queue(self, queue: list):
        queue_file = os.path.join(str(TEMP_DIR), "upload_queue.json")
        with open(queue_file, 'w') as f:
            json.dump(queue, f)

def main():
    """Test function for CameraService."""
    service = CameraService()
    if not service.start():
        return
    try:
        while True:
            if service.is_recording:
                frame = service.interface.capture_frame()
                if frame is not None and service.interface.camera_type == 'opencv':
                    service.interface.writer.write(frame)
                # For picamera2, recording is handled internally
                # Check recording duration
                if (time.time() - service.recording_start) >= MAX_RECORDING_DURATION:
                    service.stop_recording()
            else:
                time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Received shutdown signal")
    finally:
        service.stop()

if __name__ == "__main__":
    main() 