#!/bin/bash
# 🔧 EZREC Final Issues Fix
# ========================
# Fixes remaining issues: service failure, missing dependencies, Picamera2 setup

set -e

echo "🔧 EZREC Final Issues Fix"
echo "========================="

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

log_info "Step 1: Installing missing Python dependencies..."
# Add pytz and other missing dependencies to service venv
su - $SERVICE_USER -c "cd $SERVICE_DIR && source venv/bin/activate && pip install pytz opencv-python"

log_info "Step 2: Checking recent service logs for failure cause..."
echo "📋 Recent service logs:"
journalctl -u ezrec-backend --since '5 minutes ago' --no-pager -n 20

log_info "Step 3: Testing Picamera2 specifically (not libcamera)..."
# Create a focused Picamera2 test
cat > $SERVICE_DIR/test_picamera2_only.py << 'EOF'
#!/usr/bin/env python3
"""
Test Picamera2 functionality specifically - not libcamera tools
"""
import sys
import os
sys.path.insert(0, '/opt/ezrec-backend')

try:
    print("🧪 Testing Picamera2 import...")
    from picamera2 import Picamera2
    print("✅ Picamera2 imported successfully")
    
    print("🔍 Checking available Picamera2 cameras...")
    # Use Picamera2's own camera detection (not libcamera)
    try:
        cameras = Picamera2.global_camera_info()
        print(f"📹 Picamera2 detected {len(cameras)} camera(s):")
        for i, cam in enumerate(cameras):
            print(f"  Camera {i}: {cam}")
            
        if len(cameras) == 0:
            print("⚠️  No cameras detected by Picamera2")
            print("💡 Possible solutions:")
            print("   1. Check camera cable connection")
            print("   2. Enable camera interface: sudo raspi-config")
            print("   3. Check camera is not in use by another process")
            print("   4. Verify camera module is compatible")
            sys.exit(1)
        else:
            print("✅ Picamera2 camera detection successful")
            # Try to actually initialize
            print("🔧 Testing camera initialization...")
            picam2 = Picamera2(camera_num=0)
            print("✅ Camera initialization successful")
            picam2.close()
            print("✅ Picamera2 test PASSED")
            sys.exit(0)
            
    except Exception as cam_error:
        print(f"❌ Picamera2 camera error: {cam_error}")
        sys.exit(1)
        
except ImportError as e:
    print(f"❌ Picamera2 import failed: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Picamera2 test failed: {e}")
    sys.exit(1)
EOF

chmod +x $SERVICE_DIR/test_picamera2_only.py
chown $SERVICE_USER:$SERVICE_USER $SERVICE_DIR/test_picamera2_only.py

log_info "Step 4: Running Picamera2-specific test..."
su - $SERVICE_USER -c "cd $SERVICE_DIR && source venv/bin/activate && python3 test_picamera2_only.py"

log_info "Step 5: Fixing deploy script permissions..."
chmod +x /home/$SERVICE_USER/code/EZREC-BackEnd/deploy_ezrec.sh

log_info "Step 6: Installing missing test dependencies..."
cd /home/$SERVICE_USER/code/EZREC-BackEnd
su - $SERVICE_USER -c "cd ~/code/EZREC-BackEnd && source venv/bin/activate && pip install pytz opencv-python"

if [ $? -eq 0 ]; then
    log_info "✅ Dependencies installed - restarting service..."
    systemctl restart ezrec-backend
    sleep 5
    
    log_info "Step 7: Checking updated service status..."
    systemctl status ezrec-backend --no-pager -l
    
    log_info "Step 8: Testing service logs for errors..."
    echo "📋 Latest service logs:"
    journalctl -u ezrec-backend --since '1 minute ago' --no-pager
    
else
    log_error "❌ Dependency installation failed"
fi

log_info "Fix script complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Run: ./deploy_ezrec.sh"
echo "2. Run: python3 test_complete_workflow.py" 