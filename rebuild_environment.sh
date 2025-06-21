#!/bin/bash
# Rebuild Python Environment Script

set -ex # Exit on error and print commands

# --- Configuration ---
APP_DIR="/home/michomanoly14892/code/SmartCam-Soccer/backend"
TARGET_USER="michomanoly14892"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[+] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }

# --- Check for Root ---
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo."
    exit 1
fi

# --- Main Script ---
print_status "Starting a full environment rebuild..."
echo "----------------------------------------"

# 1. Update the system's dynamic library cache
print_status "1. Refreshing system library cache with ldconfig..."
ldconfig
print_status "Cache updated."
echo "----------------------------------------"

# 2. Rebuild the virtual environment as the target user
print_status "2. Rebuilding Python virtual environment..."
sudo -u "$TARGET_USER" bash <<EOF
set -ex
cd "$APP_DIR"
# Remove the old environment
rm -rf venv
# Create a new one with access to system packages (like python3-picamera2)
python3 -m venv venv --system-site-packages
# Activate it
source venv/bin/activate
# Reinstall dependencies
pip install --no-cache-dir -r requirements.txt
deactivate
EOF
print_status "Virtual environment has been rebuilt."
echo "----------------------------------------"

print_status "All steps completed!"
print_warning "A FINAL REBOOT IS REQUIRED for all changes to take effect."
echo "Run this command now: sudo reboot"
echo ""
echo "After rebooting, the service should start correctly. Check with: sudo ./manage.sh status"
echo "" 