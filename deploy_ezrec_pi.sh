#!/bin/bash

# EZREC Pi Complete Deployment - Single Script Solution
# Handles: Git pull, environment setup, system fixes, service deployment
# Everything you need in one script

set -e

echo "🎬 EZREC Pi Complete Deployment"
echo "==============================="
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

# Step 2: Copy code to deployment directory
echo
echo "📋 STEP 2: Setting up deployment directory"
echo "=========================================="
echo "📁 Creating deployment directory..."
sudo mkdir -p $DEPLOY_DIR
sudo chown -R $USER_NAME:$USER_NAME $DEPLOY_DIR 2>/dev/null || sudo useradd -m -s /bin/bash $USER_NAME

echo "📄 Copying source code..."
sudo cp -r $SOURCE_DIR/src $DEPLOY_DIR/
sudo cp -r $SOURCE_DIR/migrations $DEPLOY_DIR/
sudo cp $SOURCE_DIR/requirements.txt $DEPLOY_DIR/
sudo cp $SOURCE_DIR/ezrec-backend.service $DEPLOY_DIR/
sudo chown -R $USER_NAME:$USER_NAME $DEPLOY_DIR

# Step 3: Create Python virtual environment
echo
echo "🐍 STEP 3: Setting up Python environment"
echo "========================================"
if [ ! -d "$DEPLOY_DIR/venv" ]; then
    echo "📦 Creating virtual environment..."
    sudo -u $USER_NAME python3 -m venv $DEPLOY_DIR/venv
fi

echo "🔗 Enabling system site packages..."
VENV_PYVENV_CFG="$DEPLOY_DIR/venv/pyvenv.cfg"
if [ -f "$VENV_PYVENV_CFG" ]; then
    sudo sed -i 's/include-system-site-packages = false/include-system-site-packages = true/' "$VENV_PYVENV_CFG"
fi

echo "📦 Installing Python dependencies..."
sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/pip install --upgrade pip
sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/pip install -r $DEPLOY_DIR/requirements.txt

# Step 4: Create environment configuration
echo
echo "🔧 STEP 4: Creating environment configuration"
echo "============================================"
echo "📝 Creating .env file..."
sudo -u $USER_NAME tee $DEPLOY_DIR/.env > /dev/null << EOF
# EZREC Backend Environment Configuration
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
EOF

echo "✅ Environment configured"

# Step 5: System fixes and permissions
echo
echo "🔐 STEP 5: System fixes and permissions"
echo "======================================"
echo "🛑 Stopping conflicting services..."
sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
sudo pkill -f "python.*camera" 2>/dev/null || true

echo "👥 Setting up user permissions..."
sudo usermod -a -G video $USER_NAME 2>/dev/null || true
sudo usermod -a -G render $USER_NAME 2>/dev/null || true

echo "📁 Creating required directories..."
sudo -u $USER_NAME mkdir -p $DEPLOY_DIR/{temp,uploads,logs,recordings,user_assets}

# Step 6: Install and configure systemd service
echo
echo "⚙️ STEP 6: Configuring systemd service"
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
ExecStartPre=/bin/bash -c 'pkill -f "python.*camera" || true'
ExecStart=$DEPLOY_DIR/venv/bin/python $DEPLOY_DIR/src/orchestrator.py
Restart=always
RestartSec=10
TimeoutStartSec=30

# Environment
Environment=PYTHONPATH=$DEPLOY_DIR/src:$DEPLOY_DIR
Environment=HOME=$DEPLOY_DIR

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-backend

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

# Step 7: Start and verify service
echo
echo "🚀 STEP 7: Starting EZREC service"
echo "================================"
echo "🚀 Starting service..."
sudo systemctl start $SERVICE_NAME

sleep 3

if sudo systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ Service started successfully!"
    echo
    echo "📋 Service status:"
    sudo systemctl status $SERVICE_NAME --no-pager --lines=5
    echo
    echo "📋 Recent logs:"
    sudo journalctl -u $SERVICE_NAME --lines=8 --no-pager
else
    echo "❌ Service failed to start"
    echo "📋 Error logs:"
    sudo journalctl -u $SERVICE_NAME --lines=10 --no-pager
    exit 1
fi

echo
echo "🎉 EZREC Pi Deployment Complete!"
echo "================================"
echo "✅ Code deployed to: $DEPLOY_DIR"
echo "✅ Service: $SERVICE_NAME (active)"
echo "✅ User: $USER_EMAIL"
echo "✅ Camera: Raspberry Pi Camera"
echo
echo "🔧 Management commands:"
echo "   Status:  sudo systemctl status $SERVICE_NAME"
echo "   Logs:    sudo journalctl -u $SERVICE_NAME -f"
echo "   Restart: sudo systemctl restart $SERVICE_NAME"
echo "   Stop:    sudo systemctl stop $SERVICE_NAME"
echo
echo "🎬 System ready for frontend booking management!"
echo "   Your frontend can now create bookings and the Pi will handle recording automatically." 