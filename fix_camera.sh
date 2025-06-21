#!/bin/bash

echo "🔧 SmartCam Camera Fix Script"
echo "============================="

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

echo "Step 1: Checking camera status"
echo "=============================="
print_status "Camera interface status:"
sudo raspi-config nonint get_camera

print_status "Available video devices:"
ls -la /dev/video*

echo ""
echo "Step 2: Testing camera with different configurations"
echo "===================================================="

# Create a comprehensive camera test script
cat > ~/test_camera_comprehensive.py << 'EOF'
#!/usr/bin/env python3
import cv2
import time
import os

def test_camera_config(camera_index, width, height, fps, backend):
    """Test camera with specific configuration"""
    try:
        cap = cv2.VideoCapture(camera_index, backend)
        if not cap.isOpened():
            return False, f"Could not open camera {camera_index} with backend {backend}"
        
        # Set properties
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        cap.set(cv2.CAP_PROP_FPS, fps)
        
        # Wait a bit for camera to initialize
        time.sleep(0.5)
        
        # Try to read multiple frames
        for i in range(5):
            ret, frame = cap.read()
            if ret and frame is not None and frame.size > 0:
                cap.release()
                return True, f"Camera {camera_index} works: {width}x{height} @ {fps}fps (backend: {backend})"
            time.sleep(0.1)
        
        cap.release()
        return False, f"Camera {camera_index} opened but no frames captured"
        
    except Exception as e:
        return False, f"Camera {camera_index} error: {str(e)}"

def test_camera_formats(camera_index):
    """Test camera with different formats"""
    print(f"\nTesting camera {camera_index} with different formats...")
    
    # Common formats for Raspberry Pi camera
    formats = [
        ('YUYV', cv2.CAP_V4L2),
        ('MJPG', cv2.CAP_V4L2),
        ('RGB3', cv2.CAP_V4L2),
        ('BGR3', cv2.CAP_V4L2),
    ]
    
    resolutions = [(640, 480), (1280, 720), (1920, 1080)]
    fps_options = [15, 30]
    
    for format_name, backend in formats:
        for width, height in resolutions:
            for fps in fps_options:
                success, message = test_camera_config(camera_index, width, height, fps, backend)
                if success:
                    print(f"  ✅ {message}")
                    return True, message
                else:
                    print(f"  ❌ {message}")
    
    return False, f"Camera {camera_index} failed with all formats"

def test_camera_devices():
    """Test different camera devices"""
    print("Testing camera devices...")
    
    # Test camera indices 0-4
    for i in range(5):
        print(f"\n--- Testing Camera Index {i} ---")
        success, message = test_camera_formats(i)
        if success:
            return i, message
    
    return None, "No working camera found"

def test_camera_with_delay():
    """Test camera with longer initialization delay"""
    print("\nTesting camera with longer initialization delay...")
    
    for i in range(3):
        try:
            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                print(f"  Camera {i} opened, waiting 2 seconds...")
                time.sleep(2)
                
                # Set basic properties
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                cap.set(cv2.CAP_PROP_FPS, 30)
                
                # Try to read frames
                for j in range(10):
                    ret, frame = cap.read()
                    if ret and frame is not None and frame.size > 0:
                        print(f"  ✅ Camera {i} working after delay - Frame {j+1}: {frame.shape}")
                        cap.release()
                        return i, f"Camera {i} works with delay"
                    time.sleep(0.2)
                
                cap.release()
                print(f"  ❌ Camera {i} still not capturing frames")
            else:
                print(f"  ❌ Camera {i} not accessible")
        except Exception as e:
            print(f"  ❌ Camera {i} error: {str(e)}")
    
    return None, "No camera works with delay"

if __name__ == "__main__":
    print("🔧 Comprehensive Camera Test")
    print("============================")
    
    # First, test with normal configuration
    camera_index, message = test_camera_devices()
    
    if camera_index is None:
        # If normal test fails, try with delay
        camera_index, message = test_camera_with_delay()
    
    if camera_index is not None:
        print(f"\n✅ SUCCESS: {message}")
        print(f"Working camera index: {camera_index}")
        
        # Save the working camera index
        with open('/tmp/working_camera_index.txt', 'w') as f:
            f.write(str(camera_index))
        
        print("Camera index saved to /tmp/working_camera_index.txt")
    else:
        print(f"\n❌ FAILED: {message}")
        print("No working camera configuration found")
EOF

chmod +x ~/test_camera_comprehensive.py
print_status "Created comprehensive camera test script"

echo ""
echo "Step 3: Running comprehensive camera test"
echo "========================================="
python ~/test_camera_comprehensive.py

echo ""
echo "Step 4: Checking camera configuration"
echo "====================================="

# Check if we found a working camera
if [ -f /tmp/working_camera_index.txt ]; then
    WORKING_CAMERA=$(cat /tmp/working_camera_index.txt)
    print_success "Found working camera at index: $WORKING_CAMERA"
    
    # Update .env file with working camera
    if [ -f .env ]; then
        print_status "Updating .env file with working camera index..."
        sed -i "s/CAMERA_DEVICE=.*/CAMERA_DEVICE=$WORKING_CAMERA/" .env
        print_success "Updated .env file with CAMERA_DEVICE=$WORKING_CAMERA"
    else
        print_warning ".env file not found"
    fi
else
    print_error "No working camera found"
    
    echo ""
    echo "Step 5: Additional troubleshooting"
    echo "=================================="
    
    # Check camera modules
    print_status "Checking camera modules..."
    lsmod | grep -i camera || print_warning "No camera modules loaded"
    
    # Check camera info
    print_status "Camera information:"
    vcgencmd get_camera 2>/dev/null || print_warning "No camera info available"
    
    # Check if camera is being used
    print_status "Checking if camera is in use..."
    sudo lsof /dev/video* 2>/dev/null || print_status "No processes using camera"
    
    # Try to load camera modules
    print_status "Attempting to load camera modules..."
    sudo modprobe bcm2835-v4l2 2>/dev/null || print_warning "bcm2835-v4l2 module not available"
    sudo modprobe v4l2_common 2>/dev/null || print_warning "v4l2_common module not available"
    
    # Check camera devices again
    print_status "Available video devices after module loading:"
    ls -la /dev/video* 2>/dev/null || print_warning "No video devices found"
fi

echo ""
echo "Step 6: Testing with libcamera"
echo "==============================="

# Check if libcamera is available
if command -v libcamera-still >/dev/null 2>&1; then
    print_status "Testing with libcamera-still..."
    libcamera-still --timeout 1000 --output /tmp/test_image.jpg
    if [ -f /tmp/test_image.jpg ]; then
        print_success "libcamera-still works! Camera is functional"
        ls -la /tmp/test_image.jpg
    else
        print_error "libcamera-still failed"
    fi
else
    print_warning "libcamera-still not available"
    print_status "Installing libcamera-tools..."
    sudo apt update
    sudo apt install -y libcamera-tools
fi

echo ""
echo "Step 7: Final recommendations"
echo "============================="

if [ -f /tmp/working_camera_index.txt ]; then
    WORKING_CAMERA=$(cat /tmp/working_camera_index.txt)
    print_success "Camera fix successful!"
    echo ""
    echo "✅ Working camera found at index: $WORKING_CAMERA"
    echo ""
    echo "Next steps:"
    echo "1. Test the camera with your application:"
    echo "   python src/camera_service.py"
    echo ""
    echo "2. If everything works, start the services:"
    echo "   ./install_and_start.sh"
    echo ""
    echo "3. If you need to use a different camera index, update .env:"
    echo "   CAMERA_DEVICE=$WORKING_CAMERA"
else
    print_error "Camera fix unsuccessful"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check camera connection"
    echo "2. Try different camera cable"
    echo "3. Check camera module in raspi-config"
    echo "4. Try rebooting again"
    echo "5. Check if camera is compatible with your Pi model"
    echo ""
    echo "You can also try:"
    echo "  sudo raspi-config"
    echo "  # Go to Interface Options > Camera > Enable"
fi

print_status "Camera fix script completed!" 