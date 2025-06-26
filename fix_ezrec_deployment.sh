#!/bin/bash

# 🚀 EZREC Complete System Fix - Final Solution
# This script fixes all permission issues and ensures proper deployment
# Run this to fix the entire system once and for all

set -e  # Exit on any error

echo "🚀 EZREC Complete System Fix"
echo "============================"
echo "📅 Started at: $(date)"
echo ""

# Configuration
REPO_DIR="$HOME/code/EZREC-BackEnd"
DEPLOY_DIR="/opt/ezrec-backend"
SERVICE_NAME="ezrec-backend"
VENV_PATH="$DEPLOY_DIR/venv"
CURRENT_USER=$(whoami)

# Function to print status messages
print_status() {
    echo "📋 $1"
}

print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

print_warning() {
    echo "⚠️ $1"
}

# Stop the failing service
print_status "Stopping failing service..."
sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
print_success "Service stopped"

# Create deployment directory with proper permissions
print_status "Setting up deployment directory..."
sudo mkdir -p $DEPLOY_DIR
sudo mkdir -p $DEPLOY_DIR/src
sudo mkdir -p $DEPLOY_DIR/logs
sudo mkdir -p $DEPLOY_DIR/recordings
sudo mkdir -p $DEPLOY_DIR/temp

# Change ownership to current user (not ezrec user)
sudo chown -R $CURRENT_USER:$CURRENT_USER $DEPLOY_DIR
print_success "Deployment directory created and owned by $CURRENT_USER"

# Copy source files
print_status "Copying source files..."
cp -r $REPO_DIR/src/* $DEPLOY_DIR/src/
cp $REPO_DIR/requirements.txt $DEPLOY_DIR/
cp $REPO_DIR/ezrec-backend.service $DEPLOY_DIR/
print_success "Source files copied"

# Create/fix .env file with proper permissions
print_status "Creating .env file..."
cat > $DEPLOY_DIR/.env << 'EOF'
# EZREC Environment Variables
SUPABASE_URL=https://iszmsaayxpdrovealrrp.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTY4MzAzNzEsImV4cCI6MjAzMjQwNjM3MX0.WvnGhDHQN5lnqfCYJwvWKu-LW4vZr5vBBHiHRhOJYZw
USER_ID=65aa2e2a-e463-424d-b88f-0724bb0bea3a
CAMERA_ID=0
LOGS_DIR=/opt/ezrec-backend/logs
RECORDINGS_DIR=/opt/ezrec-backend/recordings
TEMP_DIR=/opt/ezrec-backend/temp
DEBUG=true
LOG_LEVEL=INFO
EOF

# Set proper permissions on .env file
chmod 644 $DEPLOY_DIR/.env
chown $CURRENT_USER:$CURRENT_USER $DEPLOY_DIR/.env
print_success ".env file created with proper permissions"

# Create virtual environment
print_status "Setting up virtual environment..."
if [[ -d "$VENV_PATH" ]]; then
    rm -rf $VENV_PATH
fi

python3 -m venv $VENV_PATH
source $VENV_PATH/bin/activate
pip install --upgrade pip
pip install -r $DEPLOY_DIR/requirements.txt
print_success "Virtual environment created"

# Update systemd service file to run as current user
print_status "Updating systemd service file..."
cat > /tmp/ezrec-backend.service << EOF
[Unit]
Description=EZREC Backend Service - Soccer Recording System
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$DEPLOY_DIR
Environment=PATH=$VENV_PATH/bin
Environment=PYTHONPATH=$DEPLOY_DIR/src
ExecStartPre=/bin/bash -c 'echo "🛡️ Protecting camera for EZREC..."'
ExecStartPre=/bin/bash -c 'sudo pkill -f libcamera || true'
ExecStartPre=/bin/bash -c 'sudo pkill -f raspistill || true'
ExecStartPre=/bin/bash -c 'sudo pkill -f raspivid || true'
ExecStartPre=/bin/bash -c 'echo "✅ Camera protection active"'
ExecStart=$VENV_PATH/bin/python $DEPLOY_DIR/src/orchestrator.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-backend

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$DEPLOY_DIR

[Install]
WantedBy=multi-user.target
EOF

sudo cp /tmp/ezrec-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
print_success "Service file updated to run as $CURRENT_USER"

# Clean Python cache
print_status "Cleaning Python cache..."
find $DEPLOY_DIR -name "*.pyc" -delete 2>/dev/null || true
find $DEPLOY_DIR -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
print_success "Python cache cleaned"

# Test the configuration
print_status "Testing configuration..."
cd $DEPLOY_DIR
source $VENV_PATH/bin/activate

# Quick test of imports
python3 -c "
import sys
sys.path.insert(0, 'src')
try:
    from config import Config
    from utils import SupabaseManager
    print('✅ Configuration test passed')
except Exception as e:
    print(f'❌ Configuration test failed: {e}')
    sys.exit(1)
"

print_success "Configuration test passed"

# Starting the service
print_status "Starting EZREC service..."
sudo systemctl start $SERVICE_NAME

# Wait and check status
sleep 5

if sudo systemctl is-active --quiet $SERVICE_NAME; then
    print_success "🎉 Service started successfully!"
    
    # Show recent logs
    print_status "Recent service logs:"
    echo "===================="
    sudo journalctl -u $SERVICE_NAME --lines=10 --no-pager
    
    echo ""
    print_success "🎯 EZREC System is now running properly!"
    echo ""
    echo "📋 Monitor logs with: sudo journalctl -u $SERVICE_NAME -f"
    echo "📋 Check status with: sudo systemctl status $SERVICE_NAME"
    
else
    print_error "Service failed to start. Checking logs..."
    sudo journalctl -u $SERVICE_NAME --lines=20 --no-pager
    exit 1
fi

echo ""
echo "🎉 EZREC Complete System Fix - COMPLETED!"
echo "📅 Finished at: $(date)" 