#!/bin/bash

echo "📸 EZREC System Snapshot - Complete Installation Details"
echo "========================================================"
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo

# 1. System Information
echo "🖥️  SYSTEM INFORMATION"
echo "======================"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Python Version: $(python3 --version)"
echo "pip3 Version: $(pip3 --version)"
echo

# 2. Hardware Information
echo "🔧 HARDWARE INFORMATION"
echo "======================="
echo "CPU: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | xargs)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Storage: $(df -h / | tail -1 | awk '{print $2 " total, " $3 " used, " $4 " available"}')"
echo "Camera Hardware:"
vcgencmd get_camera 2>/dev/null || echo "vcgencmd not available"
ls -la /dev/video* 2>/dev/null || echo "No video devices found"
echo

# 3. Installed System Packages
echo "📦 SYSTEM PACKAGES (APT)"
echo "========================"
echo "Key packages for EZREC:"
dpkg -l | grep -E "(python3|libcamera|picamera|ffmpeg|opencv|v4l)" | awk '{print $2 " " $3}'
echo
echo "All Python3 related packages:"
dpkg -l | grep python3 | awk '{print $2 " " $3}' | head -20
echo

# 4. Python Virtual Environment
echo "🐍 PYTHON ENVIRONMENT"
echo "====================="
echo "Virtual Environment Path: /opt/ezrec-backend/venv"
if [ -d "/opt/ezrec-backend/venv" ]; then
    echo "Virtual Environment Packages:"
    sudo -u ezrec /opt/ezrec-backend/venv/bin/pip list
else
    echo "❌ Virtual environment not found"
fi
echo

# 5. EZREC Installation Details
echo "🎬 EZREC INSTALLATION"
echo "===================="
echo "Installation Directory: /opt/ezrec-backend"
echo "User: ezrec"
echo "Group: ezrec"
echo "Directory Structure:"
sudo ls -la /opt/ezrec-backend/ 2>/dev/null || echo "❌ EZREC directory not found"
echo
echo "Service File:"
systemctl cat ezrec-backend 2>/dev/null || echo "❌ Service file not found"
echo

# 6. Configuration Files
echo "⚙️  CONFIGURATION FILES"
echo "======================="
echo "Environment file (.env):"
if [ -f "/opt/ezrec-backend/.env" ]; then
    echo "✅ .env file exists"
    # Show structure without revealing secrets
    sudo grep -E "^[A-Z_]+" /opt/ezrec-backend/.env | cut -d'=' -f1 | sort
else
    echo "❌ .env file not found"
fi
echo

# 7. Network and Permissions
echo "🔐 PERMISSIONS & NETWORK"
echo "========================"
echo "EZREC user details:"
id ezrec 2>/dev/null || echo "❌ ezrec user not found"
echo
echo "Video group membership:"
getent group video 2>/dev/null || echo "❌ video group not found"
echo
echo "Network configuration:"
ip addr show | grep -E "inet " | grep -v 127.0.0.1
echo

# 8. Camera Configuration  
echo "📹 CAMERA CONFIGURATION"
echo "======================="
echo "Camera modules status:"
lsmod | grep -E "(bcm2835|i2c)" || echo "No camera modules found"
echo
echo "Libcamera configuration:"
find /boot -name "config.txt" -exec grep -E "(camera|dtoverlay)" {} \; 2>/dev/null || echo "No camera config found"
echo
echo "Camera test:"
sudo -u ezrec timeout 5 libcamera-hello --list-cameras 2>/dev/null || echo "❌ Camera test failed"
echo

# 9. Service Status
echo "🔧 SERVICE STATUS"
echo "=================="
systemctl is-enabled ezrec-backend 2>/dev/null && echo "✅ Service enabled" || echo "❌ Service not enabled"
systemctl is-active ezrec-backend 2>/dev/null && echo "✅ Service active" || echo "❌ Service not active"
echo "Service logs (last 5 lines):"
sudo journalctl -u ezrec-backend --no-pager -n 5 2>/dev/null || echo "❌ No service logs"
echo

# 10. Database Connection
echo "🗄️  DATABASE CONNECTION"
echo "======================="
echo "Testing Supabase connection:"
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 -c "
import sys
sys.path.append('/opt/ezrec-backend/src')
try:
    from utils import supabase
    if supabase:
        print('✅ Supabase connection successful')
    else:
        print('❌ Supabase connection failed')
except Exception as e:
    print(f'❌ Connection error: {e}')
" 2>/dev/null || echo "❌ Connection test failed"
echo

# 11. Generate Installation Command
echo "🚀 ONE-COMMAND INSTALLATION"
echo "==========================="
echo "Save this output and run this command on a new Pi after git clone:"
echo
echo "sudo ./install_ezrec.sh && sudo ./setup_pi_env.sh && sudo ./create_env_file.sh"
echo
echo "Then copy your .env file with the correct Supabase credentials."
echo

# 12. File Checksums for Verification
echo "🔍 FILE VERIFICATION"
echo "==================="
echo "Key file checksums (for verification):"
if [ -d "/opt/ezrec-backend" ]; then
    sudo find /opt/ezrec-backend -name "*.py" -type f -exec md5sum {} \; | head -10
else
    echo "❌ EZREC files not found"
fi
echo

echo "📸 System snapshot complete!"
echo "💾 Save this output to replicate the exact same installation on another Pi" 