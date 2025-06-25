#!/bin/bash

# EZREC Quick Pi Fix - Optimized and Reliable
# Fixes critical issues without hanging

set -e

echo "🚀 EZREC Quick Pi Fix - Optimized Version"
echo "========================================="
echo "⏰ $(date)"

DEPLOY_DIR="/opt/ezrec-backend"
SERVICE_NAME="ezrec-backend"
USER_NAME="ezrec"

# Step 1: Stop service and kill camera processes
echo "🛑 Stopping camera processes..."
sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
sudo pkill -f "python.*camera" 2>/dev/null || true
sudo pkill -f "picamera2" 2>/dev/null || true

# Step 2: Quick Picamera2 fix - use system packages directly
echo "📷 Configuring Picamera2..."

# Create venv with system site packages access
echo "🔗 Enabling system site packages in venv..."
VENV_PYVENV_CFG="$DEPLOY_DIR/venv/pyvenv.cfg"
if [ -f "$VENV_PYVENV_CFG" ]; then
    sudo sed -i 's/include-system-site-packages = false/include-system-site-packages = true/' "$VENV_PYVENV_CFG"
    echo "✅ System site packages enabled"
fi

# Test Picamera2 import quickly
if sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python3 -c "import picamera2; print('✅ Picamera2 working')" 2>/dev/null; then
    echo "✅ Picamera2 installation verified"
else
    echo "⚠️ Picamera2 issue detected, trying alternative approach..."
    
    # Install just the essentials
    sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/pip install --no-deps picamera2 2>/dev/null || true
fi

# Step 3: Fix Config and Utils imports
echo "🔧 Fixing import issues..."
cd $DEPLOY_DIR

# Test imports
IMPORT_TEST=$(sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python3 -c "
import sys
sys.path.insert(0, '$DEPLOY_DIR/src')
try:
    from src.config import Config
    from src.utils import SupabaseManager
    print('✅ All imports working')
except Exception as e:
    print(f'❌ Import error: {e}')
" 2>&1)

echo "$IMPORT_TEST"

# Step 4: Camera permissions (quick version)
echo "🔐 Setting camera permissions..."
sudo usermod -a -G video $USER_NAME 2>/dev/null || true
sudo usermod -a -G render $USER_NAME 2>/dev/null || true

# Step 5: Update service file (essential fixes only)
echo "⚙️ Updating service configuration..."
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << EOF
[Unit]
Description=EZREC Backend Service - Complete Booking Management System
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

# Environment
Environment=PYTHONPATH=$DEPLOY_DIR/src:$DEPLOY_DIR
Environment=HOME=$DEPLOY_DIR

# Logging
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

# Step 6: Clean old booking from database
echo "🧹 Cleaning old booking..."
if [ -f "$DEPLOY_DIR/.env" ]; then
    sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python3 -c "
import os, sys
os.chdir('$DEPLOY_DIR')
sys.path.insert(0, '$DEPLOY_DIR/src')
try:
    from dotenv import load_dotenv
    load_dotenv()
    from supabase import create_client
    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_ANON_KEY')
    if url and key:
        client = create_client(url, key)
        client.table('bookings').delete().eq('id', 'e57025dd-0956-40d3-81ea-ec5771eabcfa').execute()
        print('✅ Old booking removed')
except: pass
" 2>/dev/null || true
fi

# Step 7: Test and start
echo "🧪 Testing and starting service..."

# Quick test
TEST_RESULT=$(sudo -u $USER_NAME $DEPLOY_DIR/venv/bin/python3 -c "
import sys, os
sys.path.insert(0, '$DEPLOY_DIR/src')
os.chdir('$DEPLOY_DIR')
try:
    from src.config import Config
    print('✅ Config OK')
    from src.utils import setup_logging
    print('✅ Utils OK')
    if os.path.exists('/dev/video0'):
        print('✅ Camera device found')
    else:
        print('⚠️ No camera device')
except Exception as e:
    print(f'❌ Error: {e}')
" 2>&1)

echo "$TEST_RESULT"

# Start service
echo "🚀 Starting EZREC service..."
sudo systemctl start $SERVICE_NAME

sleep 2

if sudo systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ Service started successfully!"
    echo
    echo "📋 Service status:"
    sudo systemctl status $SERVICE_NAME --no-pager --lines=5
else
    echo "❌ Service failed to start"
    echo "📋 Error logs:"
    sudo journalctl -u $SERVICE_NAME --lines=10 --no-pager
fi

echo
echo "🏁 Quick Fix Complete!"
echo "====================="
echo "🔧 Next: Test with booking creation"
echo "   cd $DEPLOY_DIR"
echo "   sudo -u $USER_NAME ./venv/bin/python3 create_test_booking_with_user.py" 