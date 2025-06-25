#!/bin/bash

echo "🎬 EZREC Live Recording Status Check"
echo "======================================"
echo

# 1. Check service status
echo "📊 Service Status:"
sudo systemctl status ezrec-backend --no-pager -l
echo

# 2. Check current recordings directory
echo "📁 Current Recordings:"
if [ -d "/opt/ezrec-backend/recordings" ]; then
    ls -la /opt/ezrec-backend/recordings/
    echo
    echo "📏 Recording Sizes:"
    du -h /opt/ezrec-backend/recordings/* 2>/dev/null || echo "No recordings found"
else
    echo "❌ Recordings directory not found"
fi
echo

# 3. Check temp/current recordings
echo "🔄 Active/Temp Recordings:"
if [ -d "/opt/ezrec-backend/temp" ]; then
    ls -la /opt/ezrec-backend/temp/*.mp4 2>/dev/null || echo "No active recordings"
else
    echo "❌ Temp directory not found"
fi
echo

# 4. Check current booking
echo "📅 Current Booking:"
if [ -f "/opt/ezrec-backend/temp/current_booking.json" ]; then
    cat /opt/ezrec-backend/temp/current_booking.json | jq '.' 2>/dev/null || cat /opt/ezrec-backend/temp/current_booking.json
else
    echo "❌ No current booking found"
fi
echo

# 5. Check service logs for recording activity
echo "📝 Recent Recording Activity (last 20 lines):"
sudo journalctl -u ezrec-backend --since "10 minutes ago" --no-pager | grep -i "recording\|booking" | tail -20
echo

# 6. Check camera status
echo "📹 Camera Status:"
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 -c "
import sys
sys.path.append('/opt/ezrec-backend/src')
from camera_interface import CameraInterface
try:
    camera = CameraInterface()
    info = camera.get_camera_info()
    print(f'Camera Type: {info[\"camera_type\"]}')
    print(f'Resolution: {info[\"resolution\"]}')
    print(f'FPS: {info[\"fps\"]}')
    print(f'Recording: {info[\"recording\"]}')
    camera.release()
except Exception as e:
    print(f'❌ Camera error: {e}')
"
echo

# 7. Check disk space
echo "💾 Disk Space:"
df -h /opt/ezrec-backend/
echo

# 8. Process check
echo "🔍 EZREC Processes:"
ps aux | grep -E "(ezrec|python.*orchestrator)" | grep -v grep
echo

echo "✅ Recording check complete!" 