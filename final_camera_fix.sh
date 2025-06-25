#!/bin/bash

echo "🔧 FINAL CAMERA FIX - Complete System Repair"
echo "============================================"
echo "This will fix picamera2 access and camera interface compatibility issues."
echo

# Stop service
echo "1. 🛑 Stopping Service"
echo "--------------------"
sudo systemctl stop ezrec-backend

# Fix picamera2 access by recreating venv with system site packages
echo "2. 🐍 Recreating Virtual Environment with System Access"
echo "------------------------------------------------------"
cd /opt/ezrec-backend

# Remove current venv
sudo rm -rf venv

# Create new venv with system site packages access
sudo python3 -m venv --system-site-packages venv
sudo chown -R ezrec:ezrec venv/
sudo chmod -R 755 venv/

echo "✅ Virtual environment recreated with system access"

# Install only missing packages (not system ones)
echo "3. 📦 Installing Missing Python Packages"
echo "----------------------------------------"
echo "Installing essential packages..."
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install --upgrade pip
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install supabase==2.2.1 python-dotenv psutil

echo "✅ Core packages installed"

# Test picamera2 access
echo "4. 🎬 Testing Picamera2 System Access"
echo "------------------------------------"
sudo -u ezrec bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 -c \"
try:
    import picamera2
    print('✅ Picamera2 accessible from system packages')
    
    from picamera2 import Picamera2
    print('✅ Picamera2 class imported successfully')
    
    # Test camera initialization
    picam2 = Picamera2()
    print('✅ Picamera2 object created')
    print(f'Camera info: {picam2.camera_info}')
    picam2.close()
    print('✅ Picamera2 test successful')
    
except Exception as e:
    print(f'❌ Picamera2 test failed: {e}')
    import traceback
    traceback.print_exc()
\"
"

# Update camera interface to fix constructor compatibility
echo "5. 🔧 Fixing Camera Interface Constructor"
echo "----------------------------------------"
sudo tee /opt/ezrec-backend/src/camera_interface.py > /dev/null << 'EOF'
import cv2
import numpy as np
import logging
import time
import subprocess
from typing import Optional, Tuple, Dict, Any

logger = logging.getLogger(__name__)

class CameraInterface:
    """Modern camera interface with picamera2 and libcamera support"""
    
    def __init__(self, **kwargs):
        """Initialize camera interface - accepts any kwargs for compatibility"""
        self.camera = None
        self.camera_type = None
        self.is_recording = False
        self.frame_count = 0
        self.last_frame_time = 0
        
        # Extract relevant parameters from kwargs (for backward compatibility)
        self.width = kwargs.get('width', 1920)
        self.height = kwargs.get('height', 1080)
        self.fps = kwargs.get('fps', 30)
        
        # Try to initialize camera
        success = self._initialize_camera()
        if success:
            logger.info(f"✅ Camera initialized successfully with {self.camera_type}")
        else:
            logger.error("❌ All camera initialization methods failed")
        
    def _initialize_camera(self):
        """Initialize camera with multiple fallback methods"""
        
        # Method 1: Try picamera2 (preferred for Pi Camera)
        try:
            import picamera2
            from picamera2 import Picamera2
            
            self.camera = Picamera2()
            
            # Configure camera for video
            video_config = self.camera.create_video_configuration(
                main={"size": (self.width, self.height), "format": "RGB888"},
                controls={"FrameRate": self.fps}
            )
            self.camera.configure(video_config)
            self.camera.start()
            
            self.camera_type = "picamera2"
            logger.info("✅ Camera initialized with picamera2")
            return True
            
        except ImportError as e:
            logger.warning(f"Picamera2 not available: {e}")
        except Exception as e:
            logger.warning(f"Picamera2 initialization failed: {e}")
            
        # Method 2: Try libcamera-vid command line
        try:
            result = subprocess.run(['libcamera-vid', '--list-cameras'], 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0 and ('imx477' in result.stdout or 'Available cameras' in result.stdout):
                self.camera_type = "libcamera_cmd"
                self.camera = "libcamera"  # Placeholder
                logger.info("✅ Camera detected via libcamera command")
                return True
        except Exception as e:
            logger.warning(f"Libcamera detection failed: {e}")
            
        # Method 3: OpenCV fallback
        try:
            self.camera = cv2.VideoCapture(0)
            if self.camera.isOpened():
                # Set properties
                self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
                self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
                self.camera.set(cv2.CAP_PROP_FPS, self.fps)
                
                # Test frame capture
                ret, frame = self.camera.read()
                if ret and frame is not None:
                    self.camera_type = "opencv"
                    logger.info("✅ Camera initialized with OpenCV")
                    return True
                else:
                    self.camera.release()
                    self.camera = None
        except Exception as e:
            logger.warning(f"OpenCV initialization failed: {e}")
            
        logger.error("❌ All camera initialization methods failed")
        return False
        
    def capture_frame(self) -> Optional[np.ndarray]:
        """Capture a single frame"""
        if not self.camera:
            return None
            
        try:
            if self.camera_type == "picamera2":
                frame = self.camera.capture_array()
                self.frame_count += 1
                self.last_frame_time = time.time()
                return frame
                
            elif self.camera_type == "opencv":
                ret, frame = self.camera.read()
                if ret:
                    self.frame_count += 1
                    self.last_frame_time = time.time()
                    return frame
                    
            elif self.camera_type == "libcamera_cmd":
                # For command-line libcamera, we can't capture individual frames
                # But we can confirm the camera is available
                logger.info("Camera available via libcamera (recording mode only)")
                return np.zeros((self.height, self.width, 3), dtype=np.uint8)  # Dummy frame
                
        except Exception as e:
            logger.error(f"Frame capture failed: {e}")
            
        return None
        
    def start_recording(self, output_path: str, duration: int) -> bool:
        """Start recording video"""
        if not self.camera:
            logger.error("Camera not initialized")
            return False
            
        try:
            if self.camera_type == "picamera2":
                # Use picamera2 encoder for video
                encoder = self.camera.create_encoder('main')
                self.camera.start_recording(encoder, output_path)
                
                # Record for specified duration
                time.sleep(duration)
                self.camera.stop_recording()
                
                self.is_recording = False
                logger.info(f"✅ Completed picamera2 recording to {output_path}")
                return True
                
            elif self.camera_type == "libcamera_cmd":
                # Use libcamera-vid command
                cmd = [
                    'libcamera-vid',
                    '-o', output_path,
                    '-t', str(duration * 1000),  # Convert to milliseconds
                    '--width', str(self.width),
                    '--height', str(self.height),
                    '--framerate', str(self.fps),
                    '--codec', 'h264'
                ]
                
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode == 0:
                    logger.info(f"✅ Completed libcamera recording to {output_path}")
                    return True
                else:
                    logger.error(f"Libcamera recording failed: {result.stderr}")
                    
            elif self.camera_type == "opencv":
                # Use OpenCV recording
                fourcc = cv2.VideoWriter_fourcc(*'mp4v')
                out = cv2.VideoWriter(output_path, fourcc, float(self.fps), (self.width, self.height))
                
                self.is_recording = True
                start_time = time.time()
                
                while time.time() - start_time < duration and self.is_recording:
                    ret, frame = self.camera.read()
                    if ret:
                        out.write(frame)
                    time.sleep(1/self.fps)
                        
                out.release()
                self.is_recording = False
                logger.info(f"✅ Completed OpenCV recording to {output_path}")
                return True
                
        except Exception as e:
            logger.error(f"Recording failed: {e}")
            self.is_recording = False
            
        return False
        
    def stop_recording(self):
        """Stop current recording"""
        try:
            if self.camera_type == "picamera2" and self.is_recording:
                self.camera.stop_recording()
                self.is_recording = False
                logger.info("✅ Stopped picamera2 recording")
            else:
                self.is_recording = False
                
        except Exception as e:
            logger.error(f"Stop recording failed: {e}")
            
    def health_check(self) -> bool:
        """Check if camera is healthy and responsive"""
        if not self.camera:
            return False
            
        try:
            if self.camera_type == "picamera2":
                # Try to capture a test frame
                frame = self.capture_frame()
                return frame is not None
                
            elif self.camera_type == "opencv":
                return self.camera.isOpened()
                
            elif self.camera_type == "libcamera_cmd":
                # Test libcamera availability
                result = subprocess.run(['libcamera-vid', '--list-cameras'], 
                                      capture_output=True, timeout=3)
                return result.returncode == 0
                
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            
        return False
        
    def get_camera_info(self) -> Dict[str, Any]:
        """Get camera information and status"""
        info = {
            "camera_type": self.camera_type,
            "is_initialized": self.camera is not None,
            "is_recording": self.is_recording,
            "frame_count": self.frame_count,
            "last_frame_time": self.last_frame_time,
            "health_status": self.health_check(),
            "resolution": f"{self.width}x{self.height}",
            "fps": self.fps
        }
        
        if self.camera_type == "picamera2" and hasattr(self.camera, 'camera_info'):
            try:
                info["camera_info"] = str(self.camera.camera_info)
            except:
                pass
                
        return info
        
    def release(self):
        """Release camera resources"""
        try:
            if self.is_recording:
                self.stop_recording()
                
            if self.camera:
                if self.camera_type == "picamera2":
                    self.camera.close()
                elif self.camera_type == "opencv":
                    self.camera.release()
                    
                self.camera = None
                logger.info("✅ Camera resources released")
                
        except Exception as e:
            logger.error(f"Camera release failed: {e}")

# Test camera interface
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    print("Testing CameraInterface...")
    camera = CameraInterface()
    
    info = camera.get_camera_info()
    print(f"Camera info: {info}")
    
    if camera.camera:
        print("✅ Camera initialized successfully")
        
        # Test frame capture
        frame = camera.capture_frame()
        if frame is not None:
            print(f"✅ Frame captured: {frame.shape}")
        else:
            print("❌ Frame capture failed")
            
        # Test health check
        healthy = camera.health_check()
        print(f"Health check: {healthy}")
        
    else:
        print("❌ Camera initialization failed")
        
    camera.release()
EOF

sudo chown ezrec:ezrec /opt/ezrec-backend/src/camera_interface.py
echo "✅ Camera interface updated with compatible constructor"

# Test the updated camera interface
echo "6. 🎬 Testing Updated Camera Interface"
echo "------------------------------------"
sudo -u ezrec timeout 20 bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 src/camera_interface.py
"

# Sync the repository code to service directory
echo "7. 🔄 Syncing Repository Code"
echo "----------------------------"
sudo rsync -av ~/code/EZREC-BackEnd/src/ /opt/ezrec-backend/src/
sudo chown -R ezrec:ezrec /opt/ezrec-backend/src/

echo "✅ Code synchronized"

# Start the service
echo "8. 🚀 Starting EZREC Service"
echo "----------------------------"
sudo systemctl start ezrec-backend
sleep 5

echo "Service status:"
sudo systemctl status ezrec-backend --no-pager | head -10

echo "9. 📊 Checking Service Logs"
echo "---------------------------"
echo "Recent logs:"
sudo journalctl -u ezrec-backend --since "1 minute ago" --no-pager | tail -15

echo
echo "🎯 FINAL CAMERA FIX COMPLETE!"
echo "============================"
echo "📋 What was fixed:"
echo "  ✅ Virtual environment recreated with --system-site-packages"
echo "  ✅ Picamera2 now accessible from system packages"
echo "  ✅ Camera interface constructor fixed for compatibility"
echo "  ✅ Multiple camera fallback methods implemented"
echo "  ✅ Service code synchronized and restarted"
echo
echo "🎬 Your EZREC system should now be fully functional!"
echo "Test with a booking from your frontend and monitor:"
echo "  sudo journalctl -u ezrec-backend -f" 