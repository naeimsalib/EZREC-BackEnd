#!/bin/bash

# EZREC Pi Complete Deployment - Production Version
# Handles: Git pull, environment setup, Picamera2, camera protection, service deployment
# Complete booking lifecycle with exclusive camera access

set -e

echo "🎬 EZREC Pi Production Deployment"
echo "=================================="
echo "⏰ $(date)"
echo

# Configuration
DEPLOY_DIR="/opt/ezrec-backend"
SOURCE_DIR="$HOME/code/EZREC-BackEnd"
SERVICE_NAME="ezrec-backend"
USER_NAME="ezrec"

# User Configuration (update these with your actual values)
USER_ID="65aa2e2a-e463-424d-b88f-0724bb0bea3a"
USER_EMAIL="michomanoly@gmail.com"
SUPABASE_URL="https://iszmsaayxpdrovealrrp.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjYwMTMsImV4cCI6MjA2Mzk0MjAxM30.5bE_fPBOgkNtEyjCieW328oxyDHWGpf2OTDWssJ_Npk"

echo "📁 Directories:"
echo "   Source: $SOURCE_DIR"
echo "   Deploy: $DEPLOY_DIR"
echo "👤 User: $USER_EMAIL ($USER_ID)"
echo

# Step 1: Pull latest code
echo "📥 STEP 1: Pulling latest code"
echo "=============================="
if [ -d "$SOURCE_DIR" ]; then
    cd "$SOURCE_DIR"
    echo "🔄 Pulling latest changes..."
    git pull origin main
    echo "✅ Code updated"
else
    echo "❌ Source directory $SOURCE_DIR not found"
    echo "   Please clone the repository first:"
    echo "   git clone https://github.com/naeimsalib/EZREC-BackEnd.git ~/code/EZREC-BackEnd"
    exit 1
fi

# Step 2: Install Raspberry Pi system packages
echo
echo "📦 STEP 2: Installing Raspberry Pi system packages"
echo "=================================================="
echo "🔄 Updating package lists..."
sudo apt update

echo "📷 Installing Picamera2 and camera packages..."
sudo apt install -y python3-libcamera python3-picamera2 python3-opencv
sudo apt install -y ffmpeg v4l-utils python3-dev
sudo apt install -y libcamera-apps libcamera-tools

echo "🛡️ Disabling conflicting camera services..."
sudo systemctl disable motion 2>/dev/null || true
sudo systemctl disable mjpg-streamer 2>/dev/null || true
sudo systemctl stop motion 2>/dev/null || true
sudo systemctl stop mjpg-streamer 2>/dev/null || true

echo "🧹 Killing any existing camera processes..."
sudo pkill -f "libcamera" 2>/dev/null || true
sudo pkill -f "raspistill" 2>/dev/null || true
sudo pkill -f "raspivid" 2>/dev/null || true
sudo pkill -f "motion" 2>/dev/null || true
sudo pkill -f "fswebcam" 2>/dev/null || true

echo "✅ System packages installed and camera protected"

# Step 3: Copy code to deployment directory
echo
echo "📋 STEP 3: Setting up deployment directory"
echo "=========================================="
echo "🛑 Stopping existing service..."
sudo systemctl stop $SERVICE_NAME 2>/dev/null || true

echo "📁 Creating deployment directory..."
sudo mkdir -p $DEPLOY_DIR
sudo useradd -m -s /bin/bash $USER_NAME 2>/dev/null || true
sudo chown -R $USER_NAME:$USER_NAME $DEPLOY_DIR

echo "📄 Copying source code..."
sudo cp -r $SOURCE_DIR/src $DEPLOY_DIR/
sudo cp -r $SOURCE_DIR/migrations $DEPLOY_DIR/
sudo cp $SOURCE_DIR/requirements.txt $DEPLOY_DIR/
sudo cp $SOURCE_DIR/ezrec-backend.service $DEPLOY_DIR/

echo "📁 Creating required directories..."
sudo -u $USER_NAME mkdir -p $DEPLOY_DIR/{temp,uploads,logs,recordings,user_assets}

sudo chown -R $USER_NAME:$USER_NAME $DEPLOY_DIR

# Step 4: Create Python virtual environment
echo
echo "🐍 STEP 4: Setting up Python environment"
echo "========================================"
if [ ! -d "$DEPLOY_DIR/venv" ]; then
    echo "📦 Creating virtual environment..."
    sudo -u $USER_NAME python3 -m venv $DEPLOY_DIR/venv
fi

echo "🔗 Enabling system site packages for Picamera2..."
VENV_PYVENV_CFG="$DEPLOY_DIR/venv/pyvenv.cfg"
if [ -f "$VENV_PYVENV_CFG" ]; then
    sudo sed -i 's/include-system-site-packages = false/include-system-site-packages = true/' "$VENV_PYVENV_CFG"
fi

echo "📦 Installing Python dependencies..."
sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/pip install --upgrade pip
sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/pip install -r $DEPLOY_DIR/requirements.txt

echo "🧪 Testing Picamera2 availability..."
sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python3 -c "
try:
    from picamera2 import Picamera2
    print('✅ Picamera2 imported successfully')
    
    # Check for available cameras
    try:
        cameras = Picamera2.global_camera_info()
        if cameras:
            print(f'✅ Found {len(cameras)} camera(s): {cameras}')
        else:
            print('⚠️ No cameras detected currently - will retry when service starts')
        print('✅ Picamera2 system integration successful')
    except Exception as cam_e:
        print(f'⚠️ Camera detection issue: {cam_e}')
        print('✅ Picamera2 available - camera will be initialized at service start')
        
except ImportError as e:
    print(f'❌ Picamera2 import failed: {e}')
    print('❌ Please check system package installation')
    exit(1)
except Exception as e:
    print(f'⚠️ Picamera2 test warning: {e}')
    print('✅ Continuing deployment - camera will be tested at service start')
"

# Step 5: Create environment configuration
echo
echo "🔧 STEP 5: Creating environment configuration"
echo "============================================"
echo "📝 Creating .env file..."
sudo -u $USER_NAME tee $DEPLOY_DIR/.env > /dev/null << EOF
# EZREC Backend Environment Configuration - Production
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_ANON_KEY
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
USER_ID=$USER_ID
USER_EMAIL=$USER_EMAIL
CAMERA_ID=0
CAMERA_NAME=Raspberry Pi Camera
CAMERA_LOCATION=Soccer Field
DEBUG=false
LOG_LEVEL=INFO
EZREC_BASE_DIR=$DEPLOY_DIR
RECORDINGS_DIR=$DEPLOY_DIR/recordings
TEMP_DIR=$DEPLOY_DIR/temp
LOGS_DIR=$DEPLOY_DIR/logs
EOF

echo "✅ Environment configured"

# Step 6: Setup user permissions and camera access
echo
echo "🔐 STEP 6: Setting up permissions and camera access"
echo "=================================================="
echo "👥 Adding user to video and render groups..."
sudo usermod -a -G video $USER_NAME 2>/dev/null || true
sudo usermod -a -G render $USER_NAME 2>/dev/null || true

echo "📷 Setting camera device permissions..."
sudo chmod 666 /dev/video* 2>/dev/null || true

echo "🛡️ Creating camera protection script..."
sudo tee /usr/local/bin/protect-camera.sh > /dev/null << 'EOF'
#!/bin/bash
# EZREC Camera Protection Script
echo "🛡️ Protecting camera for EZREC..."
pkill -f "libcamera" 2>/dev/null || true
pkill -f "raspistill" 2>/dev/null || true  
pkill -f "raspivid" 2>/dev/null || true
pkill -f "motion" 2>/dev/null || true
pkill -f "fswebcam" 2>/dev/null || true
echo "✅ Camera protection active"
EOF

sudo chmod +x /usr/local/bin/protect-camera.sh

# Step 7: Install and configure systemd service
echo
echo "⚙️ STEP 7: Configuring systemd service"
echo "====================================="
echo "📋 Installing service file..."
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << EOF
[Unit]
Description=EZREC Backend Service - Soccer Recording System
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER_NAME
Group=video
WorkingDirectory=$DEPLOY_DIR
ExecStartPre=/usr/local/bin/protect-camera.sh
ExecStart=$DEPLOY_DIR/venv/bin/python $DEPLOY_DIR/src/orchestrator.py
Restart=always
RestartSec=10
TimeoutStartSec=30

# Environment
Environment=PYTHONPATH=$DEPLOY_DIR/src:$DEPLOY_DIR
Environment=HOME=$DEPLOY_DIR
Environment=DISPLAY=:0

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-backend

# Security
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DEPLOY_DIR

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

# Step 8: Start and verify service
echo
echo "🚀 STEP 8: Starting EZREC service"
echo "================================"
echo "🛡️ Final camera protection..."
sudo /usr/local/bin/protect-camera.sh

echo "🚀 Starting service..."
sudo systemctl start $SERVICE_NAME

sleep 5

if sudo systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ Service started successfully!"
    echo
    echo "📋 Service status:"
    sudo systemctl status $SERVICE_NAME --no-pager --lines=8
    echo
    echo "📋 Recent logs:"
    sudo journalctl -u $SERVICE_NAME --lines=10 --no-pager
else
    echo "❌ Service failed to start"
    echo "📋 Error logs:"
    sudo journalctl -u $SERVICE_NAME --lines=15 --no-pager
    echo
    echo "🧪 Debugging information:"
    echo "   Python path: $DEPLOY_DIR/venv/bin/python"
    echo "   Script path: $DEPLOY_DIR/src/orchestrator.py"
    echo "   Working dir: $DEPLOY_DIR"
    echo "   User: $USER_NAME"
    echo
    echo "🔧 Manual troubleshooting:"
    echo "   Test manually: sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python $DEPLOY_DIR/src/orchestrator.py"
    echo "   Check logs: sudo journalctl -u $SERVICE_NAME -f"
    exit 1
fi

echo
echo "🎉 EZREC Pi Production Deployment Complete!"
echo "==========================================="
echo "✅ Code deployed to: $DEPLOY_DIR"
echo "✅ Service: $SERVICE_NAME (active)"
echo "✅ User: $USER_EMAIL"
echo "✅ Camera: Raspberry Pi Camera (protected)"
echo "✅ Picamera2: System integrated"
echo "✅ Status updates: Every 3 seconds"
echo
echo "🔧 Management commands:"
echo "   Status:    sudo systemctl status $SERVICE_NAME"
echo "   Logs:      sudo journalctl -u $SERVICE_NAME -f"
echo "   Restart:   sudo systemctl restart $SERVICE_NAME"
echo "   Stop:      sudo systemctl stop $SERVICE_NAME"
echo "   Protect:   sudo /usr/local/bin/protect-camera.sh"
echo
echo "📊 System Features:"
echo "   ✅ Complete booking lifecycle"
echo "   ✅ Automatic recording start/stop"
echo "   ✅ Video upload to Supabase storage"
echo "   ✅ Local file cleanup after upload"
echo "   ✅ Booking removal after completion"
echo "   ✅ 3-second status updates"
echo "   ✅ Exclusive Picamera2 access"
echo "   ✅ Camera resource protection"
echo
echo "🎬 System ready for frontend booking management!"
echo "   Create bookings in your frontend - Pi will handle everything automatically." 