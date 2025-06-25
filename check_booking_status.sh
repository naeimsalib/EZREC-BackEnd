#!/bin/bash

echo "📅 EZREC Booking Status Check"
echo "============================="
echo "Current time: $(date)"
echo

# Quick service status
echo "🔄 Service Status:"
systemctl is-active ezrec-backend
echo

# Check if there's a current booking
echo "📋 Current Booking:"
if [ -f "/opt/ezrec-backend/temp/current_booking.json" ]; then
    echo "✅ Active booking found:"
    cat /opt/ezrec-backend/temp/current_booking.json | python3 -m json.tool 2>/dev/null || cat /opt/ezrec-backend/temp/current_booking.json
else
    echo "❌ No current booking file"
fi
echo

# Check for recent recordings
echo "📹 Recent Recordings (last 4 hours):"
if [ -d "/opt/ezrec-backend/recordings" ]; then
    recent_files=$(find /opt/ezrec-backend/recordings -name "*.mp4" -newermt "4 hours ago" 2>/dev/null)
    if [ -n "$recent_files" ]; then
        echo "$recent_files" | while read file; do
            size=$(ls -lh "$file" | awk '{print $5}')
            echo "✅ $(basename "$file") - Size: $size"
        done
    else
        echo "❌ No recordings found in last 4 hours"
    fi
else
    echo "❌ Recordings directory not found"
fi
echo

# Check temp directory for active recordings
echo "🎬 Active/Temp Recordings:"
if [ -d "/opt/ezrec-backend/temp" ]; then
    temp_files=$(find /opt/ezrec-backend/temp -name "*.mp4" 2>/dev/null)
    if [ -n "$temp_files" ]; then
        echo "$temp_files" | while read file; do
            size=$(ls -lh "$file" | awk '{print $5}')
            echo "🔄 $(basename "$file") - Size: $size (Recording in progress?)"
        done
    else
        echo "❌ No temp recordings found"
    fi
else
    echo "❌ Temp directory not found"
fi
echo

# Test booking detection
echo "🔍 Booking Detection Test:"
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 -c "
import sys
sys.path.append('/opt/ezrec-backend/src')
from utils import get_next_booking
from datetime import datetime

booking = get_next_booking()
if booking:
    print(f'📅 Next booking: {booking[\"id\"]}')
    print(f'   Date: {booking[\"date\"]}')
    print(f'   Time: {booking[\"start_time\"]} - {booking[\"end_time\"]}')
    print(f'   Camera: {booking.get(\"camera_id\", \"NOT SET\")}')
    print(f'   Status: {booking.get(\"status\", \"NOT SET\")}')
else:
    print('❌ No upcoming bookings found')
    print('   Check if booking exists in Supabase')
    print('   Verify camera_id matches')
"
echo

# Quick log check for errors
echo "⚠️ Recent Errors (last 5 minutes):"
sudo journalctl -u ezrec-backend --since "5 minutes ago" --grep="ERROR\|CRITICAL\|Failed" --no-pager || echo "No recent errors found"
echo

echo "✅ Quick check complete!"
echo "For detailed troubleshooting, run: ./troubleshoot_recording.sh" 