#!/bin/bash

# EZREC Minimal Pi Fix - Ultra-Fast and Reliable
# Skips problematic Picamera2 testing that causes hangs

set -e

echo "⚡ EZREC Minimal Pi Fix - Ultra-Fast Version"
echo "============================================"
echo "⏰ $(date)"

DEPLOY_DIR="/opt/ezrec-backend"
SERVICE_NAME="ezrec-backend"
USER_NAME="ezrec"

# Step 1: Stop everything quickly
echo "🛑 Stopping services..."
sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
sudo pkill -f "python.*camera" 2>/dev/null || true

# Step 2: Enable system packages (the working part)
echo "🔗 Enabling system packages..."
VENV_PYVENV_CFG="$DEPLOY_DIR/venv/pyvenv.cfg"
if [ -f "$VENV_PYVENV_CFG" ]; then
    sudo sed -i 's/include-system-site-packages = false/include-system-site-packages = true/' "$VENV_PYVENV_CFG"
    echo "✅ System packages enabled"
fi

# Step 3: Fix service configuration (minimal)
echo "⚙️ Updating service..."
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << 'EOF'
[Unit]
Description=EZREC Backend Service
After=network-online.target

[Service]
Type=simple
User=ezrec
Group=video
WorkingDirectory=/opt/ezrec-backend
ExecStart=/opt/ezrec-backend/venv/bin/python /opt/ezrec-backend/src/orchestrator.py
Restart=always
RestartSec=10
Environment=PYTHONPATH=/opt/ezrec-backend/src:/opt/ezrec-backend

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

# Step 4: Clean old booking (quick)
echo "🧹 Cleaning old data..."
if [ -f "$DEPLOY_DIR/.env" ]; then
    sudo -u $USER_NAME timeout 10 $DEPLOY_DIR/venv/bin/python3 -c "
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
" 2>/dev/null || echo "⚠️ Booking cleanup skipped"
fi

# Step 5: Start service
echo "🚀 Starting service..."
sudo systemctl start $SERVICE_NAME

sleep 2

# Step 6: Quick status check
if sudo systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ Service started!"
    echo "📋 Status:"
    sudo systemctl status $SERVICE_NAME --no-pager --lines=3
    echo
    echo "📋 Recent logs:"
    sudo journalctl -u $SERVICE_NAME --lines=5 --no-pager
else
    echo "❌ Service failed"
    echo "📋 Error logs:"
    sudo journalctl -u $SERVICE_NAME --lines=8 --no-pager
fi

echo
echo "⚡ Minimal Fix Complete!"
echo "======================="
echo "🔧 Test with: cd $DEPLOY_DIR && sudo -u $USER_NAME ./venv/bin/python3 create_test_booking_with_user.py"
echo "📊 Monitor: sudo journalctl -u $SERVICE_NAME -f" 