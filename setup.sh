#!/bin/bash
set -e

USERNAME="michomanoly14892"
APP_DIR="/home/$USERNAME/code/SmartCam-Soccer"

# Print header
echo "SmartCam Soccer Setup Script"
echo "==========================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
# Update system
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install system dependencies
echo "Installing system dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-opencv \
    ffmpeg \
    libatlas-base-dev \
    git \
    v4l-utils

# Create application directory
echo "Setting up application directory at $APP_DIR..."
mkdir -p "$APP_DIR"
chown -R $USERNAME:$USERNAME "$APP_DIR"

# Clone repository if not already present
if [ ! -d "$APP_DIR/.git" ]; then
    echo "Cloning repository..."
    su - $USERNAME -c "git clone https://github.com/yourusername/SmartCam-Soccer.git $APP_DIR"
fi

# Setup Python environment
echo "Setting up Python virtual environment..."
cd "$APP_DIR/backend"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Create necessary directories
echo "Creating necessary directories..."
mkdir -p "$APP_DIR/backend/recordings"
mkdir -p "$APP_DIR/backend/logs"
chown -R $USERNAME:$USERNAME "$APP_DIR"

# Setup systemd services
echo "Setting up systemd services..."
cp systemd/*.service /etc/systemd/system/
systemctl daemon-reload

# Enable and start services
echo "Enabling and starting services..."
systemctl enable smartcam.service
systemctl enable smartcam-manager.service
systemctl enable smartcam-status.service

# Create .env file if it doesn't exist
if [ ! -f "$APP_DIR/backend/.env" ]; then
    echo "Creating .env file..."
    cat > "$APP_DIR/backend/.env" << EOL
# Supabase Configuration
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key

# Camera Configuration
CAMERA_DEVICE=/dev/video0
RECORDING_DIR=$APP_DIR/backend/recordings

# System Configuration
LOG_DIR=$APP_DIR/backend/logs
EOL
    chown $USERNAME:$USERNAME "$APP_DIR/backend/.env"
    echo "Please edit $APP_DIR/backend/.env with your actual configuration"
fi

# Set permissions
echo "Setting permissions..."
chown -R $USERNAME:$USERNAME "$APP_DIR"
chmod -R 755 "$APP_DIR"

echo "Setup complete!"
echo "Please edit $APP_DIR/backend/.env with your actual configuration"
echo "Then start the services with: sudo systemctl start smartcam.service" 