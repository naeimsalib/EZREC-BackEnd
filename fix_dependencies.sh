#!/bin/bash
# Fix Dependencies Script v2

set -ex # Exit on error and print commands

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

# Set the installation directory
APP_DIR="/home/michomanoly14892/code/SmartCam-Soccer/backend"

print_status "Changing to application directory: $APP_DIR"
cd "$APP_DIR"

print_status "Activating virtual environment..."
source "$APP_DIR/venv/bin/activate"

print_status "Forcibly reinstalling camera packages to fix corruption..."
# Uninstall first to ensure a clean slate
pip uninstall -y picamera2 opencv-python
# Reinstall all requirements, ignoring any cached versions
pip install --no-cache-dir -r requirements.txt

print_status "Dependencies re-installed successfully inside the virtual environment."

# Deactivate the virtual environment
deactivate

echo ""
print_status "Run 'sudo ./manage.sh restart' to apply the changes."
echo "" 