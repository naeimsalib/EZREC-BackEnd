#!/bin/bash

# EZREC Installation Verification Script
# Checks all components are working properly

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                EZREC Installation Verification                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "Checking EZREC installation..."
echo

# 1. Check if service user exists
echo "1. Service User Check:"
if id "ezrec" &>/dev/null; then
    print_status 0 "User 'ezrec' exists"
    groups ezrec | grep -q video && print_status 0 "User is in 'video' group" || print_status 1 "User NOT in 'video' group"
else
    print_status 1 "User 'ezrec' does not exist"
fi
echo

# 2. Check directories
echo "2. Directory Structure Check:"
dirs=("/opt/ezrec-backend" "/opt/ezrec-backend/src" "/opt/ezrec-backend/venv" "/opt/ezrec-backend/logs" "/opt/ezrec-backend/temp")
for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
        print_status 0 "Directory exists: $dir"
    else
        print_status 1 "Directory missing: $dir"
    fi
done
echo

# 3. Check Python environment
echo "3. Python Environment Check:"
if [ -f "/opt/ezrec-backend/venv/bin/python" ]; then
    print_status 0 "Virtual environment exists"
    
    # Test Python imports
    cd /opt/ezrec-backend
    if sudo -u ezrec ./venv/bin/python -c "import cv2; print(f'OpenCV: {cv2.__version__}')" 2>/dev/null; then
        print_status 0 "OpenCV import successful"
    else
        print_status 1 "OpenCV import failed"
    fi
    
    if sudo -u ezrec ./venv/bin/python -c "import numpy; print(f'NumPy: {numpy.__version__}')" 2>/dev/null; then
        print_status 0 "NumPy import successful"
    else
        print_status 1 "NumPy import failed"
    fi
    
    if sudo -u ezrec ./venv/bin/python -c "from supabase import create_client; print('Supabase client OK')" 2>/dev/null; then
        print_status 0 "Supabase client import successful"
    else
        print_status 1 "Supabase client import failed"
    fi
else
    print_status 1 "Virtual environment missing"
fi
echo

# 4. Check configuration
echo "4. Configuration Check:"
if [ -f "/opt/ezrec-backend/.env" ]; then
    print_status 0 "Environment file exists"
    
    # Check required variables
    source /opt/ezrec-backend/.env 2>/dev/null
    
    if [ -n "$SUPABASE_URL" ] && [ "$SUPABASE_URL" != "https://your-project-id.supabase.co" ]; then
        print_status 0 "SUPABASE_URL is configured"
    else
        print_warning "SUPABASE_URL needs to be configured"
    fi
    
    if [ -n "$SUPABASE_SERVICE_ROLE_KEY" ] && [ "$SUPABASE_SERVICE_ROLE_KEY" != "your_service_role_key_here" ]; then
        print_status 0 "SUPABASE_SERVICE_ROLE_KEY is configured"
    else
        print_warning "SUPABASE_SERVICE_ROLE_KEY needs to be configured"
    fi
    
    if [ -n "$USER_ID" ] && [ "$USER_ID" != "your_user_id_here" ]; then
        print_status 0 "USER_ID is configured"
    else
        print_warning "USER_ID needs to be configured"
    fi
else
    print_status 1 "Environment file missing"
fi
echo

# 5. Check camera
echo "5. Camera Check:"
if command -v libcamera-hello >/dev/null 2>&1; then
    print_status 0 "libcamera-hello command available"
    
    # Test camera detection
    if timeout 5 libcamera-hello --list-cameras --timeout 100 >/dev/null 2>&1; then
        print_status 0 "Pi Camera detected successfully"
    else
        print_warning "Pi Camera not detected or timeout"
    fi
else
    print_status 1 "libcamera-hello not available"
fi

# Check for camera conflicts
if sudo lsof /dev/video* 2>/dev/null | grep -q .; then
    print_warning "Camera devices are being used by other processes"
    echo "   Run: sudo lsof /dev/video* to see which processes"
else
    print_status 0 "No camera conflicts detected"
fi
echo

# 6. Check systemd service
echo "6. Service Check:"
if systemctl is-enabled ezrec-backend >/dev/null 2>&1; then
    print_status 0 "Service is enabled"
else
    print_status 1 "Service is not enabled"
fi

if systemctl is-active ezrec-backend >/dev/null 2>&1; then
    print_status 0 "Service is running"
else
    print_status 1 "Service is not running"
fi

# Check service file
if [ -f "/etc/systemd/system/ezrec-backend.service" ]; then
    print_status 0 "Service file exists"
else
    print_status 1 "Service file missing"
fi
echo

# 7. Check network connectivity
echo "7. Network Check:"
if ping -c 1 google.com >/dev/null 2>&1; then
    print_status 0 "Internet connectivity OK"
else
    print_status 1 "No internet connectivity"
fi

if [ -n "$SUPABASE_URL" ] && [ "$SUPABASE_URL" != "https://your-project-id.supabase.co" ]; then
    if curl -s --connect-timeout 5 "$SUPABASE_URL" >/dev/null; then
        print_status 0 "Supabase endpoint reachable"
    else
        print_status 1 "Cannot reach Supabase endpoint"
    fi
fi
echo

# 8. Quick logs check
echo "8. Recent Logs Check:"
if journalctl -u ezrec-backend --since "5 minutes ago" --no-pager -q 2>/dev/null | grep -q "ERROR\|CRITICAL"; then
    print_warning "Recent errors found in logs"
    echo "   Run: sudo journalctl -u ezrec-backend --since '5 minutes ago' --no-pager"
else
    print_status 0 "No recent errors in logs"
fi
echo

# Summary
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                         SUMMARY                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"

if systemctl is-active ezrec-backend >/dev/null 2>&1; then
    echo -e "${GREEN}✓ EZREC Backend service is running${NC}"
else
    echo -e "${RED}✗ EZREC Backend service is NOT running${NC}"
fi

if [ -f "/opt/ezrec-backend/.env" ]; then
    source /opt/ezrec-backend/.env 2>/dev/null
    if [ "$SUPABASE_URL" = "https://your-project-id.supabase.co" ] || [ "$USER_ID" = "your_user_id_here" ]; then
        echo -e "${YELLOW}⚠ Configuration needs to be completed${NC}"
        echo "  Edit: sudo nano /opt/ezrec-backend/.env"
    else
        echo -e "${GREEN}✓ Configuration appears complete${NC}"
    fi
else
    echo -e "${RED}✗ Configuration file missing${NC}"
fi

echo
echo "Next steps:"
echo "1. If configuration is incomplete, run: sudo nano /opt/ezrec-backend/.env"
echo "2. After editing config, restart: sudo systemctl restart ezrec-backend"
echo "3. Check status: sudo systemctl status ezrec-backend"
echo "4. View logs: sudo journalctl -u ezrec-backend -f" 