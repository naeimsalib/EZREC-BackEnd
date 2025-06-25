#!/bin/bash
# EZREC Final Camera Resource Fix - IMX477 Specific
# Addresses "Device or resource busy" error for Pi Camera Module V2.1

echo "🎬 EZREC Final Camera Resource Fix for IMX477"
echo "============================================="
echo "Time: $(date)"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

echo "🔍 Step 1: Stopping EZREC Service..."
systemctl stop ezrec-backend
sleep 3

echo "🛑 Step 2: Aggressive Camera Process Cleanup..."
# Kill all camera-related processes
pkill -f "python.*camera"
pkill -f "libcamera"
pkill -f "v4l2"
pkill -f "gstreamer"
pkill -f "opencv"
pkill -f "picamera"

# Wait for processes to fully terminate
sleep 5

echo "📹 Step 3: Camera Module Reset..."
# Unload and reload camera modules
modprobe -r imx477 2>/dev/null || true
modprobe -r v4l2_common 2>/dev/null || true
modprobe -r videodev 2>/dev/null || true

# Wait for module unload
sleep 3

# Reload modules in correct order
modprobe videodev
modprobe v4l2_common
modprobe imx477

echo "🧹 Step 4: Clear System Resources..."
# Clear shared memory
rm -rf /dev/shm/sem.* 2>/dev/null || true
rm -rf /tmp/.X11-unix/* 2>/dev/null || true

# Reset GPU firmware
echo "Resetting GPU firmware..."
vcgencmd reset

# Wait for reset
sleep 5

echo "⚙️ Step 5: Configure GPU Memory..."
# Ensure adequate GPU memory (minimum 128MB for camera)
current_gpu=$(vcgencmd get_mem gpu | grep -o '[0-9]*')
if [ "$current_gpu" -lt 128 ]; then
    echo "📝 GPU memory too low ($current_gpu MB), updating to 128MB..."
    
    # Update config.txt
    if ! grep -q "gpu_mem=128" /boot/firmware/config.txt; then
        echo "gpu_mem=128" >> /boot/firmware/config.txt
        echo "⚠️ GPU memory updated. Reboot required after this script."
    fi
fi

echo "🔧 Step 6: Camera Hardware Initialization..."
# Force camera detection
vcgencmd get_camera

# Test libcamera detection
echo "Testing libcamera detection..."
timeout 10 libcamera-hello --list-cameras || echo "libcamera test timed out"

echo "⚡ Step 7: V4L2 Device Reset..."
# Reset all video devices
for device in /dev/video*; do
    if [ -e "$device" ]; then
        # Clear any locks on the device
        fuser -k "$device" 2>/dev/null || true
    fi
done

echo "🎯 Step 8: Test Camera Access..."
# Create a simple camera test
cat > /tmp/camera_test.py << 'EOF'
#!/usr/bin/env python3
import sys
import time

try:
    from picamera2 import Picamera2
    print("✅ Picamera2 import successful")
    
    # Brief delay to ensure modules are ready
    time.sleep(2)
    
    picam = Picamera2()
    print("✅ Picamera2 object created")
    
    # Configure with minimal settings
    config = picam.create_still_configuration(main={"size": (640, 480)})
    picam.configure(config)
    print("✅ Camera configured")
    
    picam.start()
    print("✅ Camera started successfully")
    
    # Capture test frame
    picam.capture_array()
    print("✅ Test frame captured")
    
    picam.stop()
    picam.close()
    print("✅ Camera test completed successfully")
    
except Exception as e:
    print(f"❌ Camera test failed: {e}")
    sys.exit(1)
EOF

# Run camera test
echo "Running camera functionality test..."
if python3 /tmp/camera_test.py; then
    echo "✅ Camera hardware test passed!"
else
    echo "❌ Camera hardware test failed"
    echo "🔧 Applying advanced fix..."
    
    # Additional reset for stubborn cases
    echo "Performing deep camera reset..."
    
    # Reset the camera firmware
    dtoverlay -r imx477 2>/dev/null || true
    sleep 2
    dtoverlay imx477 2>/dev/null || true
    sleep 3
    
    # Try test again
    if python3 /tmp/camera_test.py; then
        echo "✅ Camera working after advanced reset"
    else
        echo "❌ Camera still not working. Manual intervention required."
    fi
fi

# Cleanup test file
rm -f /tmp/camera_test.py

echo "🔄 Step 9: Restart EZREC Service..."
systemctl start ezrec-backend
sleep 5

echo "📊 Step 10: Service Verification..."
if systemctl is-active --quiet ezrec-backend; then
    echo "✅ EZREC service is running"
    
    # Check recent logs for camera errors
    echo "Checking for camera initialization in logs..."
    journalctl -u ezrec-backend --since "1 minute ago" --no-pager | grep -i camera || echo "No camera messages in recent logs"
else
    echo "❌ EZREC service failed to start"
    echo "Service status:"
    systemctl status ezrec-backend --no-pager -l
fi

echo
echo "✅ Final camera resource fix completed!"
echo
echo "🎯 Verification steps:"
echo "1. Monitor service: sudo journalctl -u ezrec-backend -f"
echo "2. Test booking creation: cd /opt/ezrec-backend && python3 create_simple_test_booking.py"
echo "3. If camera still fails, reboot may be required: sudo reboot"
echo
echo "📋 Current system status:"
systemctl is-active ezrec-backend && echo "✅ Service: Running" || echo "❌ Service: Stopped"
vcgencmd get_camera 2>/dev/null && echo "✅ Camera: Detected" || echo "❌ Camera: Not detected" 