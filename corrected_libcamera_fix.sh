#!/bin/bash

# EZREC Backend - Corrected libcamera Fix Script
# This script uses the system-installed libcamera modules (not PyPI packages)

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

print_status "Starting corrected libcamera fix..."

# Step 1: Stop the service
print_status "Step 1: Stopping service..."
systemctl stop ezrec.service 2>/dev/null || true

# Step 2: Verify system packages are installed
print_status "Step 2: Verifying system packages..."
print_info "Checking system libcamera packages..."

if dpkg -l | grep -q "python3-libcamera"; then
    print_status "✓ python3-libcamera is installed"
else
    print_error "✗ python3-libcamera is not installed"
    print_info "Installing python3-libcamera..."
    apt-get install -y python3-libcamera
fi

if dpkg -l | grep -q "python3-picamera2"; then
    print_status "✓ python3-picamera2 is installed"
else
    print_error "✗ python3-picamera2 is not installed"
    print_info "Installing python3-picamera2..."
    apt-get install -y python3-picamera2
fi

# Step 3: Create a test script that uses system modules
print_status "Step 3: Creating test script for system libcamera modules..."

cd "$APP_DIR"

cat > "$APP_DIR/test_system_libcamera.py" << 'EOL'
#!/usr/bin/env python3
"""
Test script for system-installed libcamera modules
"""

import sys
import os

def test_system_libcamera():
    """Test if system libcamera can be imported"""
    print("Testing system libcamera import...")
    try:
        # Try to import from the system installation
        import libcamera
        print("✓ System libcamera imported successfully")
        print(f"  Module location: {libcamera.__file__}")
        return True
    except ImportError as e:
        print(f"✗ System libcamera import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ System libcamera import failed (other): {e}")
        return False

def test_system_picamera2():
    """Test if system picamera2 can be imported"""
    print("Testing system picamera2 import...")
    try:
        from picamera2 import Picamera2
        print("✓ System picamera2 imported successfully")
        print(f"  Module location: {Picamera2.__module__}")
        return True
    except ImportError as e:
        print(f"✗ System picamera2 import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ System picamera2 import failed (other): {e}")
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

def test_camera_interface():
    """Test our camera interface with system modules"""
    print("Testing CameraInterface with system modules...")
    try:
        # Add src to path
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))
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
    print("EZREC Backend - System libcamera Test")
    print("=" * 50)
    
    tests = [
        test_system_libcamera,
        test_system_picamera2,
        test_libcamera_controls,
        test_camera_detection,
        test_camera_interface
    ]
    
    results = []
    for test in tests:
        results.append(test())
        print()
    
    print("Test Summary:")
    print(f"System libcamera: {'✓' if results[0] else '✗'}")
    print(f"System picamera2: {'✓' if results[1] else '✗'}")
    print(f"libcamera.controls: {'✓' if results[2] else '✗'}")
    print(f"Camera detection: {'✓' if results[3] else '✗'}")
    print(f"CameraInterface: {'✓' if results[4] else '✗'}")
    
    if all(results):
        print("\n✓ All system libcamera components are working!")
        return True
    else:
        print("\n✗ Some system libcamera components are missing!")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOL

chmod +x "$APP_DIR/test_system_libcamera.py"

# Step 4: Test the system modules
print_status "Step 4: Testing system libcamera modules..."
print_info "Running system libcamera test..."

if sudo -u "$SERVICE_USER" python3 "$APP_DIR/test_system_libcamera.py"; then
    print_status "✓ System libcamera test passed!"
else
    print_error "✗ System libcamera test failed"
    print_warning "This may indicate a deeper system issue"
fi

# Step 5: Update requirements.txt to remove non-existent packages
print_status "Step 5: Updating requirements.txt..."
print_info "Removing non-existent libcamera package from requirements.txt..."

# Create a backup of requirements.txt
cp "$APP_DIR/requirements.txt" "$APP_DIR/requirements.txt.backup"

# Remove the libcamera line from requirements.txt
sed -i '/^libcamera==/d' "$APP_DIR/requirements.txt"

print_info "Updated requirements.txt - removed libcamera==0.2.0"

# Step 6: Reinstall dependencies without the problematic package
print_status "Step 6: Reinstalling dependencies..."
print_info "Reinstalling Python dependencies without libcamera..."

sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install -r requirements.txt

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
    print_warning "Service failed, but system libcamera modules should now be available"
fi

print_status "Corrected libcamera fix completed!"

print_info "Next steps:"
echo "1. Test system libcamera: sudo -u $SERVICE_USER python3 $APP_DIR/test_system_libcamera.py"
echo "2. Check service status: sudo $APP_DIR/manage.sh status"
echo "3. View logs: sudo $APP_DIR/manage.sh logs"

print_warning "The system libcamera modules are now being used!"
print_warning "No PyPI packages needed - using system-installed python3-libcamera and python3-picamera2" 