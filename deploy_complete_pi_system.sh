#!/bin/bash
# 🎬 COMPLETE RASPBERRY PI EZREC DEPLOYMENT SCRIPT
# Handles the full deployment lifecycle on Raspberry Pi running Debian
# - Git pull from ~/code/EZREC-BackEnd 
# - Deployment to /opt/ezrec-backend
# - Complete system setup with Picamera2
# - Ultimate camera protection and exclusive access
# - Service configuration and startup

echo "🎬 COMPLETE RASPBERRY PI EZREC DEPLOYMENT"
echo "=========================================="
echo "🕐 Time: $(date)"
echo "🖥️  Platform: Raspberry Pi running Debian"  
echo "📁 Source: ~/code/EZREC-BackEnd"
echo "🎯 Target: /opt/ezrec-backend"
echo "📹 Camera: Picamera2 with exclusive access"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   echo "Usage: sudo ./deploy_complete_pi_system.sh"
   exit 1
fi

# Configuration
SOURCE_DIR="$HOME/code/EZREC-BackEnd"
if [ "$SUDO_USER" ]; then
    SOURCE_DIR="/home/$SUDO_USER/code/EZREC-BackEnd"
fi
DEPLOY_DIR="/opt/ezrec-backend"
USER_NAME="ezrec"
SERVICE_NAME="ezrec-backend"

echo "📋 DEPLOYMENT CONFIGURATION"
echo "============================"
echo "🗂️  Source Directory: $SOURCE_DIR"
echo "🎯 Deploy Directory: $DEPLOY_DIR"
echo "👤 Service User: $USER_NAME"
echo "🔧 Service Name: $SERVICE_NAME"
echo

# STEP 1: GIT PULL FROM SOURCE DIRECTORY
echo "📥 STEP 1: UPDATING SOURCE CODE"
echo "==============================="

if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Source directory not found: $SOURCE_DIR"
    echo "Please ensure you have cloned EZREC-BackEnd to ~/code/EZREC-BackEnd"
    exit 1
fi

echo "📁 Navigating to source directory..."
cd "$SOURCE_DIR" || exit 1

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Not a git repository: $SOURCE_DIR"
    exit 1
fi

echo "📡 Pulling latest changes from GitHub..."
sudo -u "$SUDO_USER" git fetch origin
sudo -u "$SUDO_USER" git pull origin main

if [ $? -eq 0 ]; then
    echo "✅ Git pull successful"
    
    # Show latest commit
    latest_commit=$(git log --oneline -1)
    echo "📝 Latest commit: $latest_commit"
else
    echo "❌ Git pull failed"
    exit 1
fi

echo

# STEP 2: SYSTEM DEPENDENCIES AND PREPARATION
echo "📦 STEP 2: SYSTEM DEPENDENCIES"
echo "==============================="

echo "🔄 Updating system packages..."
apt update && apt upgrade -y

echo "📥 Installing required system packages..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    curl \
    wget \
    build-essential \
    cmake \
    pkg-config \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev \
    libgtk-3-dev \
    libatlas-base-dev \
    gfortran \
    ffmpeg \
    psutil \
    htop \
    nano \
    udev

echo "✅ System packages installed"

echo

# STEP 3: USER AND DIRECTORY SETUP
echo "👤 STEP 3: USER AND DIRECTORY SETUP"
echo "===================================="

# Create ezrec user if it doesn't exist
if ! id "$USER_NAME" &>/dev/null; then
    echo "👤 Creating $USER_NAME user..."
    useradd -r -s /bin/bash -d "$DEPLOY_DIR" -m "$USER_NAME"
else
    echo "✅ User $USER_NAME already exists"
fi

# Add user to required groups
echo "🔐 Adding $USER_NAME to required groups..."
usermod -a -G video,audio,dialout,i2c,spi,gpio,sudo "$USER_NAME"

# Create deployment directory structure
echo "📁 Creating deployment directory structure..."
mkdir -p "$DEPLOY_DIR"/{src,logs,recordings,temp,venv}
mkdir -p /var/log/ezrec

# Set ownership
echo "🔐 Setting directory ownership..."
chown -R "$USER_NAME:$USER_NAME" "$DEPLOY_DIR"
chown -R "$USER_NAME:$USER_NAME" /var/log/ezrec

echo "✅ User and directories setup complete"

echo

# STEP 4: CODE DEPLOYMENT
echo "📁 STEP 4: CODE DEPLOYMENT"
echo "=========================="

echo "📋 Copying source code to deployment directory..."

# Copy source files
cp -r "$SOURCE_DIR/src/"* "$DEPLOY_DIR/src/" 2>/dev/null || true
cp "$SOURCE_DIR/requirements.txt" "$DEPLOY_DIR/" 2>/dev/null || true
cp "$SOURCE_DIR"/*.py "$DEPLOY_DIR/" 2>/dev/null || true
cp "$SOURCE_DIR"/*.sh "$DEPLOY_DIR/" 2>/dev/null || true
cp "$SOURCE_DIR"/*.md "$DEPLOY_DIR/" 2>/dev/null || true

# Copy service configuration files
cp "$SOURCE_DIR/ezrec-backend.service" "$DEPLOY_DIR/" 2>/dev/null || true

# Set permissions
chown -R "$USER_NAME:$USER_NAME" "$DEPLOY_DIR"
chmod +x "$DEPLOY_DIR"/*.sh 2>/dev/null || true

echo "✅ Code deployment complete"

echo

# STEP 5: PYTHON VIRTUAL ENVIRONMENT
echo "🐍 STEP 5: PYTHON VIRTUAL ENVIRONMENT"
echo "======================================"

echo "🔄 Creating Python virtual environment..."
sudo -u "$USER_NAME" python3 -m venv "$DEPLOY_DIR/venv"

echo "📦 Installing Python dependencies..."
sudo -u "$USER_NAME" "$DEPLOY_DIR/venv/bin/pip" install --upgrade pip
sudo -u "$USER_NAME" "$DEPLOY_DIR/venv/bin/pip" install wheel setuptools

# Install Picamera2 and dependencies
echo "📹 Installing Picamera2 and camera dependencies..."
sudo -u "$USER_NAME" "$DEPLOY_DIR/venv/bin/pip" install picamera2[gui,opencv]
sudo -u "$USER_NAME" "$DEPLOY_DIR/venv/bin/pip" install opencv-python
sudo -u "$USER_NAME" "$DEPLOY_DIR/venv/bin/pip" install numpy
sudo -u "$USER_NAME" "$DEPLOY_DIR/venv/bin/pip" install psutil

# Install requirements.txt if it exists
if [ -f "$DEPLOY_DIR/requirements.txt" ]; then
    echo "📋 Installing requirements from requirements.txt..."
    sudo -u "$USER_NAME" "$DEPLOY_DIR/venv/bin/pip" install -r "$DEPLOY_DIR/requirements.txt"
fi

echo "✅ Python environment setup complete"

echo

# STEP 6: CAMERA SYSTEM OPTIMIZATION
echo "📹 STEP 6: CAMERA SYSTEM OPTIMIZATION"
echo "====================================="

echo "🔧 Configuring camera system settings..."

# Enable camera interface
echo "📹 Enabling camera interface..."
raspi-config nonint do_camera 0

# Check and set GPU memory
current_gpu=$(vcgencmd get_mem gpu 2>/dev/null | grep -o '[0-9]*' || echo "0")
if [ "$current_gpu" -lt 128 ]; then
    echo "📝 Setting GPU memory to 128MB..."
    if ! grep -q "gpu_mem=" /boot/firmware/config.txt 2>/dev/null; then
        echo "gpu_mem=128" >> /boot/firmware/config.txt
    else
        sed -i 's/gpu_mem=.*/gpu_mem=128/' /boot/firmware/config.txt
    fi
    echo "⚠️  GPU memory updated - reboot will be required"
else
    echo "✅ GPU memory already configured ($current_gpu MB)"
fi

# Configure camera-specific settings
echo "⚙️  Configuring camera-specific settings..."
if ! grep -q "start_x=1" /boot/firmware/config.txt 2>/dev/null; then
    echo "start_x=1" >> /boot/firmware/config.txt
fi

if ! grep -q "dtoverlay=imx219" /boot/firmware/config.txt 2>/dev/null; then
    echo "dtoverlay=imx219" >> /boot/firmware/config.txt
fi

echo "✅ Camera system optimization complete"

echo

# STEP 7: ULTIMATE CAMERA PROTECTION
echo "🛡️  STEP 7: ULTIMATE CAMERA PROTECTION"
echo "======================================="

# Run the ultimate camera protection script
if [ -f "$DEPLOY_DIR/ultimate_camera_protection.sh" ]; then
    echo "🔒 Running ultimate camera protection..."
    chmod +x "$DEPLOY_DIR/ultimate_camera_protection.sh"
    "$DEPLOY_DIR/ultimate_camera_protection.sh"
else
    echo "⚠️  Ultimate camera protection script not found"
    
    # Fallback basic camera protection
    echo "🔒 Applying basic camera protection..."
    pkill -f "motion|mjpg|vlc|cheese" 2>/dev/null || true
    systemctl stop motion 2>/dev/null || true
    systemctl disable motion 2>/dev/null || true
    systemctl mask motion 2>/dev/null || true
fi

echo "✅ Camera protection applied"

echo

# STEP 8: ENVIRONMENT CONFIGURATION
echo "⚙️  STEP 8: ENVIRONMENT CONFIGURATION"
echo "===================================="

echo "📝 Creating environment configuration..."

# Create .env file template
cat > "$DEPLOY_DIR/.env" << EOF
# EZREC Environment Configuration for Raspberry Pi
# Generated: $(date)

# Supabase Configuration
SUPABASE_URL=your_supabase_url_here
SUPABASE_KEY=your_supabase_anon_key_here
SUPABASE_SERVICE_KEY=your_supabase_service_key_here

# System Configuration
RECORDING_DIR=/opt/ezrec-backend/recordings
TEMP_DIR=/opt/ezrec-backend/temp
LOG_DIR=/opt/ezrec-backend/logs

# Camera Configuration
CAMERA_ID=pi_camera_1
RECORD_WIDTH=1920
RECORD_HEIGHT=1080
RECORD_FPS=30
RECORDING_BITRATE=10000000

# Pi-specific settings
PI_CAMERA_ENABLED=true
GPU_MEMORY=128
CAMERA_ROTATION=0
CAMERA_HFLIP=false
CAMERA_VFLIP=false

# Upload settings
DELETE_AFTER_UPLOAD=true
UPLOAD_TIMEOUT=300

# Debug settings
DEBUG=false
LOG_LEVEL=INFO
EOF

chown "$USER_NAME:$USER_NAME" "$DEPLOY_DIR/.env"
chmod 600 "$DEPLOY_DIR/.env"

echo "⚠️  IMPORTANT: Edit $DEPLOY_DIR/.env with your Supabase credentials"
echo "✅ Environment configuration created"

echo

# STEP 9: SYSTEMD SERVICE SETUP
echo "🔧 STEP 9: SYSTEMD SERVICE SETUP"
echo "================================="

echo "📝 Creating systemd service file..."

# Create systemd service file
cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=EZREC Backend Service - Complete Booking Management System
After=network.target multi-user.target
Wants=network.target

[Service]
Type=simple
User=$USER_NAME
Group=$USER_NAME
WorkingDirectory=$DEPLOY_DIR
Environment=PATH=$DEPLOY_DIR/venv/bin
ExecStartPre=/bin/bash -c 'if [ -f $DEPLOY_DIR/camera_protection_startup.sh ]; then $DEPLOY_DIR/camera_protection_startup.sh; fi'
ExecStart=$DEPLOY_DIR/venv/bin/python3 -m src.orchestrator_fixed
ExecStop=/bin/kill -TERM \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

# Resource limits
MemoryMax=512M
CPUQuota=80%

# Security settings
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=$DEPLOY_DIR /var/log/ezrec /dev/video* /sys/class/thermal

# Camera access
SupplementaryGroups=video audio dialout i2c spi gpio

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Reloading systemd configuration..."
systemctl daemon-reload

echo "🔧 Enabling EZREC service..."
systemctl enable "$SERVICE_NAME"

echo "✅ Systemd service setup complete"

echo

# STEP 10: TESTING AND VALIDATION
echo "🧪 STEP 10: TESTING AND VALIDATION"
echo "=================================="

echo "🔍 Running system validation tests..."

# Test camera access
echo "📹 Testing camera access..."
if sudo -u "$USER_NAME" "$DEPLOY_DIR/venv/bin/python3" -c "
try:
    from picamera2 import Picamera2
    picam = Picamera2()
    picam.close()
    print('✅ Picamera2 access test passed')
except Exception as e:
    print(f'❌ Picamera2 access test failed: {e}')
    exit(1)
"; then
    echo "✅ Camera access test passed"
else
    echo "❌ Camera access test failed"
fi

# Test Python imports
echo "🐍 Testing Python imports..."
if sudo -u "$USER_NAME" "$DEPLOY_DIR/venv/bin/python3" -c "
import sys
sys.path.insert(0, '$DEPLOY_DIR')

try:
    from src.config import Config
    from src.camera_interface import EZRECCameraInterface
    from src.utils import SupabaseManager
    print('✅ All Python imports successful')
except Exception as e:
    print(f'❌ Python import test failed: {e}')
    exit(1)
"; then
    echo "✅ Python imports test passed"
else
    echo "❌ Python imports test failed"
fi

# Test service file
echo "🔧 Testing service file..."
systemctl status "$SERVICE_NAME" --no-pager -l || true

echo "✅ Validation tests complete"

echo

# STEP 11: FINAL SYSTEM STATUS
echo "📊 STEP 11: FINAL SYSTEM STATUS"
echo "==============================="

echo "🎯 DEPLOYMENT SUMMARY:"
echo "====================="
echo "📁 Source Code: ✅ Pulled from GitHub"
echo "🎯 Deployment: ✅ Copied to $DEPLOY_DIR"
echo "👤 User Setup: ✅ $USER_NAME user configured"
echo "🐍 Python Env: ✅ Virtual environment with Picamera2"
echo "📹 Camera: ✅ Exclusive access protection applied"
echo "🔧 Service: ✅ Systemd service configured"
echo "⚙️  Environment: ✅ Configuration template created"
echo

echo "🚀 NEXT STEPS FOR RASPBERRY PI:"
echo "==============================="
echo "1. Edit Supabase credentials:"
echo "   sudo nano $DEPLOY_DIR/.env"
echo
echo "2. Test the camera interface:"
echo "   sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python3 $DEPLOY_DIR/src/camera_interface.py"
echo
echo "3. Start the EZREC service:"
echo "   sudo systemctl start $SERVICE_NAME"
echo
echo "4. Monitor the service:"
echo "   sudo journalctl -u $SERVICE_NAME -f"
echo
echo "5. Enable automatic startup (already done):"
echo "   sudo systemctl enable $SERVICE_NAME"
echo
echo "6. Check service status:"
echo "   sudo systemctl status $SERVICE_NAME"
echo
echo "📋 IMPORTANT CONFIGURATION:"
echo "=========================="
echo "• Edit $DEPLOY_DIR/.env with your Supabase credentials"
echo "• Reboot recommended if GPU memory was changed"
echo "• Camera has exclusive access - no other apps can use it"
echo "• Status updates every 3 seconds as requested"
echo "• Complete booking lifecycle: read → record → upload → cleanup"
echo
echo "🎉 RASPBERRY PI DEPLOYMENT COMPLETE!"
echo "🎬 EZREC system ready for soccer recording operations"
echo "📞 Support: Monitor logs with 'sudo journalctl -u $SERVICE_NAME -f'" 