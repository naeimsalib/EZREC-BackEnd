#!/bin/bash

echo "📷 Installing Picamera2 and Fixing Camera Interface"
echo "==================================================="
echo "Installing modern Pi Camera support..."
echo

# 1. Update system packages
echo "1. 📦 Updating System Packages"
echo "------------------------------"
sudo apt update

# Install required system packages for picamera2
echo "Installing system dependencies for picamera2..."
sudo apt install -y python3-picamera2 python3-libcamera python3-kms++ libcap-dev

echo "✅ System packages installed"
echo

# 2. Install picamera2 in the virtual environment
echo "2. 🐍 Installing Picamera2 in Virtual Environment"  
echo "------------------------------------------------"
cd /opt/ezrec-backend

echo "Installing picamera2 and dependencies..."
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install picamera2

# Also install some supporting packages
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install numpy opencv-python

echo "✅ Python packages installed"
echo

# 3. Test picamera2 installation
echo "3. 🧪 Testing Picamera2 Installation"
echo "-----------------------------------"
sudo -u ezrec timeout 10 bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 -c \"
try:
    from picamera2 import Picamera2
    print('✅ Picamera2 import successful')
    
    # Test camera initialization
    picam2 = Picamera2()
    camera_info = picam2.camera_info
    print(f'✅ Camera info: {camera_info}')
    picam2.close()
    
    print('✅ Picamera2 working correctly')
    
except Exception as e:
    print(f'❌ Picamera2 test failed: {e}')
\"
"
echo

# 4. Update camera interface for libcamera support
echo "4. 🔧 Updating Camera Interface for Modern Support"
echo "-------------------------------------------------"

# Create a backup of the current camera interface
sudo cp /opt/ezrec-backend/src/camera_interface.py /opt/ezrec-backend/src/camera_interface.py.backup

# Create an updated camera interface that prioritizes picamera2
sudo -u ezrec tee /opt/ezrec-backend/src/camera_interface_libcamera.py > /dev/null << 'EOF'
import logging
import time
import numpy as np
from typing import Optional, Dict, Any, Tuple
import subprocess
import os

logger = logging.getLogger(__name__)

class CameraInterface:
    """Modern camera interface using libcamera/picamera2 with OpenCV fallback"""
    
    def __init__(self):
        self.camera = None
        self.camera_type = None
        self.width = 1920
        self.height = 1080  
        self.fps = 30
        self.recording = False
        self.output_path = None
        
        # Try to initialize camera
        self.initialize()
    
    def initialize(self) -> bool:
        """Initialize camera with modern libcamera support"""
        try:
            # First try picamera2 (modern approach)
            return self._init_picamera2()
        except Exception as e:
            logger.warning(f"Picamera2 initialization failed: {e}")
            try:
                # Fallback to OpenCV
                return self._init_opencv()
            except Exception as e2:
                logger.error(f"All camera initialization failed: {e2}")
                return False
    
    def _init_picamera2(self) -> bool:
        """Initialize using picamera2 (preferred method)"""
        try:
            from picamera2 import Picamera2
            from picamera2.encoders import H264Encoder
            from picamera2.outputs import FileOutput
            
            self.camera = Picamera2()
            
            # Configure camera
            config = self.camera.create_video_configuration(
                main={"size": (self.width, self.height)},
                controls={"FrameRate": self.fps}
            )
            self.camera.configure(config)
            
            self.camera_type = "libcamera_picamera2"
            self.encoder = H264Encoder()
            
            logger.info(f"Picamera2 initialized: {self.width}x{self.height}@{self.fps}fps")
            return True
            
        except ImportError:
            logger.warning("Picamera2 not available")
            return False
        except Exception as e:
            logger.error(f"Picamera2 initialization error: {e}")
            return False
    
    def _init_opencv(self) -> bool:
        """Fallback OpenCV initialization"""
        try:
            import cv2
            
            # Try different camera indices
            for camera_id in [0, 1, 2]:
                cap = cv2.VideoCapture(camera_id)
                if cap.isOpened():
                    # Test if we can actually read a frame
                    ret, frame = cap.read()
                    if ret and frame is not None:
                        self.camera = cap
                        self.camera_type = f"opencv_camera_{camera_id}"
                        
                        # Set properties
                        self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
                        self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
                        self.camera.set(cv2.CAP_PROP_FPS, self.fps)
                        
                        logger.info(f"OpenCV camera {camera_id} initialized")
                        return True
                    else:
                        cap.release()
                else:
                    cap.release()
            
            logger.error("No working OpenCV camera found")
            return False
            
        except Exception as e:
            logger.error(f"OpenCV initialization error: {e}")
            return False
    
    def start_recording(self, filename: str) -> bool:
        """Start recording with libcamera support"""
        if not self.camera:
            raise RuntimeError("Camera not initialized")
            
        try:
            self.output_path = filename
            
            if self.camera_type == "libcamera_picamera2":
                return self._start_picamera2_recording(filename)
            else:
                return self._start_opencv_recording(filename)
                
        except Exception as e:
            logger.error(f"Failed to start recording: {e}")
            return False
    
    def _start_picamera2_recording(self, filename: str) -> bool:
        """Start recording with picamera2"""
        try:
            from picamera2.outputs import FileOutput
            
            output = FileOutput(filename)
            self.camera.start_recording(self.encoder, output)
            self.recording = True
            
            logger.info(f"Picamera2 recording started: {filename}")
            return True
            
        except Exception as e:
            logger.error(f"Picamera2 recording error: {e}")
            return False
    
    def _start_opencv_recording(self, filename: str) -> bool:
        """Start recording with OpenCV (fallback)"""
        try:
            import cv2
            
            fourcc = cv2.VideoWriter_fourcc(*'mp4v')
            self.video_writer = cv2.VideoWriter(
                filename, fourcc, self.fps, (self.width, self.height)
            )
            
            if not self.video_writer.isOpened():
                raise RuntimeError("Failed to open video writer")
            
            self.recording = True
            self._opencv_recording_thread(filename)
            
            logger.info(f"OpenCV recording started: {filename}")
            return True
            
        except Exception as e:
            logger.error(f"OpenCV recording error: {e}")
            return False
    
    def _opencv_recording_thread(self, filename: str):
        """Background thread for OpenCV recording"""
        import threading
        
        def record():
            while self.recording and self.camera:
                ret, frame = self.camera.read()
                if ret and frame is not None:
                    self.video_writer.write(frame)
                else:
                    break
        
        self.recording_thread = threading.Thread(target=record)
        self.recording_thread.daemon = True
        self.recording_thread.start()
    
    def stop_recording(self) -> bool:
        """Stop recording"""
        if not self.recording:
            return True
            
        try:
            self.recording = False
            
            if self.camera_type == "libcamera_picamera2":
                self.camera.stop_recording()
            else:
                # OpenCV cleanup
                if hasattr(self, 'video_writer'):
                    self.video_writer.release()
                if hasattr(self, 'recording_thread'):
                    self.recording_thread.join(timeout=5)
            
            logger.info("Recording stopped successfully")
            return True
            
        except Exception as e:
            logger.error(f"Error stopping recording: {e}")
            return False
    
    def capture_frame(self) -> Optional[np.ndarray]:
        """Capture a single frame"""
        if not self.camera:
            return None
            
        try:
            if self.camera_type == "libcamera_picamera2":
                # Capture with picamera2
                array = self.camera.capture_array()
                return array
            else:
                # Capture with OpenCV
                ret, frame = self.camera.read()
                return frame if ret else None
                
        except Exception as e:
            logger.error(f"Frame capture error: {e}")
            return None
    
    def get_camera_info(self) -> Dict[str, Any]:
        """Get camera information"""
        return {
            "camera_type": self.camera_type,
            "resolution": f"{self.width}x{self.height}",
            "fps": self.fps,
            "recording": self.recording,
            "initialized": self.camera is not None
        }
    
    def health_check(self) -> bool:
        """Check if camera is healthy"""
        if not self.camera:
            return False
            
        try:
            # Try to capture a frame
            frame = self.capture_frame()
            return frame is not None
        except:
            return False
    
    def release(self):
        """Release camera resources"""
        try:
            if self.recording:
                self.stop_recording()
                
            if self.camera:
                if self.camera_type == "libcamera_picamera2":
                    self.camera.close()
                else:
                    self.camera.release()
                    
            self.camera = None
            self.camera_type = None
            
        except Exception as e:
            logger.error(f"Error releasing camera: {e}")
EOF

# Replace the old camera interface
sudo mv /opt/ezrec-backend/src/camera_interface.py /opt/ezrec-backend/src/camera_interface_old.py
sudo mv /opt/ezrec-backend/src/camera_interface_libcamera.py /opt/ezrec-backend/src/camera_interface.py
sudo chown ezrec:ezrec /opt/ezrec-backend/src/camera_interface.py

echo "✅ Camera interface updated with libcamera support"
echo

# 5. Test new camera interface
echo "5. 🧪 Testing New Camera Interface"
echo "---------------------------------"
sudo -u ezrec timeout 15 bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 -c \"
import sys
sys.path.append('/opt/ezrec-backend/src')

try:
    from camera_interface import CameraInterface
    
    print('Testing new CameraInterface...')
    camera = CameraInterface()
    
    if camera.camera:
        info = camera.get_camera_info()
        print(f'✅ Camera initialized: {info}')
        
        # Test frame capture
        frame = camera.capture_frame()
        if frame is not None:
            print(f'✅ Frame captured: {frame.shape}')
        else:
            print('❌ Frame capture failed')
            
        # Test health check
        healthy = camera.health_check()
        print(f'✅ Health check: {healthy}')
        
    else:
        print('❌ Camera initialization failed')
        
    camera.release()
    
except Exception as e:
    print(f'❌ Camera interface test failed: {e}')
    import traceback
    traceback.print_exc()
\"
"
echo

# 6. Restart service with new camera interface
echo "6. 🔄 Restart Service with New Camera Interface"
echo "----------------------------------------------"
sudo systemctl restart ezrec-backend
sleep 5

echo "Service status:"
sudo systemctl status ezrec-backend --no-pager -l | head -10
echo

# 7. Final verification
echo "7. ✅ Final Camera Verification"
echo "------------------------------"
sleep 3

echo "Testing camera after full update..."
sudo journalctl -u ezrec-backend --since "30 seconds ago" --no-pager | grep -E "(Camera|camera|recording)" | tail -5

echo
echo "🎯 PICAMERA2 INSTALLATION AND FIX COMPLETE!"
echo "==========================================="
echo "📋 What was installed and fixed:"
echo "  ✅ Picamera2 system packages installed"
echo "  ✅ Picamera2 Python library installed"
echo "  ✅ Camera interface updated for modern libcamera support"
echo "  ✅ Service restarted with new camera interface"
echo
echo "🎬 Your camera should now work! Test with a booking:"
echo "  Create a booking from your frontend and watch:"
echo "  sudo journalctl -u ezrec-backend -f" 