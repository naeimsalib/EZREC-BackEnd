#!/bin/bash
# Camera Diagnostics and Fix Script

set -e # Exit on most errors

# --- Configuration ---
SERVICE_FILE="/etc/systemd/system/ezrec.service"
APP_DIR="/home/michomanoly14892/code/SmartCam-Soccer/backend"

# --- Colors for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}[+] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
print_error() { echo -e "${RED}[-] $1${NC}"; }

# --- Check for Root ---
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run with sudo."
    exit 1
fi

# --- Main Script ---
print_status "Starting camera diagnostics and fix..."
echo "----------------------------------------"

# 1. Check for connected video devices
print_status "1. Checking for detected camera hardware..."
if ls /dev/video* 1> /dev/null 2>&1; then
    print_status "Raw video devices found:"
    ls /dev/video*
    v4l2-ctl --list-devices
else
    print_warning "No /dev/video* devices found. Is the camera physically connected and enabled in raspi-config?"
fi
echo "----------------------------------------"

# 2. Force install system-level dependencies
print_status "2. Installing system-level camera drivers (libcamera, python3-picamera2)..."
apt-get update
# This is the crucial step: install the system package for picamera2
apt-get install -y libcamera-dev libcamera-apps python3-picamera2
print_status "System drivers installed."
echo "----------------------------------------"

# 3. Test libcamera directly
print_status "3. Testing camera with 'libcamera-hello'..."
if command -v libcamera-hello &> /dev/null; then
    print_status "Listing cameras according to libcamera:"
    libcamera-hello --list-cameras
    print_status "Running a 2-second test capture... (If this fails, the OS can't see the camera)"
    libcamera-hello -t 2000 || print_warning "libcamera-hello test failed. Check hardware connection and OS configuration."
else
    print_warning "'libcamera-hello' not found. The system driver installation may have failed."
fi
echo "----------------------------------------"

# 4. Modify systemd service to add a delay
print_status "4. Adding a 10-second delay to the service to wait for hardware..."
if ! grep -q "ExecStartPre=/bin/sleep 10" "$SERVICE_FILE"; then
    sed -i '/\[Service\]/a ExecStartPre=/bin/sleep 10' "$SERVICE_FILE"
    print_status "Delay added to $SERVICE_FILE."
    systemctl daemon-reload
else
    print_status "Delay already exists in service file."
fi
echo "----------------------------------------"

# 5. Force reinstall Python dependencies in the virtual environment
print_status "5. Forcibly reinstalling Python packages in your virtual environment..."
# Run the following commands as the service user to avoid permission issues
sudo -u michomanoly14892 bash <<EOF
set -e
source "$APP_DIR/venv/bin/activate"
pip uninstall -y picamera2 opencv-python
pip install --no-cache-dir -r "$APP_DIR/requirements.txt"
deactivate
EOF
print_status "Python packages re-installed."
echo "----------------------------------------"

print_status "All steps completed!"
print_warning "A REBOOT is required for all changes to take effect."
echo "Run this command now: sudo reboot"
echo ""
echo "After rebooting, wait a minute, then check the status with: sudo ./manage.sh status"
echo "" 