#!/bin/bash
# Install System-Level Dependencies for Camera

set -ex # Exit on error and print commands

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

print_status "Updating package list..."
apt-get update

print_status "Installing libcamera system packages..."
# Install the core libcamera development files and applications
# This is required by the picamera2 Python library
apt-get install -y libcamera-dev libcamera-apps

echo ""
print_status "System dependencies installed successfully."
print_status "Please REBOOT your Raspberry Pi now to ensure the new camera drivers are loaded."
echo ""
print_status "After rebooting, check the service with: sudo ./manage.sh status"
echo "" 