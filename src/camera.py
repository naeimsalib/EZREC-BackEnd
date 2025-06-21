#!/usr/bin/env python3
import os
import time
import threading
from datetime import datetime
from typing import Optional, Tuple
import subprocess
import json
import queue

import cv2
from .utils import (
    logger,
    supabase,
    queue_upload,
    get_upload_queue,
    clear_upload_queue,
    cleanup_temp_files,
    update_system_status,
    get_storage_used,
    remove_booking,
)
from .config import (
    CAMERA_ID,
    RECORD_WIDTH,
    RECORD_HEIGHT,
    RECORD_FPS,
    RECORDING_DIR,
    TEMP_DIR,
    MAX_RECORDING_DURATION
)
from .camera_interface import CameraInterface

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

    def start_recording(self, booking_id=None) -> bool:
        """Start recording video using CameraInterface."""
        if self.is_recording:
            logger.warning("Already recording")
            return False
        try:
            logger.info("[Recording Sign] Would turn ON recording indicator here.")
            self.current_file = self.interface.start_recording()
            self.is_recording = True
            self.recording_start = time.time()
            if booking_id:
                self.file_booking_map[self.current_file] = booking_id
                logger.info(f"[Booking Map] Associated {self.current_file} with booking {booking_id}")
            try:
                update_system_status(is_recording=True)
            except Exception as e:
                logger.error(f"Error updating system status after start_recording: {e}", exc_info=True)
            logger.info(f"Started recording to {self.current_file}")
            return True
        except Exception as e:
            logger.error(f"Error starting recording: {e}", exc_info=True)
            return False

    def stop_recording(self):
        """Stop recording and queue file for upload."""
        if not self.is_recording:
            logger.warning("stop_recording called but not recording")
            return False
        try:
            logger.info("[Camera] Beginning recording stop process")
            self.is_recording = False
            self.interface.stop_recording()
            logger.info("[Camera] Recording stopped")
            
            if self.current_file:
                logger.info(f"[Camera] Processing recording file: {self.current_file}")
                if os.path.exists(self.current_file):
                    size = os.path.getsize(self.current_file)
                    logger.info(f"[Camera] Recording file exists, size: {size} bytes")
                    
                    # Wait a moment to ensure file is fully written
                    time.sleep(2)
                    
                    try:
                        # Try to attach intro video
                        final_path = self.attach_intro_video(self.current_file)
                        if final_path and os.path.exists(final_path):
                            logger.info(f"[Camera] Final video created at: {final_path}")
                            booking_id = self.file_booking_map.get(self.current_file)
                            if booking_id:
                                logger.info(f"[Camera] Adding to upload queue with booking ID: {booking_id}")
                                self.add_to_upload_queue(final_path, booking_id)
                                logger.info(f"[Camera] Successfully queued for upload: {final_path}")
                            else:
                                logger.error(f"[Camera] No booking ID found for file: {self.current_file}")
                        else:
                            logger.error(f"[Camera] Failed to create final video from: {self.current_file}")
                    except Exception as e:
                        logger.error(f"[Camera] Error processing recording: {str(e)}", exc_info=True)
                else:
                    logger.error(f"[Camera] Recording file does not exist: {self.current_file}")
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