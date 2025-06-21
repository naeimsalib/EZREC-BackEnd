# Pi-optimized Camera Interface: auto-detects Pi Camera or USB camera. All paths set via config.py.
import os
import time
import threading
import cv2
from typing import Optional, Tuple

try:
    from picamera2 import Picamera2
    from picamera2.encoders import H264Encoder
    print("[DEBUG] Picamera2 import succeeded")
    PICAMERA2_AVAILABLE = True
except ImportError as e:
    print(f"[DEBUG] Picamera2 import failed: {e}")
    PICAMERA2_AVAILABLE = False
except Exception as e:
    print(f"[DEBUG] Picamera2 import failed (other): {e}")
    PICAMERA2_AVAILABLE = False

class CameraInterface:
    def __init__(self, width=1280, height=720, fps=30, output_dir="temp"):
        self.width = width
        self.height = height
        self.fps = fps
        self.output_dir = output_dir
        self.camera_type = None  # 'picamera2' or 'opencv'
        self.picam = None
        self.cap = None
        self.writer = None
        self.recording = False
        self.recording_path = None
        self._detect_camera()

    def _detect_camera(self):
        # Try Picamera2 first (for Pi Camera Module)
        if PICAMERA2_AVAILABLE:
            try:
                print("[DEBUG] Attempting to initialize Picamera2...")
                self.picam = Picamera2()
                video_config = self.picam.create_video_configuration(
                    main={"size": (self.width, self.height), "format": "RGB888"},
                    controls={"FrameRate": self.fps}
                )
                self.picam.configure(video_config)
                self.picam.start()
                self.camera_type = 'picamera2'
                print("[CameraInterface] Using Pi Camera (Picamera2)")
                return
            except Exception as e:
                import traceback
                self.picam = None
                print(f"[CameraInterface] Picamera2 not available or failed: {e}")
                traceback.print_exc()
        # Fallback: Try OpenCV on /dev/video* (for USB cameras)
        for idx in range(8):  # Try /dev/video0 ... /dev/video7
            try:
                cap = cv2.VideoCapture(idx)
                if cap.isOpened():
                    ret, frame = cap.read()
                    if ret:
                        self.cap = cap
                        self.camera_type = 'opencv'
                        print(f"[CameraInterface] Using USB camera at /dev/video{idx}")
                        return
                    cap.release()
            except Exception as e:
                import traceback
                print(f"[CameraInterface] Error initializing OpenCV camera at /dev/video{idx}: {e}")
                traceback.print_exc()
        raise RuntimeError("No working camera found (neither Pi Camera nor USB camera)")

    def capture_frame(self) -> Optional[any]:
        try:
            if self.camera_type == 'picamera2':
                frame = self.picam.capture_array()
                # Picamera2 returns RGB, OpenCV expects BGR
                return cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
            elif self.camera_type == 'opencv':
                ret, frame = self.cap.read()
                if not ret:
                    print("[CameraInterface] Failed to read frame (OpenCV)")
                return frame if ret else None
            else:
                print("[CameraInterface] capture_frame called with no camera initialized")
                return None
        except Exception as e:
            import traceback
            print(f"[CameraInterface] Exception in capture_frame: {e}")
            traceback.print_exc()
            return None

    def _update_system_status(self, is_recording: bool):
        try:
            from utils import update_system_status
            update_system_status(is_recording=is_recording)
        except Exception as e:
            print(f"[CameraInterface] Failed to update system status: {e}")

    def start_recording(self, filename: Optional[str] = None) -> str:
        try:
            if self.recording:
                print("[CameraInterface] Already recording!")
                return self.recording_path
            if not filename:
                timestamp = time.strftime("%Y%m%d_%H%M%S")
                filename = f"recording_{timestamp}.mp4"
            self.recording_path = os.path.join(self.output_dir, filename)
            print(f"[CameraInterface] Preparing to start recording: {self.recording_path}")
            
            # Ensure output directory exists
            os.makedirs(self.output_dir, exist_ok=True)
            
            if self.camera_type == 'picamera2':
                # Use H264 encoder with proper MP4 container
                self.encoder = H264Encoder(bitrate=10000000)  # 10Mbps for good quality
                
                # For Pi Camera, record as H264 first, then convert to MP4
                h264_path = self.recording_path.replace('.mp4', '.h264')
                self.h264_path = h264_path  # Store for conversion later
                
                # IMPORTANT: Stop the camera before reconfiguring
                print("[CameraInterface] Stopping camera for reconfiguration...")
                self.picam.stop()
                
                # Configure for recording with higher resolution
                video_config = self.picam.create_video_configuration(
                    main={"size": (1920, 1080), "format": "YUV420"},  # Higher quality
                    controls={"FrameRate": 30}
                )
                self.picam.configure(video_config)
                
                # Start the camera with new configuration
                print("[CameraInterface] Starting camera with video configuration...")
                self.picam.start()
                
                self.picam.start_recording(self.encoder, h264_path)
                self.recording = True
                self._update_system_status(is_recording=True)
                
            elif self.camera_type == 'opencv':
                # Use H264 codec with MP4 container for better compatibility
                fourcc = cv2.VideoWriter_fourcc(*'H264')
                self.writer = cv2.VideoWriter(
                    self.recording_path, fourcc, self.fps, (self.width, self.height)
                )
                
                if not self.writer.isOpened():
                    # Fallback to XVID if H264 not available
                    fourcc = cv2.VideoWriter_fourcc(*'XVID')
                    self.writer = cv2.VideoWriter(
                        self.recording_path, fourcc, self.fps, (self.width, self.height)
                    )
                
                self.recording = True
                self._recording_thread = threading.Thread(target=self._opencv_record_loop)
                self._recording_thread.daemon = True
                self._recording_thread.start()
                self._update_system_status(is_recording=True)
                
            print(f"[CameraInterface] Started recording: {self.recording_path}")
            return self.recording_path
        except Exception as e:
            import traceback
            print(f"[CameraInterface] Exception in start_recording: {e}")
            traceback.print_exc()
            raise

    def _opencv_record_loop(self):
        try:
            while self.recording:
                frame = self.capture_frame()
                if frame is not None:
                    self.writer.write(frame)
                else:
                    print("[CameraInterface] Failed to read frame during recording.")
                    break
                time.sleep(1.0 / self.fps)
        except Exception as e:
            import traceback
            print(f"[CameraInterface] Exception in _opencv_record_loop: {e}")
            traceback.print_exc()

    def stop_recording(self):
        try:
            if not self.recording:
                print("[CameraInterface] Not recording.")
                return None
                
            recording_path = self.recording_path
            
            if self.camera_type == 'picamera2':
                self.picam.stop_recording()
                self.encoder = None
                
                # Stop the camera and reconfigure back to preview mode
                print("[CameraInterface] Stopping camera and reconfiguring to preview mode...")
                self.picam.stop()
                
                # Reconfigure back to preview mode
                preview_config = self.picam.create_preview_configuration(
                    main={"size": (self.width, self.height), "format": "RGB888"}
                )
                self.picam.configure(preview_config)
                self.picam.start()
                print("[CameraInterface] Camera reconfigured to preview mode")
                
                # Convert H264 to MP4 using ffmpeg for better compatibility
                if hasattr(self, 'h264_path') and os.path.exists(self.h264_path):
                    try:
                        import subprocess
                        print(f"[CameraInterface] Converting H264 to MP4: {self.h264_path} -> {recording_path}")
                        
                        # Use ffmpeg to convert H264 to MP4
                        cmd = [
                            'ffmpeg', '-y',  # -y to overwrite output file
                            '-i', self.h264_path,  # input H264 file
                            '-c', 'copy',  # copy codec (no re-encoding)
                            '-movflags', '+faststart',  # optimize for web streaming
                            recording_path  # output MP4 file
                        ]
                        
                        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                        
                        if result.returncode == 0:
                            print(f"[CameraInterface] Successfully converted to MP4: {recording_path}")
                            # Remove the temporary H264 file
                            os.remove(self.h264_path)
                        else:
                            print(f"[CameraInterface] FFmpeg conversion failed: {result.stderr}")
                            # If conversion fails, rename H264 to MP4 as fallback
                            os.rename(self.h264_path, recording_path)
                            print(f"[CameraInterface] Renamed H264 to MP4 as fallback: {recording_path}")
                            
                    except subprocess.TimeoutExpired:
                        print("[CameraInterface] FFmpeg conversion timed out, using H264 file")
                        os.rename(self.h264_path, recording_path)
                    except Exception as conv_error:
                        print(f"[CameraInterface] Conversion error: {conv_error}")
                        # Fallback: rename H264 to MP4
                        if os.path.exists(self.h264_path):
                            os.rename(self.h264_path, recording_path)
                            
            elif self.camera_type == 'opencv':
                self.recording = False
                if self.writer:
                    self.writer.release()
                    self.writer = None
                    
            self.recording = False
            self._update_system_status(is_recording=False)
            print(f"[CameraInterface] Stopped recording: {recording_path}")
            
            # Verify the file exists and has content
            if os.path.exists(recording_path):
                file_size = os.path.getsize(recording_path)
                print(f"[CameraInterface] Recording file size: {file_size} bytes")
                if file_size < 1000:  # Less than 1KB is likely empty
                    print("[CameraInterface] Warning: Recording file is very small, may be corrupted")
            else:
                print(f"[CameraInterface] Warning: Recording file not found: {recording_path}")
                return None
            
            # Return the path of the recorded file
            return recording_path
        except Exception as e:
            import traceback
            print(f"[CameraInterface] Exception in stop_recording: {e}")
            traceback.print_exc()
            return None

    def release(self):
        try:
            if self.camera_type == 'picamera2' and self.picam:
                self.picam.stop()
            elif self.camera_type == 'opencv' and self.cap:
                self.cap.release()
        except Exception as e:
            import traceback
            print(f"[CameraInterface] Exception in release: {e}")
            traceback.print_exc() 