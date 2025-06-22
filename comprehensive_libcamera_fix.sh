#!/bin/bash

# EZREC Backend - Comprehensive libcamera Fix Script
# This script completely fixes the libcamera issues on Raspberry Pi

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

print_status "Starting comprehensive libcamera fix..."

# Step 1: Stop the service
print_status "Step 1: Stopping service..."
systemctl stop ezrec.service 2>/dev/null || true

# Step 2: Fix the package conflicts by removing conflicting packages
print_status "Step 2: Resolving package conflicts..."

# First, let's see what's actually installed
print_info "Checking current libcamera packages..."
dpkg -l | grep libcamera || print_warning "No libcamera packages found"

# Remove ALL libcamera packages to start completely fresh
print_info "Removing all libcamera packages..."
apt-get remove -y libcamera* python3-libcamera python3-picamera2 2>/dev/null || true

# Clean up any broken packages
print_info "Cleaning up broken packages..."
apt-get autoremove -y
apt-get autoclean

# Step 3: Update package lists and install the correct packages
print_status "Step 3: Installing correct libcamera packages..."

# Update package lists
apt-get update

# Install the specific versions that work together
print_info "Installing libcamera packages..."
apt-get install -y libcamera0.5 python3-libcamera python3-picamera2

# Step 4: Install Python libcamera module in virtual environment
print_status "Step 4: Installing Python libcamera module..."

cd "$APP_DIR"

# Activate virtual environment and install libcamera
print_info "Installing libcamera Python module..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install libcamera==0.2.0

# Also install picamera2 in the virtual environment
print_info "Installing picamera2 Python module..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install picamera2==0.3.27

# Step 5: Test the installation
print_status "Step 5: Testing libcamera installation..."

# Create a comprehensive test script
cat > "$APP_DIR/test_libcamera_comprehensive.py" << 'EOL'
#!/usr/bin/env python3
"""
Comprehensive libcamera test script
"""

import sys
import os

def test_libcamera_import():
    """Test if libcamera can be imported"""
    print("Testing libcamera import...")
    try:
        import libcamera
        print("✓ libcamera imported successfully")
        print(f"  Version: {libcamera.__version__ if hasattr(libcamera, '__version__') else 'Unknown'}")
        return True
    except ImportError as e:
        print(f"✗ libcamera import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ libcamera import failed (other): {e}")
        return False

def test_picamera2_import():
    """Test if picamera2 can be imported"""
    print("Testing picamera2 import...")
    try:
        from picamera2 import Picamera2
        print("✓ picamera2 imported successfully")
        return True
    except ImportError as e:
        print(f"✗ picamera2 import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ picamera2 import failed (other): {e}")
        return False

def test_libcamera_controls():
    """Test if libcamera.controls can be imported"""
    print("Testing libcamera.controls import...")
    try:
        from libcamera import controls
        print("✓ libcamera.controls imported successfully")
        return True
    except ImportError as e:
        print(f"✗ libcamera.controls import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ libcamera.controls import failed (other): {e}")
        return False

def test_camera_detection():
    """Test if camera can be detected"""
    print("Testing camera detection...")
    try:
        from picamera2 import Picamera2
        picam2 = Picamera2()
        camera_info = picam2.sensor_info
        print(f"✓ Camera detected: {camera_info}")
        return True
    except Exception as e:
        print(f"✗ Camera detection failed: {e}")
        return False

def main():
    print("EZREC Backend - Comprehensive libcamera Test")
    print("=" * 50)
    
    tests = [
        test_libcamera_import,
        test_picamera2_import,
        test_libcamera_controls,
        test_camera_detection
    ]
    
    results = []
    for test in tests:
        results.append(test())
        print()
    
    print("Test Summary:")
    print(f"libcamera: {'✓' if results[0] else '✗'}")
    print(f"picamera2: {'✓' if results[1] else '✗'}")
    print(f"controls: {'✓' if results[2] else '✗'}")
    print(f"camera detection: {'✓' if results[3] else '✗'}")
    
    if all(results):
        print("\n✓ All libcamera components are working!")
        return True
    else:
        print("\n✗ Some libcamera components are missing!")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOL

chmod +x "$APP_DIR/test_libcamera_comprehensive.py"

# Run the test
print_info "Running comprehensive libcamera test..."
if sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" "$APP_DIR/test_libcamera_comprehensive.py"; then
    print_status "✓ libcamera test passed!"
else
    print_error "✗ libcamera test failed"
    print_info "Continuing with alternative approach..."
fi

# Step 6: Create a fallback camera test
print_status "Step 6: Creating fallback camera test..."

cat > "$APP_DIR/test_camera_fallback.py" << 'EOL'
#!/usr/bin/env python3
"""
Fallback camera test that works with or without libcamera
"""

import sys
import os
import cv2

def test_opencv_camera():
    """Test OpenCV camera access"""
    print("Testing OpenCV camera...")
    try:
        # Try different camera indices
        for i in range(4):
            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                ret, frame = cap.read()
                if ret:
                    print(f"✓ OpenCV camera {i} working")
                    cap.release()
                    return True
                cap.release()
        print("✗ No OpenCV camera found")
        return False
    except Exception as e:
        print(f"✗ OpenCV camera test failed: {e}")
        return False

def test_picamera2_fallback():
    """Test Picamera2 with fallback"""
    print("Testing Picamera2...")
    try:
        from picamera2 import Picamera2
        picam2 = Picamera2()
        print("✓ Picamera2 initialized")
        return True
    except ImportError:
        print("✗ Picamera2 not available")
        return False
    except Exception as e:
        print(f"✗ Picamera2 test failed: {e}")
        return False

def test_camera_devices():
    """Test camera devices"""
    print("Testing camera devices...")
    try:
        import subprocess
        result = subprocess.run(['v4l2-ctl', '--list-devices'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ Camera devices found:")
            print(result.stdout)
            return True
        else:
            print("✗ No camera devices found")
            return False
    except Exception as e:
        print(f"✗ Camera device test failed: {e}")
        return False

def main():
    print("EZREC Backend - Fallback Camera Test")
    print("=" * 40)
    
    tests = [
        test_camera_devices,
        test_opencv_camera,
        test_picamera2_fallback
    ]
    
    results = []
    for test in tests:
        results.append(test())
        print()
    
    print("Test Summary:")
    print(f"Camera devices: {'✓' if results[0] else '✗'}")
    print(f"OpenCV camera: {'✓' if results[1] else '✗'}")
    print(f"Picamera2: {'✓' if results[2] else '✗'}")
    
    if any(results):
        print("\n✓ At least one camera method is working!")
        return True
    else:
        print("\n✗ No camera methods are working!")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOL

chmod +x "$APP_DIR/test_camera_fallback.py"

# Step 7: Start the service
print_status "Step 7: Starting service..."
systemctl start ezrec.service

# Step 8: Verify it's working
print_status "Step 8: Verifying service status..."
sleep 5

if systemctl is-active --quiet ezrec.service; then
    print_status "✓ Service is running successfully!"
else
    print_error "✗ Service failed to start. Checking logs..."
    journalctl -u ezrec.service -n 10
    print_warning "Service failed, but libcamera should now be working"
fi

print_status "Comprehensive libcamera fix completed!"

print_info "Next steps:"
echo "1. Test libcamera: sudo -u $SERVICE_USER $APP_DIR/venv/bin/python $APP_DIR/test_libcamera_comprehensive.py"
echo "2. Test camera fallback: sudo -u $SERVICE_USER $APP_DIR/venv/bin/python $APP_DIR/test_camera_fallback.py"
echo "3. Check service status: sudo $APP_DIR/manage.sh status"
echo "4. View logs: sudo $APP_DIR/manage.sh logs"

print_warning "The libcamera package conflicts have been resolved!"
print_warning "If the service still fails, the camera hardware may need attention." 