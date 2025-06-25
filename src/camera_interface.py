#!/usr/bin/env python3
"""
🎬 EZREC Camera Interface - Picamera2 Exclusive Access
Optimized for Raspberry Pi running Debian with Picamera2
Ensures exclusive camera access and proper resource management
"""

import os
import sys
import time
import logging
import threading
from typing import Optional, Tuple, Dict, Any
from datetime import datetime, timedelta
import gc

# Add project root to path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

try:
    from picamera2 import Picamera2
    from picamera2.encoders import H264Encoder, Quality
    from picamera2.outputs import FileOutput
    import numpy as np
    PICAMERA2_AVAILABLE = True
except ImportError as e:
    PICAMERA2_AVAILABLE = False
    print(f"❌ Picamera2 not available: {e}")

from src.config import Config

class EZRECCameraInterface:
    """
    EZREC Camera Interface with Picamera2 Exclusive Access
    Optimized for Raspberry Pi Debian with resource protection
    """
    
    def __init__(self, camera_id: str = "pi_camera_1"):
        """Initialize camera interface with exclusive access"""
        self.camera_id = camera_id
        self.picam: Optional[Picamera2] = None
        self.encoder: Optional[H264Encoder] = None
        self.output: Optional[FileOutput] = None
        self.is_recording = False
        self.current_recording_path: Optional[str] = None
        self.recording_start_time: Optional[datetime] = None
        self.recording_thread: Optional[threading.Thread] = None
        self.stop_recording_event = threading.Event()
        self.lock = threading.Lock()
        
        # Configuration
        self.config = Config()
        self.temp_dir = "/opt/ezrec-backend/temp"
        self.recordings_dir = "/opt/ezrec-backend/recordings"
        
        # Camera settings optimized for recording
        self.recording_resolution = (1920, 1080)  # Full HD
        self.preview_resolution = (640, 480)      # Lower for status checks
        self.framerate = 30
        self.quality = Quality.HIGH
        
        # Ensure directories exist
        os.makedirs(self.temp_dir, exist_ok=True)
        os.makedirs(self.recordings_dir, exist_ok=True)
        
        # Setup logging
        self.logger = logging.getLogger(f"EZREC.Camera.{camera_id}")
        self.logger.setLevel(logging.INFO)
        
        if not PICAMERA2_AVAILABLE:
            self.logger.error("❌ Picamera2 not available - camera disabled")
            return
            
        # Initialize camera with exclusive access
        self._initialize_camera_exclusive()
    
    def _initialize_camera_exclusive(self) -> bool:
        """Initialize camera with exclusive access protection"""
        try:
            self.logger.info("🎬 Initializing Picamera2 with exclusive access...")
            
            # Ensure no other process is using camera
            self._ensure_exclusive_access()
            
            # Create Picamera2 instance
            self.picam = Picamera2()
            self.logger.info("✅ Picamera2 object created")
            
            # Get camera properties
            camera_props = self.picam.camera_properties
            self.logger.info(f"📹 Camera properties: {camera_props}")
            
            # Create optimized configuration for recording
            self._configure_for_recording()
            
            self.logger.info("✅ Camera initialized successfully with exclusive access")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Camera initialization failed: {e}")
            self.picam = None
            return False
    
    def _ensure_exclusive_access(self):
        """Ensure no other process is using the camera"""
        try:
            import psutil
            
            # Check for competing processes
            camera_processes = []
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                try:
                    cmdline = ' '.join(proc.info['cmdline'] or [])
                    if any(term in cmdline.lower() for term in 
                          ['libcamera', 'motion', 'mjpg', 'vlc', 'cheese', 'opencv']):
                        if proc.info['name'] != 'python3':  # Don't kill ourselves
                            camera_processes.append(proc)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            
            # Terminate competing processes
            for proc in camera_processes:
                try:
                    self.logger.warning(f"🛑 Terminating competing camera process: {proc.info['name']} (PID: {proc.info['pid']})")
                    proc.terminate()
                    proc.wait(timeout=3)
                except (psutil.NoSuchProcess, psutil.TimeoutExpired):
                    try:
                        proc.kill()
                    except psutil.NoSuchProcess:
                        pass
                        
        except ImportError:
            # psutil not available, use basic process killing
            os.system("pkill -f 'motion|mjpg|vlc|cheese' 2>/dev/null || true")
    
    def _configure_for_recording(self):
        """Configure camera optimally for recording"""
        try:
            # Create recording configuration
            recording_config = self.picam.create_video_configuration(
                main={"size": self.recording_resolution, "format": "RGB888"},
                lores={"size": self.preview_resolution, "format": "YUV420"}
            )
            
            # Set framerate
            recording_config["controls"] = {
                "FrameRate": self.framerate,
                "ExposureMode": 0,  # Auto exposure
                "AwbMode": 0,       # Auto white balance
                "Brightness": 0.0,
                "Contrast": 1.0,
                "Saturation": 1.0
            }
            
            self.picam.configure(recording_config)
            self.logger.info(f"✅ Camera configured for recording: {self.recording_resolution}@{self.framerate}fps")
            
        except Exception as e:
            self.logger.error(f"❌ Camera configuration failed: {e}")
            raise
    
    def get_status(self) -> Dict[str, Any]:
        """Get current camera status"""
        try:
            if not self.is_available():
                return {
                    "camera_id": self.camera_id,
                    "status": "unavailable",
                    "is_recording": False,
                    "error": "Camera not initialized"
                }
            
            status = {
                "camera_id": self.camera_id,
                "status": "active" if self.picam else "inactive",
                "is_recording": self.is_recording,
                "recording_path": self.current_recording_path,
                "recording_duration": None,
                "resolution": f"{self.recording_resolution[0]}x{self.recording_resolution[1]}",
                "framerate": self.framerate,
                "temperature": self._get_cpu_temperature(),
                "memory_usage": self._get_memory_usage(),
                "last_check": datetime.now().isoformat()
            }
            
            if self.is_recording and self.recording_start_time:
                duration = datetime.now() - self.recording_start_time
                status["recording_duration"] = str(duration).split('.')[0]  # Remove microseconds
            
            return status
            
        except Exception as e:
            self.logger.error(f"❌ Status check failed: {e}")
            return {
                "camera_id": self.camera_id,
                "status": "error",
                "error": str(e),
                "is_recording": False
            }
    
    def is_available(self) -> bool:
        """Check if camera is available and working"""
        return PICAMERA2_AVAILABLE and self.picam is not None
    
    def start_recording(self, booking_id: str, output_path: str) -> bool:
        """Start recording for a booking"""
        with self.lock:
            try:
                if not self.is_available():
                    self.logger.error("❌ Cannot start recording - camera not available")
                    return False
                
                if self.is_recording:
                    self.logger.warning("⚠️  Already recording - stopping current recording first")
                    self.stop_recording()
                
                self.logger.info(f"🎬 Starting recording for booking {booking_id}")
                
                # Ensure output directory exists
                os.makedirs(os.path.dirname(output_path), exist_ok=True)
                
                # Start camera if not already started
                if not self.picam.started:
                    self.picam.start()
                    time.sleep(1)  # Allow camera to stabilize
                
                # Create encoder
                self.encoder = H264Encoder(bitrate=10000000, repeat=True, iperiod=30)
                
                # Create output
                self.output = FileOutput(output_path)
                
                # Start recording
                self.picam.start_recording(self.encoder, self.output)
                
                # Update state
                self.is_recording = True
                self.current_recording_path = output_path
                self.recording_start_time = datetime.now()
                self.stop_recording_event.clear()
                
                self.logger.info(f"✅ Recording started: {output_path}")
                return True
                
            except Exception as e:
                self.logger.error(f"❌ Failed to start recording: {e}")
                self.is_recording = False
                self.current_recording_path = None
                return False
    
    def stop_recording(self) -> Tuple[bool, Optional[str]]:
        """Stop current recording"""
        with self.lock:
            try:
                if not self.is_recording:
                    self.logger.warning("⚠️  Not currently recording")
                    return True, None
                
                self.logger.info("🛑 Stopping recording...")
                
                # Stop recording
                if self.picam and self.picam.started:
                    self.picam.stop_recording()
                
                # Get recording path before clearing
                recording_path = self.current_recording_path
                
                # Clear state
                self.is_recording = False
                self.current_recording_path = None
                self.recording_start_time = None
                self.stop_recording_event.set()
                
                # Cleanup encoder and output
                if self.encoder:
                    self.encoder = None
                if self.output:
                    self.output = None
                
                # Force garbage collection
                gc.collect()
                
                self.logger.info(f"✅ Recording stopped: {recording_path}")
                return True, recording_path
                
            except Exception as e:
                self.logger.error(f"❌ Failed to stop recording: {e}")
                return False, None
    
    def capture_test_frame(self) -> Tuple[bool, Optional[str]]:
        """Capture a test frame to verify camera functionality"""
        try:
            if not self.is_available():
                return False, "Camera not available"
            
            test_path = os.path.join(self.temp_dir, f"test_frame_{int(time.time())}.jpg")
            
            # Start camera if needed
            was_started = self.picam.started
            if not was_started:
                self.picam.start()
                time.sleep(1)
            
            # Capture image
            self.picam.capture_file(test_path)
            
            # Stop camera if we started it
            if not was_started:
                self.picam.stop()
            
            # Verify file exists and has content
            if os.path.exists(test_path) and os.path.getsize(test_path) > 0:
                self.logger.info(f"✅ Test frame captured: {test_path}")
                return True, test_path
            else:
                return False, "Test frame file empty or missing"
                
        except Exception as e:
            self.logger.error(f"❌ Test frame capture failed: {e}")
            return False, str(e)
    
    def cleanup(self):
        """Clean up camera resources"""
        try:
            self.logger.info("🧹 Cleaning up camera resources...")
            
            # Stop recording if active
            if self.is_recording:
                self.stop_recording()
            
            # Stop and close camera
            if self.picam:
                try:
                    if self.picam.started:
                        self.picam.stop()
                    self.picam.close()
                except Exception as e:
                    self.logger.warning(f"Warning during camera cleanup: {e}")
                finally:
                    self.picam = None
            
            # Clear references
            self.encoder = None
            self.output = None
            
            # Force garbage collection
            gc.collect()
            
            self.logger.info("✅ Camera cleanup completed")
            
        except Exception as e:
            self.logger.error(f"❌ Camera cleanup failed: {e}")
    
    def _get_cpu_temperature(self) -> Optional[float]:
        """Get CPU temperature"""
        try:
            with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
                temp = float(f.read().strip()) / 1000.0
                return round(temp, 1)
        except:
            return None
    
    def _get_memory_usage(self) -> Dict[str, Any]:
        """Get memory usage information"""
        try:
            import psutil
            memory = psutil.virtual_memory()
            return {
                "total_mb": round(memory.total / 1024 / 1024),
                "available_mb": round(memory.available / 1024 / 1024),
                "used_percent": memory.percent
            }
        except ImportError:
            return {"error": "psutil not available"}
    
    def __enter__(self):
        """Context manager entry"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.cleanup()


# Global camera instance for the application
_camera_instance: Optional[EZRECCameraInterface] = None

def get_camera_instance(camera_id: str = "pi_camera_1") -> EZRECCameraInterface:
    """Get or create the global camera instance"""
    global _camera_instance
    if _camera_instance is None:
        _camera_instance = EZRECCameraInterface(camera_id)
    return _camera_instance

def cleanup_camera_instance():
    """Cleanup the global camera instance"""
    global _camera_instance
    if _camera_instance:
        _camera_instance.cleanup()
        _camera_instance = None


if __name__ == "__main__":
    # Test the camera interface
    print("🎬 EZREC Camera Interface Test")
    print("==============================")
    
    with EZRECCameraInterface() as camera:
        print(f"📹 Camera available: {camera.is_available()}")
        
        if camera.is_available():
            # Test status
            status = camera.get_status()
            print(f"📊 Status: {status}")
            
            # Test frame capture
            success, result = camera.capture_test_frame()
            if success:
                print(f"✅ Test frame: {result}")
            else:
                print(f"❌ Test frame failed: {result}")
            
            # Test short recording
            test_video = "/tmp/ezrec_interface_test.mp4"
            print(f"🎬 Testing recording to {test_video}")
            
            if camera.start_recording("test_booking", test_video):
                print("✅ Recording started")
                time.sleep(3)  # Record for 3 seconds
                
                success, path = camera.stop_recording()
                if success:
                    print(f"✅ Recording completed: {path}")
                    if os.path.exists(test_video):
                        size = os.path.getsize(test_video)
                        print(f"📹 Video size: {size} bytes")
                        os.remove(test_video)
                else:
                    print("❌ Recording stop failed")
            else:
                print("❌ Recording start failed")
    
    print("🏁 Camera interface test completed") 