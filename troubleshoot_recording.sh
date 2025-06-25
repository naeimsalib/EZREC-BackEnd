#!/bin/bash

echo "🔍 EZREC Recording Issue Troubleshooter"
echo "======================================="
echo "Time: $(date)"
echo

# 1. Check service status
echo "📊 1. Service Status Check"
echo "-------------------------"
sudo systemctl status ezrec-backend --no-pager -l
echo

# 2. Check recent service logs
echo "📋 2. Recent Service Logs (Last 10 minutes)"
echo "--------------------------------------------"
sudo journalctl -u ezrec-backend --since "10 minutes ago" --no-pager
echo

# 3. Check for current booking file
echo "📁 3. Current Booking File Check"
echo "--------------------------------"
if [ -f "/opt/ezrec-backend/temp/current_booking.json" ]; then
    echo "✅ Current booking file exists:"
    cat /opt/ezrec-backend/temp/current_booking.json | jq '.' 2>/dev/null || cat /opt/ezrec-backend/temp/current_booking.json
else
    echo "❌ No current booking file found"
fi
echo

# 4. Check recordings directory
echo "📹 4. Recordings Directory Check"
echo "--------------------------------"
if [ -d "/opt/ezrec-backend/recordings" ]; then
    echo "📁 Recordings directory contents:"
    ls -la /opt/ezrec-backend/recordings/
    echo
    echo "📏 Recent recordings (last 24 hours):"
    find /opt/ezrec-backend/recordings -name "*.mp4" -newermt "24 hours ago" -exec ls -la {} \;
else
    echo "❌ Recordings directory not found"
fi
echo

# 5. Check temp directory for active recordings
echo "🔄 5. Temp Directory Check"
echo "--------------------------"
if [ -d "/opt/ezrec-backend/temp" ]; then
    echo "📁 Temp directory contents:"
    ls -la /opt/ezrec-backend/temp/
    echo
    echo "🎬 Active recording files:"
    find /opt/ezrec-backend/temp -name "*.mp4" -exec ls -la {} \; 2>/dev/null || echo "No .mp4 files in temp"
else
    echo "❌ Temp directory not found"
fi
echo

# 6. Test booking detection
echo "🔍 6. Current Booking Detection Test"
echo "-----------------------------------"
echo "Testing booking detection for camera_id 'raspberry_pi_camera':"
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 -c "
import sys
sys.path.append('/opt/ezrec-backend/src')
from utils import get_next_booking
booking = get_next_booking()
if booking:
    print(f'✅ Found booking: {booking[\"id\"]} at {booking[\"date\"]} {booking[\"start_time\"]}-{booking[\"end_time\"]}')
    print(f'   Camera ID: {booking.get(\"camera_id\", \"NOT SET\")}')
    print(f'   Status: {booking.get(\"status\", \"NOT SET\")}')
else:
    print('❌ No upcoming bookings found')
"
echo

# 7. Check camera status
echo "📹 7. Camera Status Check"
echo "-------------------------"
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 -c "
import sys
sys.path.append('/opt/ezrec-backend/src')
try:
    from camera_interface import CameraInterface
    camera = CameraInterface()
    if camera.camera_type:
        print(f'✅ Camera available: {camera.camera_type}')
        print(f'   Resolution: {camera.width}x{camera.height}@{camera.fps}fps')
        # Test frame capture
        frame = camera.capture_frame()
        if frame is not None:
            print('✅ Camera can capture frames')
        else:
            print('❌ Camera cannot capture frames')
        camera.release()
    else:
        print('❌ No camera available')
except Exception as e:
    print(f'❌ Camera error: {e}')
"
echo

# 8. Check system time and timezone
echo "⏰ 8. System Time Check"
echo "----------------------"
echo "Current system time: $(date)"
echo "Timezone: $(timedatectl | grep 'Time zone')"
echo "System uptime: $(uptime -p)"
echo

# 9. Check disk space
echo "💾 9. Disk Space Check"
echo "---------------------"
df -h /opt/ezrec-backend
echo

# 10. Check process information
echo "🔧 10. Process Information"
echo "-------------------------"
echo "EZREC processes:"
ps aux | grep ezrec | grep -v grep
echo

# 11. Check environment configuration
echo "⚙️ 11. Environment Configuration Check"
echo "--------------------------------------"
if [ -f "/opt/ezrec-backend/.env" ]; then
    echo "✅ Environment file exists"
    echo "Key configuration (values hidden for security):"
    grep -E "^(SUPABASE_URL|USER_ID|CAMERA_ID|DEBUG|LOG_LEVEL)" /opt/ezrec-backend/.env | sed 's/=.*/=***/'
else
    echo "❌ Environment file not found"
fi
echo

# 12. Check network connectivity
echo "🌐 12. Network Connectivity Check"
echo "---------------------------------"
echo "Testing Supabase connectivity..."
timeout 10 curl -s -o /dev/null -w "%{http_code}" "$(grep SUPABASE_URL /opt/ezrec-backend/.env | cut -d'=' -f2)/rest/v1/" 2>/dev/null || echo "Connection test failed"
echo

echo "🔍 Troubleshooting Complete!"
echo "============================"
echo
echo "📋 Next Steps:"
echo "1. Check the logs above for any ERROR messages"
echo "2. Verify booking exists in Supabase with correct camera_id"
echo "3. Ensure camera is working properly"
echo "4. Check if service is running and not stuck"
echo
echo "🆘 Common Issues:"
echo "- Booking camera_id doesn't match CAMERA_ID in .env"
echo "- Camera hardware issues or permissions"
echo "- Service stopped or crashed"
echo "- Time zone mismatches"
echo "- Network connectivity problems" 