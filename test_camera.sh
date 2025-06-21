#!/bin/bash

echo "📷 SmartCam Camera Testing and Fix Script"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Navigate to backend directory
cd ~/code/SmartCam-Soccer/backend

# Activate virtual environment
source venv/bin/activate

echo "Step 1: Checking camera devices"
echo "================================"
ls -la /dev/video*

echo ""
echo "Step 2: Checking camera permissions"
echo "==================================="
groups michomanoly14892 | grep video
sudo usermod -a -G video michomanoly14892

echo ""
echo "Step 3: Checking if camera is in use"
echo "===================================="
sudo lsof /dev/video* 2>/dev/null || echo "No processes using camera devices"

echo ""
echo "Step 4: Testing camera with different methods"
echo "============================================="

# Test with v4l2-ctl
if command -v v4l2-ctl >/dev/null 2>&1; then
    echo "Testing with v4l2-ctl:"
    v4l2-ctl --list-devices
    echo ""
    v4l2-ctl -d /dev/video0 --list-formats-ext
else
    print_warning "v4l2-ctl not installed. Installing..."
    sudo apt update
    sudo apt install -y v4l-utils
fi

echo ""
echo "Step 5: Testing camera with OpenCV"
echo "=================================="

# Test different camera devices with different settings
for device in /dev/video0 /dev/video1 /dev/video2 /dev/video3 /dev/video4; do
    print_status "Testing $device with OpenCV..."
    
    python3 -c "
import cv2
import time
import sys

device_path = '$device'

try:
    print(f'Testing {device_path}...')
    
    # Try different camera backends
    backends = [cv2.CAP_V4L2, cv2.CAP_V4L, cv2.CAP_ANY]
    
    for backend in backends:
        try:
            cap = cv2.VideoCapture(device_path, backend)
            if cap.isOpened():
                print(f'  ✅ {device_path} opened with backend {backend}')
                
                # Set camera properties
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                cap.set(cv2.CAP_PROP_FPS, 30)
                
                # Try to read a frame
                ret, frame = cap.read()
                if ret:
                    print(f'  ✅ {device_path} can capture frames - Size: {frame.shape}')
                    cap.release()
                    sys.exit(0)
                else:
                    print(f'  ❌ {device_path} cannot capture frames')
                    cap.release()
            else:
                print(f'  ❌ {device_path} not accessible with backend {backend}')
        except Exception as e:
            print(f'  ❌ {device_path} failed with backend {backend}: {str(e)}')
    
    print(f'  ❌ {device_path} failed with all backends')
    sys.exit(1)
    
except Exception as e:
    print(f'  ❌ {device_path} test failed: {str(e)}')
    sys.exit(1)
"
    
    if [ $? -eq 0 ]; then
        print_success "Found working camera: $device"
        WORKING_CAMERA="$device"
        break
    fi
done

if [ -z "$WORKING_CAMERA" ]; then
    print_error "No working camera found. Trying alternative approaches..."
    
    echo ""
    echo "Step 6: Alternative camera testing"
    echo "=================================="
    
    # Test with different resolutions
    print_status "Testing with different resolutions..."
    python3 -c "
import cv2
import time

resolutions = [(320, 240), (640, 480), (1280, 720), (1920, 1080)]

for width, height in resolutions:
    try:
        cap = cv2.VideoCapture(0)
        if cap.isOpened():
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
            cap.set(cv2.CAP_PROP_FPS, 30)
            
            ret, frame = cap.read()
            if ret:
                print(f'✅ Camera works at {width}x{height} - Frame size: {frame.shape}')
                cap.release()
                break
            else:
                print(f'❌ Camera cannot capture at {width}x{height}')
                cap.release()
        else:
            print(f'❌ Camera not accessible at {width}x{height}')
    except Exception as e:
        print(f'❌ Camera test failed at {width}x{height}: {str(e)}')
"
    
    # Test with different camera indices
    print_status "Testing with different camera indices..."
    python3 -c "
import cv2
import time

for i in range(10):
    try:
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            ret, frame = cap.read()
            if ret:
                print(f'✅ Camera index {i} works - Frame size: {frame.shape}')
                cap.release()
                break
            else:
                print(f'❌ Camera index {i} cannot capture frames')
                cap.release()
        else:
            print(f'❌ Camera index {i} not accessible')
    except Exception as e:
        print(f'❌ Camera index {i} test failed: {str(e)}')
"
fi

echo ""
echo "Step 7: Camera troubleshooting"
echo "=============================="

# Check if camera module is loaded
print_status "Checking camera modules..."
lsmod | grep -i camera || echo "No camera modules loaded"

# Check if camera is enabled in config
print_status "Checking camera configuration..."
sudo raspi-config nonint get_camera || echo "Camera not enabled in raspi-config"

# Check camera info
print_status "Camera information:"
vcgencmd get_camera || echo "No camera info available"

echo ""
echo "Step 8: Recommendations"
echo "======================"

if [ -z "$WORKING_CAMERA" ]; then
    print_error "No working camera found"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Enable camera: sudo raspi-config"
    echo "2. Reboot: sudo reboot"
    echo "3. Check camera connection"
    echo "4. Try different camera device"
    echo "5. Check if camera is being used by another process"
else
    print_success "Working camera found: $WORKING_CAMERA"
fi

echo ""
print_status "Camera testing completed!" 