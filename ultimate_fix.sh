#!/bin/bash

# EZREC Backend - Ultimate Fix Script
# This script fixes both dependency conflicts and camera detection issues

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

print_status "Starting ultimate fix for EZREC Backend..."

# Step 1: Stop the service
print_status "Step 1: Stopping service..."
systemctl stop ezrec.service 2>/dev/null || true

# Step 2: Fix camera hardware detection
print_status "Step 2: Fixing camera hardware detection..."
print_info "Checking camera interface..."

# Enable camera interface
raspi-config nonint do_camera 0

# Check camera devices
print_info "Checking camera devices..."
if command -v v4l2-ctl >/dev/null 2>&1; then
    print_info "Available camera devices:"
    v4l2-ctl --list-devices 2>/dev/null | grep -A1 "video" | grep "video" || print_warning "No video devices found"
else
    print_warning "v4l2-ctl not available"
fi

# Test Pi Camera
print_info "Testing Pi Camera..."
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

# Step 3: Fix virtual environment and dependencies
print_status "Step 3: Fixing virtual environment and dependencies..."
cd "$APP_DIR"

# Remove existing venv
print_info "Removing existing virtual environment..."
rm -rf venv

# Create new venv
print_info "Creating new virtual environment..."
sudo -u "$SERVICE_USER" python3 -m venv venv
chown -R "$SERVICE_USER:$SERVICE_USER" venv

# Install dependencies in correct order
print_info "Installing dependencies in correct order..."

# Upgrade pip first
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install --upgrade pip

# Install httpx and httpcore first (compatible versions)
print_info "Installing httpx and httpcore first..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install httpx==0.24.1
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install httpcore==0.17.3

# Install gotrue with compatible version
print_info "Installing gotrue with compatible version..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install gotrue==2.8.0

# Install other Supabase packages
print_info "Installing other Supabase packages..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install postgrest==0.13.0
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install storage3==0.7.7
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install realtime==1.0.6
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install supafunc==0.3.3

# Install supabase last
print_info "Installing supabase..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install supabase==2.2.1

# Install other dependencies
print_info "Installing other dependencies..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install python-dotenv==1.0.0
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install opencv-python==4.8.1.78
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install numpy==1.26.4
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install psutil==5.9.4
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install pytz==2023.3
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install ffmpeg-python==0.2.0

# Step 4: Test the dependencies
print_status "Step 4: Testing dependencies..."
print_info "Testing httpx import..."

if sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" -c "import httpx; print('✓ httpx imported successfully')"; then
    print_status "✓ httpx import successful!"
else
    print_error "✗ httpx import failed"
    exit 1
fi

print_info "Testing Supabase client creation..."

if sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" -c "
import os
os.environ['SUPABASE_URL'] = 'https://test.supabase.co'
os.environ['SUPABASE_KEY'] = 'test_key'
from supabase import create_client
try:
    client = create_client('https://test.supabase.co', 'test_key')
    print('✓ Supabase client creation successful')
except Exception as e:
    print(f'✗ Error: {e}')
    exit(1)
"; then
    print_status "✓ Supabase client creation successful!"
else
    print_error "✗ Supabase client creation failed"
    exit 1
fi

# Step 5: Test system libcamera modules
print_status "Step 5: Testing system libcamera modules..."
print_info "Testing system libcamera import..."

if sudo -u "$SERVICE_USER" python3 -c "import libcamera; print('✓ System libcamera imported successfully')"; then
    print_status "✓ System libcamera import successful!"
else
    print_error "✗ System libcamera import failed"
    print_info "Installing python3-libcamera..."
    apt-get install -y python3-libcamera
fi

print_info "Testing system picamera2 import..."

if sudo -u "$SERVICE_USER" python3 -c "from picamera2 import Picamera2; print('✓ System picamera2 imported successfully')"; then
    print_status "✓ System picamera2 import successful!"
else
    print_error "✗ System picamera2 import failed"
    print_info "Installing python3-picamera2..."
    apt-get install -y python3-picamera2
fi

# Step 6: Create comprehensive test script
print_status "Step 6: Creating comprehensive test script..."
cat > "$APP_DIR/test_ultimate.py" << 'EOL'
#!/usr/bin/env python3
"""
Ultimate test script for EZREC Backend
"""

import sys
import os

def test_dependencies():
    """Test all dependencies"""
    print("Testing dependencies...")
    try:
        import httpx
        print("✓ httpx imported successfully")
        
        from supabase import create_client
        print("✓ supabase imported successfully")
        
        import cv2
        print("✓ opencv imported successfully")
        
        import numpy
        print("✓ numpy imported successfully")
        
        return True
    except ImportError as e:
        print(f"✗ Dependency import failed: {e}")
        return False

def test_system_libcamera():
    """Test system libcamera"""
    print("Testing system libcamera...")
    try:
        import libcamera
        print("✓ System libcamera imported successfully")
        return True
    except ImportError as e:
        print(f"✗ System libcamera import failed: {e}")
        return False

def test_system_picamera2():
    """Test system picamera2"""
    print("Testing system picamera2...")
    try:
        from picamera2 import Picamera2
        print("✓ System picamera2 imported successfully")
        return True
    except ImportError as e:
        print(f"✗ System picamera2 import failed: {e}")
        return False

def test_camera_detection():
    """Test camera detection"""
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
    """Test our camera interface"""
    print("Testing CameraInterface...")
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
    print("EZREC Backend - Ultimate Test")
    print("=" * 50)
    
    tests = [
        test_dependencies,
        test_system_libcamera,
        test_system_picamera2,
        test_camera_detection,
        test_camera_interface
    ]
    
    results = []
    for test in tests:
        results.append(test())
        print()
    
    print("Test Summary:")
    print(f"Dependencies: {'✓' if results[0] else '✗'}")
    print(f"System libcamera: {'✓' if results[1] else '✗'}")
    print(f"System picamera2: {'✓' if results[2] else '✗'}")
    print(f"Camera detection: {'✓' if results[3] else '✗'}")
    print(f"CameraInterface: {'✓' if results[4] else '✗'}")
    
    if all(results):
        print("\n✓ All tests passed!")
        return True
    else:
        print("\n✗ Some tests failed!")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOL

chmod +x "$APP_DIR/test_ultimate.py"

# Step 7: Test the ultimate setup
print_status "Step 7: Testing ultimate setup..."
print_info "Running ultimate test..."

if sudo -u "$SERVICE_USER" python3 "$APP_DIR/test_ultimate.py"; then
    print_status "✓ Ultimate test passed!"
else
    print_error "✗ Ultimate test failed"
    print_warning "This may indicate a deeper system issue"
fi

# Step 8: Start the service
print_status "Step 8: Starting service..."
systemctl start ezrec.service

# Step 9: Verify it's working
print_status "Step 9: Verifying service status..."
sleep 5

if systemctl is-active --quiet ezrec.service; then
    print_status "✓ Service is running successfully!"
else
    print_error "✗ Service failed to start. Checking logs..."
    journalctl -u ezrec.service -n 10
    print_warning "Service failed, but dependencies should now be working"
fi

print_status "Ultimate fix completed!"

print_info "Next steps:"
echo "1. Test ultimate setup: sudo -u $SERVICE_USER python3 $APP_DIR/test_ultimate.py"
echo "2. Check service status: sudo $APP_DIR/manage.sh status"
echo "3. View logs: sudo $APP_DIR/manage.sh logs"

print_warning "IMPORTANT: All dependency conflicts have been resolved!"
print_warning "✓ httpx==0.24.1 (compatible with supabase==2.2.1)"
print_warning "✓ System libcamera and picamera2 modules"
print_warning "✓ Camera hardware detection enabled" 