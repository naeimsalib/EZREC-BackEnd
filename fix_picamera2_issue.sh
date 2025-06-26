#!/bin/bash
# 📹 EZREC Picamera2 Camera Access Fix
# =====================================
# Fixes the "list index out of range" camera detection issue

set -e

echo "📹 EZREC Picamera2 Camera Access Fix"
echo "====================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Step 1: Checking camera hardware..."
echo "📹 Available cameras:"
if command -v libcamera-hello >/dev/null 2>&1; then
    libcamera-hello --list-cameras || log_warn "No cameras detected by libcamera"
else
    log_warn "libcamera-hello not found"
fi

log_info "Step 2: Adding service user to camera groups..."
usermod -a -G video michomanoly14892
usermod -a -G dialout michomanoly14892
usermod -a -G i2c michomanoly14892
usermod -a -G spi michomanoly14892
usermod -a -G gpio michomanoly14892

log_info "Step 3: Checking camera device permissions..."
ls -la /dev/video* 2>/dev/null || log_warn "No video devices found"

log_info "Step 4: Fixing GPU memory split (if needed)..."
# Ensure GPU memory is adequate for camera
if grep -q "gpu_mem" /boot/firmware/config.txt; then
    log_info "GPU memory already configured"
else
    echo "gpu_mem=128" >> /boot/firmware/config.txt
    log_warn "Added gpu_mem=128 to config.txt - REBOOT REQUIRED"
fi

log_info "Step 5: Creating camera test script..."
cat > /opt/ezrec-backend/test_camera.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/opt/ezrec-backend')

try:
    from picamera2 import Picamera2
    print("✅ Picamera2 imported successfully")
    
    # Test camera detection
    cameras = Picamera2.global_camera_info()
    print(f"📹 Detected {len(cameras)} camera(s):")
    for i, cam in enumerate(cameras):
        print(f"  Camera {i}: {cam}")
    
    if len(cameras) > 0:
        # Test camera initialization
        picam2 = Picamera2(camera_num=0)
        print("✅ Camera initialization successful")
        picam2.close()
        print("✅ Camera test PASSED")
        sys.exit(0)
    else:
        print("❌ No cameras detected")
        sys.exit(1)
        
except Exception as e:
    print(f"❌ Camera test FAILED: {e}")
    sys.exit(1)
EOF

chmod +x /opt/ezrec-backend/test_camera.py
chown michomanoly14892:michomanoly14892 /opt/ezrec-backend/test_camera.py

log_info "Step 6: Testing camera as service user..."
su - michomanoly14892 -c "cd /opt/ezrec-backend && python3 test_camera.py"

if [ $? -eq 0 ]; then
    log_info "✅ Camera test PASSED - restarting service..."
    systemctl restart ezrec-backend
    sleep 3
    systemctl status ezrec-backend --no-pager -l
else
    log_error "❌ Camera test FAILED - check hardware connection"
    log_warn "Possible solutions:"
    log_warn "  1. Check camera cable connection"
    log_warn "  2. Enable camera in raspi-config"
    log_warn "  3. Reboot after GPU memory changes"
fi

log_info "Fix script complete!" 