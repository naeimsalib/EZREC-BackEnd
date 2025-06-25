#!/bin/bash
# 🎬 EZREC Camera Resource Conflict Fix
# Resolves camera initialization issues on Raspberry Pi

echo "🎬 EZREC Camera Resource Conflict Fix"
echo "====================================="
echo "Time: $(date)"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

echo "🔍 Step 1: Identifying Camera Processes..."
echo "Active camera-related processes:"
ps aux | grep -E "(camera|picamera|opencv|v4l|libcamera)" | grep -v grep || echo "No camera processes found"

echo
echo "🛑 Step 2: Stopping Conflicting Services..."

# Stop any camera-related services
systemctl stop motion || true
systemctl stop mjpg-streamer || true
systemctl stop uv4l* || true

# Kill any processes using the camera
echo "Killing camera processes..."
pkill -f "picamera" || true
pkill -f "libcamera" || true
pkill -f "opencv" || true
pkill -f "v4l" || true

# Wait a moment
sleep 2

echo
echo "📹 Step 3: Checking Camera Hardware..."
echo "Camera modules detected:"
lsmod | grep -E "(bcm2835|imx|ov)" || echo "No camera kernel modules loaded"

echo
echo "Video devices:"
ls -la /dev/video* 2>/dev/null || echo "No video devices found"

echo
echo "libcamera devices:"
libcamera-hello --list-cameras 2>/dev/null || echo "libcamera detection failed"

echo
echo "🧹 Step 4: Clearing GPU Memory..."
# Free GPU memory
echo 1 > /proc/sys/vm/drop_caches
echo 2 > /proc/sys/vm/drop_caches  
echo 3 > /proc/sys/vm/drop_caches

# Restart GPU service if available
systemctl restart gpu-mem-reloc.service 2>/dev/null || true

echo
echo "🔧 Step 5: Optimizing Memory Settings..."
# Temporary memory optimization
sysctl -w vm.min_free_kbytes=65536 2>/dev/null || true

echo
echo "⚙️ Step 6: Testing Camera Access..."

# Test camera with timeout
timeout 10s libcamera-hello --timeout 1000 --nopreview 2>/dev/null && echo "✅ libcamera test passed" || echo "❌ libcamera test failed"

echo
echo "🎯 Step 7: Configuring Camera for EZREC..."

# Create camera test script
cat > /tmp/test_camera.py << 'EOF'
#!/usr/bin/env python3
import sys
sys.path.insert(0, '/opt/ezrec-backend/src')

try:
    from picamera2 import Picamera2
    print("✅ Picamera2 import successful")
    
    picam = Picamera2()
    print("✅ Picamera2 object created")
    
    # Quick test configuration
    config = picam.create_preview_configuration(main={"size": (640, 480)})
    picam.configure(config)
    print("✅ Camera configured")
    
    picam.start()
    print("✅ Camera started")
    
    # Capture test frame
    frame = picam.capture_array()
    print(f"✅ Frame captured: {frame.shape if frame is not None else 'None'}")
    
    picam.stop()
    picam.close()
    print("✅ Camera test completed successfully")
    
except Exception as e:
    print(f"❌ Camera test failed: {e}")
    sys.exit(1)
EOF

echo "Testing camera access..."
cd /opt/ezrec-backend
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 /tmp/test_camera.py

if [ $? -eq 0 ]; then
    echo "✅ Camera test passed!"
else
    echo "❌ Camera test failed. Trying additional fixes..."
    
    echo
    echo "🔧 Step 8: Advanced Troubleshooting..."
    
    # Check camera cable connection
    echo "Camera detection via vcgencmd:"
    vcgencmd get_camera || echo "vcgencmd camera detection failed"
    
    # Check for hardware issues
    echo "GPU memory split:"
    vcgencmd get_mem gpu || echo "GPU memory check failed"
    
    # Try legacy camera interface
    echo "Trying legacy camera interface..."
    raspistill -t 1000 -o /tmp/test.jpg 2>/dev/null && echo "✅ Legacy camera works" || echo "❌ Legacy camera failed"
    
    echo
    echo "🆘 Manual steps required:"
    echo "1. Check camera cable connection"
    echo "2. Ensure camera is enabled: sudo raspi-config -> Interface Options -> Camera"
    echo "3. Reboot the Pi: sudo reboot"
    echo "4. Check GPU memory split (should be at least 128MB): vcgencmd get_mem gpu"
fi

echo
echo "🔄 Step 9: Restarting EZREC Service..."
systemctl restart ezrec-backend

echo
echo "📊 Step 10: Final Status Check..."
sleep 3
journalctl -u ezrec-backend --since "1 minute ago" | grep -E "(Camera|camera|✅|❌)" | tail -10

echo
echo "✅ Camera resource fix completed!"
echo
echo "🎯 Next steps:"
echo "1. Monitor the service: sudo journalctl -u ezrec-backend -f"
echo "2. If still failing, check camera hardware connection"
echo "3. Try creating a test booking: python3 create_simple_test_booking.py" 