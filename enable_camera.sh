#!/bin/bash

echo "📷 SmartCam Camera Enablement Script"
echo "===================================="

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

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    print_error "This script is designed for Raspberry Pi only"
    exit 1
fi

print_status "Detected Raspberry Pi - proceeding with camera enablement"

# Step 1: Enable camera in raspi-config
echo ""
echo "Step 1: Enabling camera in raspi-config"
echo "======================================="
print_status "Enabling camera interface..."
sudo raspi-config nonint do_camera 0

if [ $? -eq 0 ]; then
    print_success "Camera interface enabled in raspi-config"
else
    print_error "Failed to enable camera interface"
    exit 1
fi

# Step 2: Check current camera status
echo ""
echo "Step 2: Checking camera status"
echo "=============================="
print_status "Current camera status:"
sudo raspi-config nonint get_camera
if [ $? -eq 0 ]; then
    print_success "Camera is enabled"
else
    print_warning "Camera may not be enabled yet"
fi

# Step 3: Install camera utilities
echo ""
echo "Step 3: Installing camera utilities"
echo "==================================="
print_status "Installing v4l-utils..."
sudo apt update
sudo apt install -y v4l-utils

# Step 4: Add user to video group
echo ""
echo "Step 4: Setting up permissions"
echo "=============================="
print_status "Adding user to video group..."
sudo usermod -a -G video $USER
print_success "User added to video group"

# Step 5: Check camera modules
echo ""
echo "Step 5: Checking camera modules"
echo "==============================="
print_status "Checking loaded camera modules..."
lsmod | grep -i camera || print_warning "No camera modules currently loaded"

# Step 6: Check for camera devices
echo ""
echo "Step 6: Checking camera devices"
echo "==============================="
print_status "Available video devices:"
ls -la /dev/video* 2>/dev/null || print_warning "No video devices found"

# Step 7: Test camera with v4l2-ctl
echo ""
echo "Step 7: Testing camera with v4l2-ctl"
echo "===================================="
if command -v v4l2-ctl >/dev/null 2>&1; then
    print_status "Testing camera with v4l2-ctl..."
    v4l2-ctl --list-devices
else
    print_warning "v4l2-ctl not available"
fi

# Step 8: Create camera test script
echo ""
echo "Step 8: Creating camera test script"
echo "==================================="
cat > ~/test_camera_simple.py << 'EOF'
#!/usr/bin/env python3
import cv2
import time

def test_camera():
    print("Testing camera with OpenCV...")
    
    # Try different camera indices
    for i in range(5):
        print(f"Testing camera index {i}...")
        try:
            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                print(f"  ✅ Camera {i} opened successfully")
                
                # Set properties
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                cap.set(cv2.CAP_PROP_FPS, 30)
                
                # Try to read a frame
                ret, frame = cap.read()
                if ret:
                    print(f"  ✅ Camera {i} can capture frames - Size: {frame.shape}")
                    cap.release()
                    return i
                else:
                    print(f"  ❌ Camera {i} cannot capture frames")
                    cap.release()
            else:
                print(f"  ❌ Camera {i} not accessible")
        except Exception as e:
            print(f"  ❌ Camera {i} test failed: {str(e)}")
    
    return None

if __name__ == "__main__":
    working_camera = test_camera()
    if working_camera is not None:
        print(f"\n✅ Working camera found at index {working_camera}")
        print("You can now run your SmartCam application!")
    else:
        print("\n❌ No working camera found")
        print("Please reboot and try again: sudo reboot")
EOF

chmod +x ~/test_camera_simple.py
print_success "Camera test script created: ~/test_camera_simple.py"

# Step 9: Final instructions
echo ""
echo "Step 9: Final Instructions"
echo "=========================="
print_warning "IMPORTANT: You need to reboot for camera changes to take effect!"
echo ""
echo "Next steps:"
echo "1. Reboot your Raspberry Pi:"
echo "   sudo reboot"
echo ""
echo "2. After reboot, test the camera:"
echo "   cd ~/code/SmartCam-Soccer/backend"
echo "   source venv/bin/activate"
echo "   python ~/test_camera_simple.py"
echo ""
echo "3. If camera works, run the full test:"
echo "   ./test_camera.sh"
echo ""
echo "4. If everything works, start the services:"
echo "   ./install_and_start.sh"
echo ""

print_success "Camera enablement script completed!"
print_warning "Please reboot your Raspberry Pi now!" 