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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect Raspberry Pi model
detect_pi_model() {
    if [ -f /proc/device-tree/model ]; then
        MODEL=$(tr -d '\0' < /proc/device-tree/model)
        echo "$MODEL"
    else
        echo "Unknown"
    fi
}

# Function to check camera
check_camera() {
    print_status "Checking camera..."
    if command_exists v4l2-ctl; then
        CAMERAS=$(v4l2-ctl --list-devices | grep -c "video")
        if [ "$CAMERAS" -gt 0 ]; then
            print_status "Found $CAMERAS camera(s)"
            return 0
        else
            print_error "No cameras found"
            return 1
        fi
    else
        print_error "v4l2-ctl not found. Installing..."
        apt-get install -y v4l-utils
        check_camera
    fi
}

# Main installation function
install_backend() {
    print_status "Starting installation..."
    print_status "Detected Raspberry Pi model: $(detect_pi_model)"

    # Get the directory where the script is located
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    cd "$SCRIPT_DIR"

    # Update package lists
    print_status "Updating package lists..."
    apt-get update

    # Install system dependencies
    print_status "Installing system dependencies..."
    apt-get install -y \
        python3-pip \
        python3-venv \
        python3-opencv \
        ffmpeg \
        v4l-utils \
        libopencv-dev \
        libatlas-base-dev \
        libhdf5-dev \
        libhdf5-serial-dev \
        libopenjp2-7 \
        libtiff-dev \
        libavcodec-dev \
        libavformat-dev \
        libswscale-dev \
        libv4l-dev \
        libxvidcore-dev \
        libx264-dev \
        libjpeg-dev \
        libpng-dev \
        gfortran \
        libopenblas-dev \
        liblapack-dev \
        libatlas-base-dev \
        libimath-dev \
        libopenexr-dev \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev

    # Create Python virtual environment
    print_status "Creating Python virtual environment..."
    if [ -d "venv" ]; then
        print_status "Removing existing virtual environment..."
        rm -rf venv
    fi
    python3 -m venv venv
    source venv/bin/activate

    # Upgrade pip
    print_status "Upgrading pip..."
    pip install --upgrade pip

    # Install Python dependencies
    print_status "Installing Python dependencies..."
    pip install -r requirements.txt

    # Create necessary directories
    print_status "Creating necessary directories..."
    mkdir -p temp
    mkdir -p recordings
    mkdir -p logs
    mkdir -p user_assets

    # Set permissions
    print_status "Setting permissions..."
    chown -R $SUDO_USER:$SUDO_USER .
    chmod -R 755 .
    chmod -R 777 temp recordings logs user_assets

    # Add user to video group
    print_status "Adding user to video group..."
    usermod -a -G video $SUDO_USER

    # Check camera
    check_camera

    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        print_status "Creating .env file..."
        cat > .env << EOL
USER_EMAIL=
USER_ID=
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
CAMERA_ID=0
CAMERA_WIDTH=1920
CAMERA_HEIGHT=1080
CAMERA_FPS=30
EOL
        print_warning "Please edit the .env file with your configuration"
    fi

    # Make scripts executable
    print_status "Making scripts executable..."
    chmod +x deploy.sh
    chmod +x setup.sh
    chmod +x test.sh
    chmod +x run_services.sh

    print_status "Installation completed successfully!"
    print_warning "Please configure your .env file with your Supabase credentials"
    print_warning "Then run 'sudo ./deploy.sh' to start the services"
}

# Run installation
install_backend 