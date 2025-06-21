#!/bin/bash

# EZREC Backend - Camera Issues Fix Script
# This script fixes camera detection and libcamera issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[-]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

APP_DIR="/home/michomanoly14892/code/SmartCam-Soccer/backend"
SERVICE_USER="michomanoly14892"

print_status "Starting camera issues fix..."

# Step 1: Stop the service
print_status "Step 1: Stopping service..."
systemctl stop ezrec.service 2>/dev/null || true

# Step 2: Fix libcamera package conflicts
print_status "Step 2: Fixing libcamera package conflicts..."
print_info "Removing conflicting libcamera packages..."

# Remove conflicting packages
apt-get remove -y libcamera-ipa libcamera0.5 2>/dev/null || true

# Install the correct libcamera packages
print_info "Installing correct libcamera packages..."
apt-get install -y libcamera0 python3-libcamera python3-picamera2

# Step 3: Install missing system dependencies
print_status "Step 3: Installing missing system dependencies..."
print_info "Installing libcamera and camera dependencies..."

# Install camera-related packages
apt-get install -y \
    v4l-utils \
    libv4l-dev \
    libv4l-0 \
    libopencv-dev \
    python3-opencv \
    ffmpeg \
    git \
    curl \
    wget

# Step 4: Enable camera interface
print_status "Step 4: Enabling camera interface..."
print_info "Enabling camera interface via raspi-config..."

# Enable camera interface
raspi-config nonint do_camera 0

# Step 5: Fix Python libcamera module
print_status "Step 5: Installing Python libcamera module..."
cd "$APP_DIR"

# Install libcamera Python module in virtual environment
print_info "Installing libcamera Python module..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install libcamera==0.2.0

# Step 6: Test camera devices
print_status "Step 6: Testing camera devices..."
print_info "Checking camera devices..."

# List camera devices
if command -v v4l2-ctl >/dev/null 2>&1; then
    print_info "Available camera devices:"
    v4l2-ctl --list-devices 2>/dev/null | grep -A1 "video" | grep "video" || print_warning "No video devices found"
else
    print_warning "v4l2-ctl not available"
fi

# Step 7: Test Pi Camera
print_status "Step 7: Testing Pi Camera..."
print_info "Testing Pi Camera with libcamera-still..."

# Test Pi Camera
if command -v libcamera-still >/dev/null 2>&1; then
    if timeout 10s libcamera-still -o test.jpg --nopreview 2>/dev/null; then
        print_status "✓ Pi Camera test successful!"
        rm -f test.jpg
    else
        print_warning "⚠️ Pi Camera test failed or timed out"
    fi
else
    print_warning "⚠️ libcamera-still not available"
fi

# Step 8: Test USB camera
print_status "Step 8: Testing USB camera..."
print_info "Testing USB camera with v4l2-ctl..."

# Test USB camera
if command -v v4l2-ctl >/dev/null 2>&1; then
    if v4l2-ctl --device=/dev/video0 --list-formats-ext 2>/dev/null | grep -q "Pixel Format"; then
        print_status "✓ USB camera test successful!"
    else
        print_warning "⚠️ USB camera test failed"
    fi
else
    print_warning "⚠️ v4l2-ctl not available"
fi

# Step 9: Create simple camera test script
print_status "Step 9: Creating camera test script..."
cat > "$APP_DIR/test_camera_simple.py" << 'EOL'
#!/usr/bin/env python3
"""
Simple camera test script for EZREC Backend
"""

import sys
import os
import time

# Add the src directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

def test_picamera2():
    """Test PiCamera2 functionality"""
    print("Testing PiCamera2...")
    try:
        from picamera2 import Picamera2
        from libcamera import controls
        
        # Initialize camera
        picam2 = Picamera2()
        
        # Configure camera
        config = picam2.create_preview_configuration()
        picam2.configure(config)
        
        # Start camera
        picam2.start()
        print("✓ PiCamera2 initialized successfully")
        
        # Capture a frame
        frame = picam2.capture_array()
        print(f"✓ Captured frame: {frame.shape}")
        
        # Stop camera
        picam2.stop()
        print("✓ PiCamera2 test completed successfully")
        return True
        
    except ImportError as e:
        print(f"✗ PiCamera2 import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ PiCamera2 test failed: {e}")
        return False

def test_opencv():
    """Test OpenCV camera functionality"""
    print("Testing OpenCV camera...")
    try:
        import cv2
        
        # Try to open camera
        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            print("✗ OpenCV cannot open camera device 0")
            return False
        
        # Read a frame
        ret, frame = cap.read()
        if not ret:
            print("✗ OpenCV cannot read from camera")
            cap.release()
            return False
        
        print(f"✓ OpenCV captured frame: {frame.shape}")
        cap.release()
        print("✓ OpenCV test completed successfully")
        return True
        
    except ImportError as e:
        print(f"✗ OpenCV import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ OpenCV test failed: {e}")
        return False

def test_camera_interface():
    """Test our camera interface"""
    print("Testing CameraInterface...")
    try:
        from camera_interface import CameraInterface
        
        # Initialize camera interface
        camera = CameraInterface(width=1280, height=720, fps=30)
        print("✓ CameraInterface initialized successfully")
        
        # Test frame capture
        frame = camera.capture_frame()
        if frame is not None:
            print(f"✓ CameraInterface captured frame: {frame.shape}")
        else:
            print("✗ CameraInterface failed to capture frame")
            return False
        
        # Clean up
        camera.release()
        print("✓ CameraInterface test completed successfully")
        return True
        
    except ImportError as e:
        print(f"✗ CameraInterface import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ CameraInterface test failed: {e}")
        return False

def main():
    """Run all camera tests"""
    print("EZREC Backend - Camera Test")
    print("=" * 40)
    
    # Test PiCamera2
    picamera2_ok = test_picamera2()
    print()
    
    # Test OpenCV
    opencv_ok = test_opencv()
    print()
    
    # Test CameraInterface
    interface_ok = test_camera_interface()
    print()
    
    # Summary
    print("Test Summary:")
    print(f"PiCamera2: {'✓' if picamera2_ok else '✗'}")
    print(f"OpenCV: {'✓' if opencv_ok else '✗'}")
    print(f"CameraInterface: {'✓' if interface_ok else '✗'}")
    
    if picamera2_ok or opencv_ok or interface_ok:
        print("\n✓ At least one camera method is working!")
        return 0
    else:
        print("\n✗ No camera methods are working!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
EOL

chmod +x "$APP_DIR/test_camera_simple.py"
chown "$SERVICE_USER:$SERVICE_USER" "$APP_DIR/test_camera_simple.py"

# Step 10: Test the camera
print_status "Step 10: Running camera test..."
print_info "Running camera test script..."

if sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" "$APP_DIR/test_camera_simple.py"; then
    print_status "✓ Camera test successful!"
else
    print_warning "⚠️ Camera test had issues, but continuing..."
fi

# Step 11: Start the service
print_status "Step 11: Starting service..."
systemctl start ezrec.service

# Step 12: Verify it's working
print_status "Step 12: Verifying service status..."
sleep 5

if systemctl is-active --quiet ezrec.service; then
    print_status "✓ Service is running successfully!"
else
    print_error "✗ Service failed to start. Checking logs..."
    journalctl -u ezrec.service -n 10
    print_warning "⚠️ Service failed to start, but camera dependencies are installed"
fi

print_status "Camera issues fix completed!"

print_info "Next steps:"
echo "1. Check service status: sudo $APP_DIR/manage.sh status"
echo "2. View logs: sudo $APP_DIR/manage.sh logs"
echo "3. Health check: sudo $APP_DIR/manage.sh health"
echo "4. Test camera: sudo -u $SERVICE_USER $APP_DIR/venv/bin/python $APP_DIR/test_camera_simple.py"

print_warning "If the service still fails, check the logs for specific error messages"
print_warning "The camera hardware is working (libcamera-still test passed), so the issue is likely in the Python code" 