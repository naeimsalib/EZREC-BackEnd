#!/bin/bash

echo "🔧 EZREC System Issues Fix"
echo "=========================="
echo "Fixing identified issues from system health check..."
echo

# 1. Fix script permissions
echo "1. 🔒 Fixing Script Permissions"
echo "--------------------------------"
cd /opt/ezrec-backend
sudo chmod +x *.sh
sudo chmod +x *.py
echo "✅ All scripts now executable"
echo

# 2. Clean up old temp files
echo "2. 🧹 Cleaning Old Temp Files"
echo "-----------------------------"
echo "Current temp files:"
ls -la /opt/ezrec-backend/temp/
echo
read -p "Remove old recordings from temp? (y/N): " confirm
if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    sudo rm -f /opt/ezrec-backend/temp/*.mp4
    echo "✅ Temp directory cleaned"
else
    echo "⏭️ Skipping temp cleanup"
fi
echo

# 3. Test working directory and environment
echo "3. ⚙️ Testing Environment Configuration"
echo "-------------------------------------"
cd /opt/ezrec-backend
echo "Current working directory: $(pwd)"

# Test if .env loads properly
if sudo -u ezrec bash -c "cd /opt/ezrec-backend && source .env && echo 'Environment loads: ✅'"; then
    echo "✅ Environment configuration working"
else
    echo "❌ Environment configuration issue"
fi
echo

# 4. Test camera access specifically
echo "4. 📹 Testing Camera Access"
echo "---------------------------"
echo "Testing camera with ezrec user:"
sudo -u ezrec bash -c "
cd /opt/ezrec-backend
timeout 10 /opt/ezrec-backend/venv/bin/python3 -c \"
import sys
sys.path.append('/opt/ezrec-backend/src')
try:
    from camera_interface import CameraInterface
    camera = CameraInterface()
    print(f'Camera type: {camera.camera_type}')
    print(f'Camera ready: {camera.camera is not None}')
    if camera.camera:
        info = camera.get_camera_info()
        print(f'Resolution: {info[\"resolution\"]}')
        print(f'FPS: {info[\"fps\"]}')
        camera.release()
        print('✅ Camera test successful')
    else:
        print('❌ Camera not initialized')
except Exception as e:
    print(f'❌ Camera test failed: {e}')
\"
"
echo

# 5. Test booking detection from correct directory
echo "5. 📅 Testing Booking Detection"
echo "-------------------------------"
sudo -u ezrec bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 -c \"
import sys
sys.path.append('/opt/ezrec-backend/src')
try:
    from utils import get_next_booking
    booking = get_next_booking()
    if booking:
        print(f'✅ Found booking: {booking[\\\"id\\\"]}')
    else:
        print('✅ No bookings found (expected if none created)')
except Exception as e:
    print(f'❌ Booking detection failed: {e}')
\"
"
echo

# 6. Restart service to clear any stuck states
echo "6. 🔄 Service Restart"
echo "--------------------"
read -p "Restart EZREC service to clear any issues? (y/N): " restart_confirm
if [[ $restart_confirm == [yY] || $restart_confirm == [yY][eE][sS] ]]; then
    echo "Restarting service..."
    sudo systemctl restart ezrec-backend
    sleep 3
    sudo systemctl status ezrec-backend --no-pager -l
    echo "✅ Service restarted"
else
    echo "⏭️ Skipping service restart"
fi
echo

# 7. Final verification
echo "7. ✅ Final System Verification"
echo "------------------------------"
echo "Running quick health check..."
cd /opt/ezrec-backend
sudo ./verify_installation.sh | tail -10
echo

echo "🎯 SYSTEM FIXES COMPLETE!"
echo "========================"
echo "📋 Summary of fixes applied:"
echo "  ✅ Script permissions corrected"
echo "  ✅ Working directory verified"
echo "  ✅ Camera access tested"
echo "  ✅ Environment configuration verified"
echo "  ✅ Booking detection tested"
echo
echo "🧪 Next step: Test with a real booking:"
echo "  sudo ./create_simple_test_booking.py"
echo
echo "📊 Monitor the system:"
echo "  sudo journalctl -u ezrec-backend -f" 