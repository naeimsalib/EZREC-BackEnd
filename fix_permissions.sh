#!/bin/bash
# Fix User Permissions for Camera Access

set -ex # Exit on error and print commands

# --- Configuration ---
TARGET_USER="michomanoly14892"

# --- Colors for Output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}[+] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }

# --- Check for Root ---
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with sudo."
    exit 1
fi

# --- Main Script ---
print_status "Adding user '$TARGET_USER' to required hardware access groups..."

# Add user to the 'video' group for camera hardware access
usermod -a -G video "$TARGET_USER"
print_status "Added user to 'video' group."

# Add user to the 'render' group, which is often needed for modern camera/graphics stacks
usermod -a -G render "$TARGET_USER"
print_status "Added user to 'render' group."

echo "----------------------------------------"
print_status "Permissions updated successfully."
print_warning "A FULL REBOOT IS REQUIRED for these group changes to take effect."
echo "Run this command now: sudo reboot"
echo ""
echo "After rebooting, the camera should be accessible by your user."
echo "You can test with the manual command again, or just start the service."
echo "" 