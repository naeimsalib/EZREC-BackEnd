#!/bin/bash

# EZREC Backend - Camera Issues Fix Script
# This script fixes camera detection and libcamera issues on Raspberry Pi

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

# Step 2: Install missing system dependencies
print_status "Step 2: Installing missing system dependencies..."

# Update package list
apt-get update

# Install libcamera and related packages
print_info "Installing libcamera and camera dependencies..."
apt-get install -y \
    libcamera0 \
    libcamera-apps-lite \
    python3-libcamera \
    python3-picamera2 \
    v4l-utils \
    libv4l-dev \
    libv4l-0 \
    libopencv-dev \
    python3-opencv

# Step 3: Enable camera interface
print_status "Step 3: Enabling camera interface..."
print_info "Enabling camera interface via raspi-config..."

# Check if we're on a Raspberry Pi
if [ -f "/proc/device-tree/model" ]; then
    PI_MODEL=$(cat /proc/device-tree/model)
    if [[ "$PI_MODEL" == *"Raspberry Pi"* ]]; then
        print_info "Raspberry Pi detected: $PI_MODEL"
        
        # Enable camera interface
        raspi-config nonint do_camera 0
        
        # Enable legacy camera support if needed
        raspi-config nonint do_legacy 0
        
        print_info "Camera interface enabled"
    else
        print_warning "Not a Raspberry Pi, skipping raspi-config"
    fi
else
    print_warning "Could not detect Raspberry Pi model"
fi

# Step 4: Check camera devices
print_status "Step 4: Checking camera devices..."
print_info "Available video devices:"
ls -la /dev/video* 2>/dev/null || print_warning "No video devices found"

print_info "Camera devices detected by v4l2-ctl:"
v4l2-ctl --list-devices 2>/dev/null || print_warning "v4l2-ctl not available"

# Step 5: Check for Pi Camera
print_status "Step 5: Checking for Pi Camera..."
if [ -d "/dev/video0" ] || [ -d "/dev/video1" ]; then
    print_info "Video devices found"
    
    # Test each video device
    for device in /dev/video*; do
        if [ -e "$device" ]; then
            print_info "Testing $device..."
            if v4l2-ctl --device="$device" --list-formats-ext 2>/dev/null; then
                print_status "✓ $device is working"
            else
                print_warning "✗ $device has issues"
            fi
        fi
    done
else
    print_warning "No video devices found"
fi

# Step 6: Install Python dependencies
print_status "Step 6: Installing Python dependencies..."
cd "$APP_DIR"

# Install libcamera Python package
print_info "Installing libcamera Python package..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install libcamera==0.2.0

# Reinstall picamera2 with proper dependencies
print_info "Reinstalling picamera2..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" uninstall -y picamera2
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install picamera2==0.3.27

# Step 7: Test camera detection
print_status "Step 7: Testing camera detection..."
print_info "Testing camera detection in Python..."

# Test camera detection
if sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" -c "
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

try:
    from camera_interface import CameraInterface
    print('✓ CameraInterface imported successfully')
    
    # Test camera detection
    try:
        camera = CameraInterface(width=640, height=480, fps=30)
        print(f'✓ Camera detected: {camera.camera_type}')
        camera.release()
    except Exception as e:
        print(f'✗ Camera detection failed: {e}')
        
except Exception as e:
    print(f'✗ Import failed: {e}')
"; then
    print_status "✓ Camera detection test completed"
else
    print_error "✗ Camera detection test failed"
fi

# Step 8: Create a simple camera test script
print_status "Step 8: Creating camera test script..."
cat > "$APP_DIR/test_camera_simple.py" << 'EOL'
#!/usr/bin/env python3
"""
Simple camera test script for EZREC Backend
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

def test_camera():
    print("Testing camera detection...")
    
    try:
        from camera_interface import CameraInterface
        print("✓ CameraInterface imported successfully")
        
        # Try to initialize camera
        camera = CameraInterface(width=640, height=480, fps=30)
        print(f"✓ Camera initialized: {camera.camera_type}")
        
        # Try to capture a frame
        frame = camera.capture_frame()
        if frame is not None:
            print("✓ Frame captured successfully")
            print(f"  Frame shape: {frame.shape}")
        else:
            print("✗ Failed to capture frame")
        
        camera.release()
        print("✓ Camera test completed successfully")
        return True
        
    except Exception as e:
        print(f"✗ Camera test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    test_camera()
EOL

chmod +x "$APP_DIR/test_camera_simple.py"
chown "$SERVICE_USER:$SERVICE_USER" "$APP_DIR/test_camera_simple.py"

# Step 9: Test the camera
print_status "Step 9: Running camera test..."
if sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" "$APP_DIR/test_camera_simple.py"; then
    print_status "✓ Camera test passed!"
else
    print_error "✗ Camera test failed"
    print_warning "You may need to:"
    echo "  1. Connect a camera (USB or Pi Camera)"
    echo "  2. Enable camera interface: sudo raspi-config"
    echo "  3. Reboot: sudo reboot"
fi

# Step 10: Start the service
print_status "Step 10: Starting service..."
systemctl start ezrec.service

# Step 11: Verify it's working
print_status "Step 11: Verifying service status..."
sleep 5

if systemctl is-active --quiet ezrec.service; then
    print_status "✓ Service is running successfully!"
else
    print_error "✗ Service failed to start. Checking logs..."
    journalctl -u ezrec.service -n 10
fi

print_status "Camera fix completed!"

print_info "Next steps:"
echo "1. Check service status: sudo $APP_DIR/manage.sh status"
echo "2. View logs: sudo $APP_DIR/manage.sh logs"
echo "3. Test camera: sudo -u $SERVICE_USER $APP_DIR/venv/bin/python $APP_DIR/test_camera_simple.py"
echo "4. Health check: sudo $APP_DIR/manage.sh health"

print_warning "If camera still doesn't work:"
echo "1. Make sure a camera is connected"
echo "2. Run: sudo raspi-config"
echo "3. Navigate to: Interface Options > Camera > Enable"
echo "4. Reboot: sudo reboot" 