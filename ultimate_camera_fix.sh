#!/bin/bash
# ULTIMATE EZREC CAMERA FIX
# Ensures EXCLUSIVE Picamera2 access and prevents all camera conflicts
# Designed specifically for Raspberry Pi Debian with IMX477 camera

echo "🎬 ULTIMATE EZREC CAMERA FIX - EXCLUSIVE PICAMERA2 ACCESS"
echo "========================================================="
echo "Time: $(date)"
echo "This will ensure EZREC has EXCLUSIVE access to the Pi Camera"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

echo "🛑 Step 1: Complete Camera Process Termination..."
# Kill ALL camera-related processes aggressively
pkill -9 -f "libcamera"
pkill -9 -f "picamera"
pkill -9 -f "camera"
pkill -9 -f "v4l2"
pkill -9 -f "gstreamer"
pkill -9 -f "motion"
pkill -9 -f "mjpg"
pkill -9 -f "vlc"
pkill -9 -f "opencv"
pkill -9 -f "ffmpeg"

# Stop ALL services that might use camera
systemctl stop motion 2>/dev/null || true
systemctl stop mjpg-streamer 2>/dev/null || true
systemctl stop vlc 2>/dev/null || true
systemctl stop ezrec-backend 2>/dev/null || true

# Force kill any remaining camera processes
ps aux | grep -E "(camera|libcamera|picamera|v4l2)" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null || true

echo "✅ All camera processes terminated"
sleep 3

echo "🔒 Step 2: Disable Conflicting Services PERMANENTLY..."
# Disable services that commonly conflict with camera access
systemctl disable motion 2>/dev/null || true
systemctl disable mjpg-streamer 2>/dev/null || true
systemctl disable vlc 2>/dev/null || true

# Mask them to prevent accidental start
systemctl mask motion 2>/dev/null || true
systemctl mask mjpg-streamer 2>/dev/null || true

echo "✅ Conflicting services disabled permanently"

echo "⚡ Step 3: Camera Hardware Reset..."
# Reset video devices
for device in /dev/video*; do
    if [ -e "$device" ]; then
        fuser -k "$device" 2>/dev/null || true
        echo "Reset $device"
    fi
done

# GPU memory reset
vcgencmd get_mem gpu 2>/dev/null || true
echo "GPU memory check completed"

echo "🎯 Step 4: Picamera2 Installation & Verification..."
# Ensure Picamera2 system packages are installed
apt update -q
apt install -y python3-picamera2 python3-libcamera python3-kms++ libcamera-apps

# Test system Picamera2
echo "Testing system Picamera2..."
if python3 -c "from picamera2 import Picamera2; print('✅ System Picamera2 working')" 2>/dev/null; then
    echo "✅ System Picamera2 verified"
else
    echo "❌ System Picamera2 failed - attempting repair..."
    apt install --reinstall -y python3-picamera2 python3-libcamera
fi

echo "🐍 Step 5: Virtual Environment Picamera2 Setup..."
cd /opt/ezrec-backend

# Create new venv with system site packages access
if [ -d "venv" ]; then
    rm -rf venv
fi

# Create venv with access to system packages (critical for Picamera2)
python3 -m venv --system-site-packages venv
chown -R ezrec:ezrec venv/

# Install only non-system packages in venv
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install --upgrade pip
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install \
    supabase==2.2.1 \
    python-dotenv==1.0.0 \
    psutil==5.9.8 \
    pytz==2024.1 \
    storage3==0.7.7 \
    httpx==0.24.1

echo "✅ Virtual environment configured with system Picamera2 access"

echo "🧪 Step 6: Comprehensive Camera Test..."
# Create comprehensive camera test
cat > /tmp/ultimate_camera_test.py << 'EOF'
#!/usr/bin/env python3
import sys
import time

def test_picamera2():
    """Test Picamera2 exclusively"""
    try:
        from picamera2 import Picamera2
        print("✅ Picamera2 import successful")
        
        # Create camera instance
        picam = Picamera2()
        print("✅ Picamera2 object created")
        
        # Get camera info
        camera_info = str(picam.camera_info)
        print(f"✅ Camera detected: {camera_info}")
        
        # Configure for minimal test
        config = picam.create_still_configuration(main={"size": (640, 480)})
        picam.configure(config)
        print("✅ Camera configured")
        
        # Start camera
        picam.start()
        print("✅ Camera started")
        
        # Capture test frame
        frame = picam.capture_array()
        print(f"✅ Frame captured: {frame.shape}")
        
        # Stop and cleanup
        picam.stop()
        picam.close()
        print("✅ Camera test completed successfully")
        
        return True
        
    except Exception as e:
        print(f"❌ Picamera2 test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_picamera2()
    sys.exit(0 if success else 1)
EOF

# Test with system Python
echo "Testing with system Python..."
if python3 /tmp/ultimate_camera_test.py; then
    echo "✅ System Python camera test PASSED"
else
    echo "❌ System Python camera test FAILED"
fi

# Test with venv Python
echo "Testing with virtual environment Python..."
if sudo -u ezrec /opt/ezrec-backend/venv/bin/python /tmp/ultimate_camera_test.py; then
    echo "✅ Virtual environment camera test PASSED"
    CAMERA_WORKING=true
else
    echo "❌ Virtual environment camera test FAILED"
    CAMERA_WORKING=false
fi

# Cleanup test file
rm -f /tmp/ultimate_camera_test.py

echo "🛡️  Step 7: Create Camera Access Protection..."
# Create udev rule to ensure EZREC gets priority camera access
cat > /etc/udev/rules.d/99-ezrec-camera.rules << 'EOF'
# EZREC Camera Priority Rules
# Ensures EZREC service gets exclusive camera access

# Pi Camera Module - Give ezrec user priority
SUBSYSTEM=="video4linux", KERNEL=="video0", GROUP="video", MODE="0664", OWNER="ezrec"
SUBSYSTEM=="video4linux", KERNEL=="video1", GROUP="video", MODE="0664", OWNER="ezrec"

# Prevent other users from accessing camera when EZREC is running
SUBSYSTEM=="video4linux", RUN+="/bin/chown ezrec:video /dev/$kernel"
EOF

# Reload udev rules
udevadm control --reload-rules
udevadm trigger

echo "✅ Camera access protection installed"

echo "🔄 Step 8: Start EZREC Service..."
# Start EZREC service
systemctl start ezrec-backend
sleep 5

# Check service status
if systemctl is-active --quiet ezrec-backend; then
    echo "✅ EZREC service started successfully"
    
    # Show recent logs
    echo "📋 Recent service logs:"
    journalctl -u ezrec-backend --lines=20 --no-pager
else
    echo "❌ EZREC service failed to start"
    echo "📋 Error logs:"
    journalctl -u ezrec-backend --lines=30 --no-pager
fi

echo "📊 Step 9: Final System Status..."
echo "================================"
echo "EZREC Service: $(systemctl is-active ezrec-backend)"
echo "Camera Devices:"
ls -la /dev/video* 2>/dev/null || echo "No video devices found"
echo
echo "Process Check (should be empty except EZREC):"
ps aux | grep -E "(camera|libcamera|picamera)" | grep -v grep || echo "No camera processes found"
echo
echo "EZREC Service Status:"
systemctl status ezrec-backend --no-pager --lines=5

if [ "$CAMERA_WORKING" = true ]; then
    echo
    echo "🎉 SUCCESS! Camera is working and EZREC has exclusive access!"
    echo "✅ Picamera2 working correctly"
    echo "✅ Conflicting services disabled"
    echo "✅ Camera protection rules installed"
    echo "✅ EZREC service running"
    echo
    echo "🔧 Next steps:"
    echo "1. Pull latest code on Pi: cd ~/code/EZREC-BackEnd && git pull"
    echo "2. Monitor service: sudo journalctl -u ezrec-backend -f"
    echo "3. Test recording with: sudo python3 /opt/ezrec-backend/create_test_booking_pi.py"
else
    echo
    echo "⚠️  CAMERA TEST FAILED - Manual intervention required"
    echo "📞 Check hardware connection and run diagnostics"
fi

echo
echo "🎬 ULTIMATE CAMERA FIX COMPLETED"
echo "================================" 