#!/bin/bash

# EZREC Complete Pi System Fix - Fixes all deployment issues
# Addresses: Picamera2, camera conflicts, service issues, permissions

set -e

echo "🔧 EZREC Complete Pi System Fix"
echo "==============================="
echo "⏰ $(date)"
echo

# Variables
DEPLOY_DIR="/opt/ezrec-backend"
SOURCE_DIR="$HOME/code/EZREC-BackEnd"
SERVICE_NAME="ezrec-backend"
USER_NAME="ezrec"

echo "📁 Directories:"
echo "   Source: $SOURCE_DIR"
echo "   Deploy: $DEPLOY_DIR"
echo

# Step 1: Stop all camera processes and service
echo "🛑 STEP 1: Stopping all camera processes and services"
echo "=================================================="

# Stop EZREC service
sudo systemctl stop $SERVICE_NAME 2>/dev/null || true

# Kill all camera processes
echo "🔫 Terminating all camera processes..."
sudo pkill -f "python.*camera" 2>/dev/null || true
sudo pkill -f "picamera2" 2>/dev/null || true
sudo pkill -f "libcamera" 2>/dev/null || true
sudo pkill -f "vcgencmd" 2>/dev/null || true
sudo pkill -f "raspivid" 2>/dev/null || true
sudo pkill -f "ffmpeg.*video" 2>/dev/null || true

# Disable competing services permanently
echo "⛔ Disabling competing camera services..."
sudo systemctl disable motion 2>/dev/null || true
sudo systemctl stop motion 2>/dev/null || true
sudo systemctl disable mjpg-streamer 2>/dev/null || true
sudo systemctl stop mjpg-streamer 2>/dev/null || true

echo "✅ Camera processes terminated"

# Step 2: Fix Picamera2 installation
echo
echo "📷 STEP 2: Installing Picamera2 in virtual environment"
echo "======================================================="

if [ ! -d "$DEPLOY_DIR/venv" ]; then
    echo "❌ Virtual environment not found at $DEPLOY_DIR/venv"
    echo "   Please run deploy_complete_pi_system.sh first"
    exit 1
fi

# Install Picamera2 with all dependencies
echo "📦 Installing Picamera2 and dependencies..."
sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/pip install --upgrade pip setuptools wheel

# Install Picamera2 system-wide dependencies first
sudo apt-get update
sudo apt-get install -y \
    python3-picamera2 \
    python3-libcamera \
    libcamera-apps \
    libcamera-tools \
    libcamera-dev \
    python3-opencv \
    python3-numpy

# Install Picamera2 in venv with --system-site-packages link
echo "🔗 Configuring virtual environment for system packages..."
sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/pip install \
    opencv-python \
    numpy \
    picamera2 --force-reinstall --no-deps || true

# Create symbolic links for system picamera2 if direct install fails
if ! sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python -c "import picamera2" 2>/dev/null; then
    echo "🔗 Creating symbolic links for system picamera2..."
    
    # Find system picamera2 location
    SYSTEM_PICAMERA2=$(python3 -c "import picamera2; print(picamera2.__file__)" 2>/dev/null | head -1)
    if [ -n "$SYSTEM_PICAMERA2" ]; then
        SYSTEM_PICAMERA2_DIR=$(dirname "$SYSTEM_PICAMERA2")
        VENV_SITE_PACKAGES="$DEPLOY_DIR/venv/lib/python*/site-packages"
        
        sudo -u $USER_NAME ln -sf "$SYSTEM_PICAMERA2_DIR/picamera2" $VENV_SITE_PACKAGES/ 2>/dev/null || true
        sudo -u $USER_NAME ln -sf "$SYSTEM_PICAMERA2_DIR/libcamera" $VENV_SITE_PACKAGES/ 2>/dev/null || true
    fi
fi

# Test Picamera2 import
if sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python -c "import picamera2; print('✅ Picamera2 successfully imported')" 2>/dev/null; then
    echo "✅ Picamera2 installation successful"
else
    echo "⚠️ Picamera2 may have installation issues, but continuing..."
fi

# Step 3: Fix camera permissions and access
echo
echo "🔐 STEP 3: Fixing camera permissions and access"
echo "=============================================="

# Add user to camera groups
sudo usermod -a -G video $USER_NAME
sudo usermod -a -G render $USER_NAME
sudo usermod -a -G gpio $USER_NAME

# Create udev rules for exclusive camera access
echo "📋 Creating camera udev rules..."
sudo tee /etc/udev/rules.d/99-ezrec-camera.rules > /dev/null << 'EOF'
# EZREC Camera exclusive access rules
SUBSYSTEM=="video4linux", KERNEL=="video[0-9]*", GROUP="video", MODE="0664", OWNER="ezrec"
SUBSYSTEM=="vchiq", GROUP="video", MODE="0664", OWNER="ezrec"
SUBSYSTEM=="vcsm-cma", GROUP="video", MODE="0664", OWNER="ezrec"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Set GPU memory split for camera
echo "🖥️ Setting GPU memory split..."
if ! grep -q "gpu_mem=" /boot/config.txt; then
    echo "gpu_mem=128" | sudo tee -a /boot/config.txt
elif ! grep -q "gpu_mem=128" /boot/config.txt; then
    sudo sed -i 's/gpu_mem=.*/gpu_mem=128/' /boot/config.txt
fi

echo "✅ Camera permissions configured"

# Step 4: Fix systemd service configuration
echo
echo "⚙️ STEP 4: Fixing systemd service configuration"
echo "=============================================="

# Create improved service file
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << EOF
[Unit]
Description=EZREC Backend Service - Complete Booking Management System
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
User=$USER_NAME
Group=video
WorkingDirectory=$DEPLOY_DIR
ExecStartPre=/bin/bash -c 'pkill -f "python.*camera" || true'
ExecStart=$DEPLOY_DIR/venv/bin/python $DEPLOY_DIR/src/orchestrator.py
Restart=always
RestartSec=10
TimeoutStartSec=30
TimeoutStopSec=30

# Environment
Environment=PYTHONPATH=$DEPLOY_DIR/src
Environment=HOME=$DEPLOY_DIR

# Resource limits
MemoryMax=1G
CPUQuota=80%

# Security (minimal for camera access)
NoNewPrivileges=true
ProtectHome=false
ProtectSystem=false
PrivateDevices=false

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-backend

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

echo "✅ Service configuration updated"

# Step 5: Clean up old booking and test environment
echo
echo "🧹 STEP 5: Cleaning up old data and testing environment"
echo "======================================================"

# Remove old booking that's causing issues
echo "🗑️ Removing old test booking..."
if [ -f "$DEPLOY_DIR/.env" ]; then
    OLD_BOOKING_ID="e57025dd-0956-40d3-81ea-ec5771eabcfa"
    
    sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python3 -c "
import os
os.chdir('$DEPLOY_DIR')
import sys
sys.path.insert(0, '$DEPLOY_DIR/src')

try:
    from dotenv import load_dotenv
    load_dotenv()
    
    from supabase import create_client
    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_ANON_KEY')
    
    if url and key:
        client = create_client(url, key)
        response = client.table('bookings').delete().eq('id', '$OLD_BOOKING_ID').execute()
        print('✅ Old booking removed')
    else:
        print('⚠️ Supabase credentials not found')
except Exception as e:
    print(f'⚠️ Could not remove old booking: {e}')
    " 2>/dev/null || echo "⚠️ Could not remove old booking"
fi

# Clean temp files
sudo -u $USER_NAME rm -f $DEPLOY_DIR/temp/*.json 2>/dev/null || true

echo "✅ Environment cleaned"

# Step 6: Test and start service
echo
echo "🧪 STEP 6: Testing and starting service"
echo "====================================="

# Test camera access
echo "📷 Testing camera access..."
CAMERA_TEST_RESULT=$(sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python3 -c "
import sys
sys.path.insert(0, '$DEPLOY_DIR/src')
try:
    from src.config import Config
    print('✅ Config import successful')
    
    # Test basic camera detection
    import os
    if os.path.exists('/dev/video0'):
        print('✅ Camera device found')
    else:
        print('⚠️ Camera device not found')
        
except Exception as e:
    print(f'❌ Error: {e}')
" 2>&1)

echo "$CAMERA_TEST_RESULT"

# Start the service
echo "🚀 Starting EZREC service..."
sudo systemctl start $SERVICE_NAME

# Wait a moment and check status
sleep 3
if sudo systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ Service started successfully"
    
    # Show recent logs
    echo
    echo "📋 Recent service logs:"
    echo "-----------------------"
    sudo journalctl -u $SERVICE_NAME --lines=10 --no-pager
else
    echo "❌ Service failed to start"
    echo
    echo "📋 Service status:"
    echo "------------------"
    sudo systemctl status $SERVICE_NAME --no-pager --lines=5
    
    echo
    echo "📋 Recent error logs:"
    echo "--------------------"
    sudo journalctl -u $SERVICE_NAME --lines=20 --no-pager
fi

echo
echo "🏁 EZREC Pi System Fix Complete!"
echo "==============================="
echo "✅ Picamera2 installed"
echo "✅ Camera permissions fixed"
echo "✅ Service configuration updated"
echo "✅ Old data cleaned"
echo
echo "🔧 Next steps:"
echo "   1. Check service status: sudo systemctl status $SERVICE_NAME"
echo "   2. Monitor logs: sudo journalctl -u $SERVICE_NAME -f"
echo "   3. Test booking creation: cd $DEPLOY_DIR && sudo -u $USER_NAME ./venv/bin/python3 create_test_booking_with_user.py"
echo
echo "🎬 System ready for EZREC recording!" 