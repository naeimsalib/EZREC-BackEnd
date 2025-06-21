#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print with color
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[-]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Test camera
test_camera() {
    print_status "Testing all /dev/video* devices..."
    python3 -c "import cv2, glob; found = False; devices = sorted(glob.glob('/dev/video*')); print('Found devices:', devices);\
for device in devices:\n    cap = cv2.VideoCapture(device);\n    if cap.isOpened():\n        ret, frame = cap.read();\n        cap.release();\n        if ret:\n            print(f'Camera test passed for {device}'); found = True\n        else:\n            print(f'Opened {device} but failed to read frame.')\n    else:\n        print(f'Failed to open {device}');\
if not found: print('No working camera found'); exit(1)"
}

# Test Supabase connection
test_supabase() {
    print_status "Testing Supabase connection..."
    python3 -c "
from src.utils import supabase, logger
try:
    response = supabase.table('system_status').select('*').limit(1).execute()
    print('Supabase test passed')
except Exception as e:
    print(f'Supabase test failed: {e}')
    exit(1)
"
}

# Test systemd services
test_services() {
    print_status "Testing systemd services..."
    
    for service in scheduler camera orchestrator; do
        if systemctl is-active --quiet $service.service; then
            print_status "$service service is running"
        else
            print_error "$service service is not running"
            exit 1
        fi
    done
}

# Test file permissions
test_permissions() {
    print_status "Testing file permissions..."
    
    directories=(
        "/home/pi/SmartCam-Soccer/backend/temp"
        "/home/pi/SmartCam-Soccer/backend/recordings"
        "/home/pi/SmartCam-Soccer/backend/logs"
    )
    
    for dir in "${directories[@]}"; do
        if [ -w "$dir" ]; then
            print_status "Directory $dir is writable"
        else
            print_error "Directory $dir is not writable"
            exit 1
        fi
    done
}

# Test Python environment
test_python() {
    print_status "Testing Python environment..."
    
    if [ -d "venv" ]; then
        print_status "Virtual environment exists"
    else
        print_error "Virtual environment not found"
        exit 1
    fi
    
    # Test Python packages
    python3 -c "
try:
    import cv2
    import supabase
    import numpy
    print('Python packages test passed')
except ImportError as e:
    print(f'Python packages test failed: {e}')
    exit(1)
"
}

# Run all tests
print_status "Starting system tests..."

test_python
test_camera
test_supabase
test_services
test_permissions

print_status "All tests completed successfully!"
print_warning "Please check the logs for any warnings or errors:"
print_warning "sudo journalctl -u scheduler.service"
print_warning "sudo journalctl -u camera.service"
print_warning "sudo journalctl -u orchestrator.service" 