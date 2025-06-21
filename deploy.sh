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

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Create necessary directories
print_status "Creating directories..."
mkdir -p temp
mkdir -p recordings
mkdir -p logs
mkdir -p user_assets

# Set permissions
print_status "Setting permissions..."
chown -R $SUDO_USER:$SUDO_USER .
chmod -R 755 .
chmod -R 777 temp recordings logs user_assets

# Install systemd services
print_status "Installing systemd services..."
cp systemd/*.service /etc/systemd/system/

# Reload systemd
print_status "Reloading systemd..."
systemctl daemon-reload

# Enable and start services
print_status "Enabling and starting services..."
systemctl enable smartcam.service
systemctl enable smartcam-manager.service
systemctl enable smartcam-status.service

systemctl start smartcam.service
systemctl start smartcam-manager.service
systemctl start smartcam-status.service

print_status "Deployment completed successfully!"
print_status "Services are now running. You can check their status with:"
print_status "  sudo systemctl status smartcam.service"
print_status "  sudo systemctl status smartcam-manager.service"
print_status "  sudo systemctl status smartcam-status.service" 