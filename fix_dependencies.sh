#!/bin/bash
# 🔧 EZREC Dependencies Final Fix
# ==============================
# Fixes the remaining dependencies: libcamera, psutil, deploy permissions

set -e

echo "🔧 EZREC Dependencies Final Fix"
echo "==============================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

SERVICE_DIR="/opt/ezrec-backend"
SERVICE_USER="michomanoly14892"
DEV_DIR="/home/$SERVICE_USER/code/EZREC-BackEnd"

log_info "Step 1: Installing libcamera Python bindings..."
# Install libcamera for Picamera2
apt-get update
apt-get install -y python3-libcamera python3-kms++

log_info "Step 2: Installing missing Python dependencies in service environment..."
su - $SERVICE_USER -c "cd $SERVICE_DIR && source venv/bin/activate && pip install psutil libcamera"

log_info "Step 3: Installing missing Python dependencies in development environment..."  
su - $SERVICE_USER -c "cd $DEV_DIR && source venv/bin/activate && pip install psutil pytz opencv-python libcamera"

log_info "Step 4: Fixing deploy script permissions..."
chmod +x $DEV_DIR/deploy_ezrec.sh
chown $SERVICE_USER:$SERVICE_USER $DEV_DIR/deploy_ezrec.sh

log_info "Step 5: Testing Picamera2 with proper libcamera..."
cat > $SERVICE_DIR/test_final_camera.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/opt/ezrec-backend')

try:
    print("🧪 Testing libcamera import...")
    import libcamera
    print("✅ libcamera imported successfully")
    
    print("🧪 Testing Picamera2 import...")
    from picamera2 import Picamera2
    print("✅ Picamera2 imported successfully")
    
    print("🔍 Checking Picamera2 cameras...")
    cameras = Picamera2.global_camera_info()
    print(f"📹 Detected {len(cameras)} camera(s)")
    
    if len(cameras) > 0:
        print("✅ Camera hardware detected!")
        # Quick initialization test
        picam2 = Picamera2(camera_num=0)
        print("✅ Camera initialization successful")
        picam2.close()
        print("✅ Camera test PASSED")
    else:
        print("⚠️  No cameras detected - check hardware connection")
        
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Camera test error: {e}")
    sys.exit(1)
EOF

chmod +x $SERVICE_DIR/test_final_camera.py
chown $SERVICE_USER:$SERVICE_USER $SERVICE_DIR/test_final_camera.py

log_info "Step 6: Running final camera test..."
su - $SERVICE_USER -c "cd $SERVICE_DIR && source venv/bin/activate && python3 test_final_camera.py"

if [ $? -eq 0 ]; then
    log_info "✅ Camera test successful - restarting service..."
    systemctl restart ezrec-backend
    sleep 3
    systemctl status ezrec-backend --no-pager -l
else
    log_warn "⚠️  Camera test had issues but continuing..."
fi

log_info "Step 7: Testing development environment..."
su - $SERVICE_USER -c "cd $DEV_DIR && source venv/bin/activate && python3 -c 'import psutil, pytz; print(\"✅ Dev dependencies OK\")'"

log_info "Dependencies fix complete!"
echo ""
echo "🎯 Now run:"
echo "1. ./deploy_ezrec.sh"  
echo "2. python3 test_complete_workflow.py" 