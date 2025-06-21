#!/bin/bash
# Fix Dependencies Script

set -e

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

print_status "Upgrading pip..."
pip install --upgrade pip

print_status "Installing all dependencies from requirements.txt..."
pip install -r requirements.txt

print_status "Dependencies re-installed successfully inside the virtual environment."

# Deactivate the virtual environment
deactivate

echo ""
print_status "Run 'sudo ./manage.sh restart' to apply the changes."
echo "" 