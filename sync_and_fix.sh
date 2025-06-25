#!/bin/bash

echo "🔄 EZREC Repository Sync and Dependency Fix"
echo "============================================"

# 1. Sync the git repo with the service directory
echo "1. 📁 Syncing Git Repository with Service Directory"
echo "--------------------------------------------------"
cd ~/code/EZREC-BackEnd
echo "Pulling latest changes from GitHub..."
git pull origin main

echo "Copying files to service directory..."
sudo cp -r ~/code/EZREC-BackEnd/* /opt/ezrec-backend/
sudo chown -R ezrec:ezrec /opt/ezrec-backend/
sudo chmod +x /opt/ezrec-backend/*.sh
sudo chmod +x /opt/ezrec-backend/*.py

echo "✅ Files synced to /opt/ezrec-backend/"
echo

# 2. Fix Supabase dependency
echo "2. 📦 Fixing Supabase Dependencies"
echo "----------------------------------"
cd /opt/ezrec-backend

echo "Installing missing Python packages..."
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install supabase python-dotenv

echo "Testing Supabase import..."
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 -c "
import sys
sys.path.append('/opt/ezrec-backend/src')
try:
    from supabase import create_client
    print('✅ Supabase client import successful')
except ImportError as e:
    print(f'❌ Still missing: {e}')
"
echo

# 3. Test environment loading
echo "3. ⚙️ Testing Environment Configuration"
echo "-------------------------------------"
cd /opt/ezrec-backend

sudo -u ezrec bash -c "
cd /opt/ezrec-backend
source .env 2>/dev/null
echo 'SUPABASE_URL configured: ' \$([ -n \"\$SUPABASE_URL\" ] && echo '✅' || echo '❌')
echo 'USER_ID configured: ' \$([ -n \"\$USER_ID\" ] && echo '✅' || echo '❌')
echo 'CAMERA_ID configured: ' \$([ -n \"\$CAMERA_ID\" ] && echo '✅' || echo '❌')
"
echo

# 4. Test booking creation
echo "4. 📅 Testing Booking Creation from Service Directory"
echo "---------------------------------------------------"
cd /opt/ezrec-backend

echo "Testing create_simple_test_booking.py..."
sudo -u ezrec bash -c "
cd /opt/ezrec-backend
./venv/bin/python3 ./create_simple_test_booking.py
"
echo

# 5. Restart service with synced files
echo "5. 🔄 Restarting Service with Updated Files"
echo "------------------------------------------"
sudo systemctl restart ezrec-backend
sleep 3

echo "Service status:"
sudo systemctl status ezrec-backend --no-pager -l | head -15
echo

# 6. Monitor for booking detection
echo "6. 📊 Quick Service Health Check"
echo "-------------------------------"
sleep 5
sudo journalctl -u ezrec-backend --since "1 minute ago" --no-pager | tail -10

echo
echo "🎯 SYNC AND FIX COMPLETE!"
echo "========================"
echo "✅ Repository synced with service directory"
echo "✅ Dependencies installed"
echo "✅ Service restarted with latest code"
echo
echo "🌐 Next: Set up frontend testing"
echo "  1. Make sure your frontend is connected to the same Supabase"
echo "  2. Create a booking from the UI"
echo "  3. Watch the logs: sudo journalctl -u ezrec-backend -f" 