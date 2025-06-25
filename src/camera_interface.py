#!/usr/bin/env python3
"""
EZREC Camera Interface - Optimized for Raspberry Pi
Handles both Pi Camera (via picamera2) and USB cameras (via OpenCV)
Features: Enhanced error handling, logging, retry logic, and configuration
"""
import os
import time
import threading
import logging
from typing import Optional, Tuple, Dict, Any
import subprocess
import cv2

try:
    from picamera2 import Picamera2
    from picamera2.encoders import H264Encoder, MJPEGEncoder
    from picamera2.outputs import FileOutput
    PICAMERA2_AVAILABLE = True
    logging.info("Picamera2 library available")
except ImportError as e:
    PICAMERA2_AVAILABLE = False
    logging.warning(f"Picamera2 not available: {e}")

from config import (
    RECORD_WIDTH, RECORD_HEIGHT, RECORD_FPS, RECORDING_BITRATE, 
    TEMP_DIR, DEBUG, NETWORK_TIMEOUT, HARDWARE_ENCODER
)

class CameraInterface:
    """Enhanced camera interface with robust error handling and logging."""
    
    def __init__(self, width=None, height=None, fps=None, output_dir=None, bitrate=None):
        # Configuration with fallbacks
        self.width = width or RECORD_WIDTH
        self.height = height or RECORD_HEIGHT
        self.fps = fps or RECORD_FPS
        self.output_dir = output_dir or str(TEMP_DIR)
        self.bitrate = bitrate or RECORDING_BITRATE
        
        # State management
        self.camera_type = None  # 'picamera2' or 'opencv'
        self.picam = None
        self.cap = None
        self.encoder = None
        self.writer = None
        self.recording = False
        self.recording_path = None
        self.recording_thread = None
        self.frame_count = 0
        self.last_frame_time = 0
        
        # Setup logging
        self.logger = logging.getLogger(f"{__name__}.CameraInterface")
        
        # Ensure output directory exists
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Initialize camera with retry logic
        self._initialize_camera_with_retry()

    def _initialize_camera_with_retry(self, max_retries=3, delay=2):
        """Initialize camera with retry logic and proper error handling."""
        for attempt in range(max_retries):
            try:
                # Run camera detection first for diagnostics
                if attempt == 0:  # Only on first attempt to avoid spam
                    try:
                        available_cameras = detect_cameras()
                        self.logger.info(f"Available cameras detected: {available_cameras}")
                    except Exception as e:
                        self.logger.warning(f"Camera detection failed: {e}")
                
                self._detect_and_initialize_camera()
                
                # Verify camera is actually working by capturing a test frame
                test_frame = self.capture_frame()
                if test_frame is not None:
                    self.logger.info(f"Camera initialized and verified successfully on attempt {attempt + 1}")
                    return
                else:
                    self.logger.warning("Camera initialized but failed test frame capture")
                    self.release()  # Clean up before retry
                    raise RuntimeError("Camera test frame capture failed")
                    
            except Exception as e:
                self.logger.warning(f"Camera initialization attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    self.logger.info(f"Retrying camera initialization in {delay} seconds...")
                    time.sleep(delay)
                else:
                    self.logger.error("All camera initialization attempts failed")
                    # Don't raise exception - let camera interface handle gracefully
                    self.camera_type = None

    def _detect_and_initialize_camera(self):
        """Detect and initialize the best available camera."""
        # Try Pi Camera first (more reliable on Raspberry Pi)
        if PICAMERA2_AVAILABLE:
            if self._try_picamera2():
                return
        
        # Fallback to USB cameras
        if self._try_opencv_cameras():
            return
            
        raise RuntimeError("No working camera found (tried Pi Camera and USB cameras)")

    def _try_picamera2(self) -> bool:
        """Try to initialize Pi Camera using picamera2."""
        try:
            self.logger.info("Attempting to initialize Pi Camera (picamera2)...")
            
            self.picam = Picamera2()
            
            # Configure for video with optimal settings
            video_config = self.picam.create_video_configuration(
                main={"size": (self.width, self.height), "format": "YUV420"},
                controls={
                    "FrameRate": self.fps,
                    "ExposureTime": 10000,  # Auto exposure
                    "AnalogueGain": 1.0,
                }
            )
            
            self.picam.configure(video_config)
            self.picam.start()
            
            # Test frame capture
            test_frame = self.picam.capture_array()
            if test_frame is not None:
                self.camera_type = 'picamera2'
                self.logger.info(f"Pi Camera initialized: {self.width}x{self.height}@{self.fps}fps")
                return True
            else:
                raise RuntimeError("Failed to capture test frame")
                
        except Exception as e:
            self.logger.warning(f"Pi Camera initialization failed: {e}")
            if self.picam:
                try:
                    self.picam.stop()
                    self.picam.close()
                except:
                    pass
                self.picam = None
            return False

    def _try_opencv_cameras(self) -> bool:
        """Try to initialize USB cameras using OpenCV."""
        # Common camera indices to try
        camera_indices = [0, 1, 2, 4, 6]  # Skip some problematic indices
        
        for idx in camera_indices:
            try:
                self.logger.info(f"Trying USB camera at /dev/video{idx}...")
                
                cap = cv2.VideoCapture(idx)
                if not cap.isOpened():
                    continue
                
                # Configure camera properties
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
                cap.set(cv2.CAP_PROP_FPS, self.fps)
                cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # Reduce latency
                
                # Test frame capture with timeout
                for _ in range(5):  # Try a few frames
                    ret, frame = cap.read()
                    if ret and frame is not None:
                        actual_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
                        actual_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
                        actual_fps = cap.get(cv2.CAP_PROP_FPS)
                        
                        self.cap = cap
                        self.camera_type = 'opencv'
                        self.logger.info(f"USB camera initialized at /dev/video{idx}: "
                                       f"{actual_width}x{actual_height}@{actual_fps}fps")
                        return True
                        
                cap.release()
                
            except Exception as e:
                self.logger.warning(f"Failed to initialize camera at /dev/video{idx}: {e}")
                
        return False

    def capture_frame(self) -> Optional[any]:
        """Capture a single frame with error handling and retry logic."""
        if not self._is_camera_ready():
            self.logger.error("Camera not ready for frame capture")
            return None
            
        max_retries = 3
        for attempt in range(max_retries):
            try:
                if self.camera_type == 'picamera2':
                    frame = self.picam.capture_array()
                    if frame is not None:
                        # Convert RGB to BGR for OpenCV compatibility
                        frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
                        self.frame_count += 1
                        self.last_frame_time = time.time()
                        return frame
                        
                elif self.camera_type == 'opencv':
                    ret, frame = self.cap.read()
                    if ret and frame is not None:
                        self.frame_count += 1
                        self.last_frame_time = time.time()
                        return frame
                    
            except Exception as e:
                self.logger.warning(f"Frame capture attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(0.1)  # Brief pause before retry
                    
        self.logger.error("All frame capture attempts failed")
        return None

    def start_recording(self, filename: Optional[str] = None) -> str:
        """Start video recording with enhanced error handling."""
        if self.recording:
            self.logger.warning("Already recording")
            return self.recording_path
            
        if not self._is_camera_ready():
            raise RuntimeError("Camera not ready for recording")
            
        try:
            # Generate filename if not provided
            if not filename:
                timestamp = time.strftime("%Y%m%d_%H%M%S")
                filename = f"recording_{timestamp}.mp4"
                
            self.recording_path = os.path.join(self.output_dir, filename)
            self.logger.info(f"Starting recording: {self.recording_path}")
            
            if self.camera_type == 'picamera2':
                self._start_picamera2_recording()
            elif self.camera_type == 'opencv':
                self._start_opencv_recording()
            else:
                raise RuntimeError("No camera available for recording")
                
            self.recording = True
            self.logger.info(f"Recording started successfully: {filename}")
            return self.recording_path
            
        except Exception as e:
            self.logger.error(f"Failed to start recording: {e}")
            self.recording = False
            raise

    def _start_picamera2_recording(self):
        """Start recording with Pi Camera using H264 encoder."""
        try:
            # Stop camera for reconfiguration
            self.picam.stop()
            
            # Configure for high-quality recording
            video_config = self.picam.create_video_configuration(
                main={"size": (self.width, self.height), "format": "YUV420"},
                controls={"FrameRate": self.fps}
            )
            self.picam.configure(video_config)
            
            # Create H264 encoder with specified bitrate
            self.encoder = H264Encoder(bitrate=self.bitrate)
            
            # Start camera and recording
            self.picam.start()
            self.picam.start_recording(self.encoder, self.recording_path)
            
        except Exception as e:
            self.logger.error(f"Pi Camera recording setup failed: {e}")
            raise

    def _start_opencv_recording(self):
        """Start recording with USB camera using OpenCV VideoWriter."""
        try:
            # Try H264 codec first (best quality)
            fourcc_options = [
                ('H264', cv2.VideoWriter_fourcc(*'H264')),
                ('MP4V', cv2.VideoWriter_fourcc(*'MP4V')),
                ('XVID', cv2.VideoWriter_fourcc(*'XVID')),
            ]
            
            for codec_name, fourcc in fourcc_options:
                self.writer = cv2.VideoWriter(
                    self.recording_path, fourcc, self.fps, (self.width, self.height)
                )
                
                if self.writer.isOpened():
                    self.logger.info(f"Using {codec_name} codec for recording")
                    break
                else:
                    self.writer.release()
                    self.writer = None
                    
            if not self.writer:
                raise RuntimeError("Failed to initialize video writer with any codec")
                
            # Start recording thread
            self.recording_thread = threading.Thread(target=self._opencv_recording_loop)
            self.recording_thread.daemon = True
            self.recording_thread.start()
            
        except Exception as e:
            self.logger.error(f"USB camera recording setup failed: {e}")
            raise

    def _opencv_recording_loop(self):
        """Recording loop for OpenCV cameras."""
        frame_interval = 1.0 / self.fps
        last_frame_time = time.time()
        
        while self.recording:
            try:
                current_time = time.time()
                if current_time - last_frame_time >= frame_interval:
                    frame = self.capture_frame()
                    if frame is not None:
                        self.writer.write(frame)
                        last_frame_time = current_time
                    else:
                        self.logger.warning("Failed to capture frame during recording")
                        break
                        
                time.sleep(0.001)  # Prevent busy waiting
                
            except Exception as e:
                self.logger.error(f"Error in recording loop: {e}")
                break

    def stop_recording(self) -> Optional[str]:
        """Stop recording and return the recorded file path."""
        if not self.recording:
            self.logger.warning("Not currently recording")
            return None
            
        try:
            recording_path = self.recording_path
            self.recording = False
            
            if self.camera_type == 'picamera2':
                self.picam.stop_recording()
                self.encoder = None
                
                # Reconfigure back to preview mode
                self.picam.stop()
                preview_config = self.picam.create_preview_configuration(
                    main={"size": (640, 480), "format": "RGB888"}
                )
                self.picam.configure(preview_config)
                self.picam.start()
                
            elif self.camera_type == 'opencv':
                if self.recording_thread:
                    self.recording_thread.join(timeout=5)
                if self.writer:
                    self.writer.release()
                    self.writer = None
                    
            # Verify file was created and has content
            if recording_path and os.path.exists(recording_path):
                file_size = os.path.getsize(recording_path)
                if file_size > 0:
                    self.logger.info(f"Recording stopped successfully: {recording_path} ({file_size} bytes)")
                    return recording_path
                else:
                    self.logger.error("Recording file is empty")
            else:
                self.logger.error("Recording file not found")
                
            return None
            
        except Exception as e:
            self.logger.error(f"Error stopping recording: {e}")
            return None

    def get_camera_info(self) -> Dict[str, Any]:
        """Get detailed camera information."""
        info = {
            "camera_type": self.camera_type,
            "resolution": f"{self.width}x{self.height}",
            "fps": self.fps,
            "bitrate": self.bitrate,
            "recording": self.recording,
            "frame_count": self.frame_count,
            "last_frame_time": self.last_frame_time,
        }
        
        if self.camera_type == 'opencv' and self.cap:
            info.update({
                "actual_width": int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
                "actual_height": int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
                "actual_fps": self.cap.get(cv2.CAP_PROP_FPS),
                "backend": self.cap.getBackendName(),
            })
            
        return info

    def health_check(self) -> bool:
        """Perform a comprehensive health check on the camera."""
        try:
            # Check if camera is initialized
            if not self._is_camera_ready():
                self.logger.warning("Camera health check failed: Camera not ready/initialized")
                return False
            
            # Check camera type and specific health
            if self.camera_type == 'picamera2':
                if not self.picam:
                    self.logger.warning("Camera health check failed: Pi Camera object is None")
                    return False
            elif self.camera_type == 'opencv':
                if not self.cap or not self.cap.isOpened():
                    self.logger.warning("Camera health check failed: OpenCV camera not opened")
                    return False
            else:
                self.logger.warning("Camera health check failed: Unknown camera type")
                return False
                
            # Try to capture a test frame (most comprehensive test)
            frame = self.capture_frame()
            if frame is not None:
                self.logger.debug("Camera health check passed")
                return True
            else:
                self.logger.warning("Camera health check failed: Unable to capture test frame")
                return False
            
        except Exception as e:
            self.logger.error(f"Camera health check failed with exception: {e}")
            return False

    def _is_camera_ready(self) -> bool:
        """Check if camera is ready for operations."""
        if self.camera_type == 'picamera2':
            return self.picam is not None
        elif self.camera_type == 'opencv':
            return self.cap is not None and self.cap.isOpened()
        return False

    def release(self):
        """Clean up camera resources."""
        try:
            if self.recording:
                self.stop_recording()
                
            if self.camera_type == 'picamera2' and self.picam:
                self.picam.stop()
                self.picam.close()
                self.picam = None
                
            elif self.camera_type == 'opencv' and self.cap:
                self.cap.release()
                self.cap = None
                
            self.camera_type = None
            self.logger.info("Camera resources released")
            
        except Exception as e:
            self.logger.error(f"Error releasing camera: {e}")

    def __del__(self):
        """Destructor to ensure cleanup."""
        self.release()

# Utility functions for camera detection
def detect_cameras() -> Dict[str, Any]:
    """Detect all available cameras on the system."""
    cameras = {"picamera": False, "usb_cameras": []}
    
    # Check for Pi Camera
    if PICAMERA2_AVAILABLE:
        try:
            picam = Picamera2()
            picam.close()
            cameras["picamera"] = True
        except:
            pass
    
    # Check for USB cameras
    for i in range(8):
        try:
            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                ret, _ = cap.read()
                if ret:
                    cameras["usb_cameras"].append(i)
            cap.release()
        except:
            pass
    
    return cameras

def test_camera_interface():
    """Test function for camera interface."""
    try:
        camera = CameraInterface()
        info = camera.get_camera_info()
        print(f"Camera Info: {info}")
        
        # Test frame capture
        frame = camera.capture_frame()
        if frame is not None:
            print(f"Frame captured: {frame.shape}")
        else:
            print("Failed to capture frame")
            
        camera.release()
        return True
    except Exception as e:
        print(f"Camera test failed: {e}")
        return False

if __name__ == "__main__":
    # Run camera test
    print("Testing camera interface...")
    success = test_camera_interface()
    print(f"Camera test {'passed' if success else 'failed'}") 