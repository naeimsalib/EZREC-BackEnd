#!/bin/bash

echo "🔪 Killing Camera Processes Script"
echo "=================================="

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

echo "Step 1: Checking for processes using camera devices"
echo "==================================================="

# Check what processes are using video devices
print_status "Processes using video devices:"
sudo lsof /dev/video* 2>/dev/null || print_status "No processes currently using video devices"

echo ""
echo "Step 2: Checking for Python processes"
echo "====================================="

# Check for Python processes that might be camera-related
print_status "Python processes running:"
ps aux | grep python | grep -v grep || print_status "No Python processes found"

echo ""
echo "Step 3: Checking for SmartCam processes"
echo "======================================"

# Check for any SmartCam-related processes
print_status "SmartCam-related processes:"
ps aux | grep -i smartcam | grep -v grep || print_status "No SmartCam processes found"
ps aux | grep -i camera | grep -v grep || print_status "No camera-related processes found"

echo ""
echo "Step 4: Killing camera-related processes"
echo "======================================="

# Kill any processes using video devices
print_status "Killing processes using video devices..."
sudo pkill -f "python.*camera" 2>/dev/null || print_status "No camera Python processes to kill"
sudo pkill -f "camera_service" 2>/dev/null || print_status "No camera service processes to kill"
sudo pkill -f "orchestrator" 2>/dev/null || print_status "No orchestrator processes to kill"

# Kill any processes using video devices
for device in /dev/video*; do
    if [ -e "$device" ]; then
        print_status "Checking processes using $device..."
        sudo lsof "$device" 2>/dev/null | awk 'NR>1 {print $2}' | xargs -r sudo kill -9 2>/dev/null || print_status "No processes using $device"
    fi
done

echo ""
echo "Step 5: Stopping systemd services"
echo "================================="

# Stop any running systemd services
print_status "Stopping SmartCam systemd services..."
sudo systemctl stop smartcam-camera.service 2>/dev/null || print_status "smartcam-camera.service not running"
sudo systemctl stop smartcam-orchestrator.service 2>/dev/null || print_status "smartcam-orchestrator.service not running"
sudo systemctl stop smartcam-scheduler.service 2>/dev/null || print_status "smartcam-scheduler.service not running"

# Disable services temporarily
print_status "Disabling SmartCam services temporarily..."
sudo systemctl disable smartcam-camera.service 2>/dev/null || print_status "smartcam-camera.service not enabled"
sudo systemctl disable smartcam-orchestrator.service 2>/dev/null || print_status "smartcam-orchestrator.service not enabled"
sudo systemctl disable smartcam-scheduler.service 2>/dev/null || print_status "smartcam-scheduler.service not enabled"

echo ""
echo "Step 6: Checking for remaining processes"
echo "========================================"

# Check if any processes are still using video devices
print_status "Remaining processes using video devices:"
sudo lsof /dev/video* 2>/dev/null || print_success "No processes using video devices"

echo ""
echo "Step 7: Unloading camera modules (if needed)"
echo "============================================="

# Unload and reload camera modules
print_status "Unloading camera modules..."
sudo modprobe -r bcm2835-v4l2 2>/dev/null || print_status "bcm2835-v4l2 module not loaded"
sudo modprobe -r v4l2_common 2>/dev/null || print_status "v4l2_common module not loaded"

print_status "Reloading camera modules..."
sudo modprobe bcm2835-v4l2 2>/dev/null || print_status "Could not load bcm2835-v4l2"
sudo modprobe v4l2_common 2>/dev/null || print_status "Could not load v4l2_common"

echo ""
echo "Step 8: Final verification"
echo "=========================="

# Check camera devices
print_status "Available video devices:"
ls -la /dev/video* 2>/dev/null || print_warning "No video devices found"

# Check if any processes are using them
print_status "Processes using video devices:"
sudo lsof /dev/video* 2>/dev/null || print_success "No processes using video devices"

echo ""
echo "Step 9: Recommendations"
echo "======================="

print_success "Camera processes cleanup completed!"
echo ""
echo "Next steps:"
echo "1. Test the camera:"
echo "   python quick_camera_test.py"
echo ""
echo "2. If camera works, re-enable services:"
echo "   sudo systemctl enable smartcam-camera.service"
echo "   sudo systemctl enable smartcam-orchestrator.service"
echo "   sudo systemctl enable smartcam-scheduler.service"
echo ""
echo "3. Start services:"
echo "   sudo systemctl start smartcam-camera.service"
echo "   sudo systemctl start smartcam-orchestrator.service"
echo "   sudo systemctl start smartcam-scheduler.service"
echo ""
print_warning "If camera still doesn't work, try rebooting: sudo reboot" 