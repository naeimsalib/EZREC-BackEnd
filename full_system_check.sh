#!/bin/bash

echo "🎬 EZREC Complete System Health Check"
echo "======================================"
echo "Time: $(date)"
echo "Running comprehensive verification..."
echo

# 1. Run installation verification
echo "🔧 1. INSTALLATION VERIFICATION"
echo "================================"
./verify_installation.sh
echo

# 2. Check service and bookings
echo "📅 2. BOOKING STATUS CHECK"
echo "========================="
./check_booking_status.sh
echo

# 3. Check recordings
echo "🎬 3. RECORDINGS CHECK"
echo "====================="
./check_recordings.sh
echo

# 4. Run troubleshooting diagnostics
echo "🔍 4. DETAILED TROUBLESHOOTING"
echo "=============================="
./troubleshoot_recording.sh
echo

# 5. Additional system health checks
echo "💊 5. ADDITIONAL HEALTH CHECKS"
echo "==============================="

# Check if git repo is up to date
echo "📡 Git Repository Status:"
git status --porcelain
if [ $? -eq 0 ]; then
    if [ -z "$(git status --porcelain)" ]; then
        echo "✅ Working tree is clean"
    else
        echo "⚠️ Working tree has changes"
        git status --short
    fi
    
    # Check if we're behind origin
    git fetch --dry-run 2>&1 | grep -q "up to date" && echo "✅ Repository is up to date" || echo "⚠️ Repository may have updates available"
else
    echo "❌ Not in a git repository or git error"
fi
echo

# Check memory usage
echo "🧠 Memory Usage:"
free -h
echo

# Check CPU usage
echo "⚡ CPU Usage (5 second average):"
top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d'%' -f1 | xargs printf "%.1f%% CPU usage\n"
echo

# Check temperature (Pi specific)
echo "🌡️ System Temperature:"
vcgencmd measure_temp 2>/dev/null || echo "Temperature monitoring not available"
echo

# Check camera module specifically
echo "📸 Pi Camera Module Check:"
if command -v libcamera-hello >/dev/null 2>&1; then
    echo "Testing camera detection..."
    timeout 10 libcamera-hello --list-cameras --timeout 1000 2>&1 | head -10
else
    echo "❌ libcamera-hello not available"
fi
echo

# Check for common issues
echo "⚠️ Common Issue Checks:"
echo "----------------------"

# Check for camera permission issues
if [ ! -r /dev/video0 ]; then
    echo "❌ Camera device not readable - check permissions"
else
    echo "✅ Camera device is accessible"
fi

# Check for service conflicts
if pgrep -f "camera" | grep -v "ezrec" >/dev/null; then
    echo "⚠️ Other camera processes detected:"
    pgrep -f "camera" | xargs ps -p
else
    echo "✅ No camera conflicts detected"
fi

# Check environment file permissions
if [ -f "/opt/ezrec-backend/.env" ]; then
    env_perms=$(stat -c "%a" /opt/ezrec-backend/.env)
    if [ "$env_perms" = "600" ] || [ "$env_perms" = "640" ]; then
        echo "✅ Environment file has secure permissions ($env_perms)"
    else
        echo "⚠️ Environment file permissions may be too open ($env_perms)"
    fi
else
    echo "❌ Environment file not found"
fi

echo
echo "🏁 COMPLETE SYSTEM CHECK FINISHED"
echo "================================="
echo "📊 Summary:"
echo "- Installation verification: See section 1"
echo "- Service status: See section 2" 
echo "- Recording capability: See section 3"
echo "- Detailed diagnostics: See section 4"
echo "- System health: See section 5"
echo
echo "📋 Next Steps:"
echo "1. Review any ❌ or ⚠️ items above"
echo "2. If all looks good, test with: ./create_simple_test_booking.py"
echo "3. Monitor logs with: sudo journalctl -u ezrec-backend -f"
echo
echo "🆘 If you see issues:"
echo "- Run individual scripts for more detail"
echo "- Check Supabase dashboard for bookings"
echo "- Restart service: sudo systemctl restart ezrec-backend" 