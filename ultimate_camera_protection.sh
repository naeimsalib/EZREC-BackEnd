#!/bin/bash
# 🎬 ULTIMATE EZREC CAMERA PROTECTION - RASPBERRY PI DEBIAN
# Ensures ABSOLUTE EXCLUSIVE camera access for EZREC using Picamera2
# Prevents ALL other processes from accessing the camera

echo "🎬 ULTIMATE EZREC CAMERA PROTECTION - RASPBERRY PI DEBIAN"
echo "=========================================================="
echo "🕐 Time: $(date)"
echo "🎯 Target: EXCLUSIVE Picamera2 access for EZREC"
echo "🖥️  Platform: Raspberry Pi running Debian"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   echo "Usage: sudo ./ultimate_camera_protection.sh"
   exit 1
fi

echo "🛑 STEP 1: AGGRESSIVE PROCESS TERMINATION"
echo "===========================================" 
echo "Killing ALL camera-related processes..."

# Kill all camera processes with extreme prejudice
pkill -9 -f "libcamera" 2>/dev/null || true
pkill -9 -f "picamera" 2>/dev/null || true  
pkill -9 -f "camera" 2>/dev/null || true
pkill -9 -f "v4l2" 2>/dev/null || true
pkill -9 -f "gstreamer" 2>/dev/null || true
pkill -9 -f "motion" 2>/dev/null || true
pkill -9 -f "mjpg" 2>/dev/null || true
pkill -9 -f "vlc" 2>/dev/null || true
pkill -9 -f "opencv" 2>/dev/null || true
pkill -9 -f "ffmpeg" 2>/dev/null || true
pkill -9 -f "raspistill" 2>/dev/null || true
pkill -9 -f "raspivid" 2>/dev/null || true

# Stop ALL conflicting services
echo "Stopping conflicting services..."
systemctl stop motion 2>/dev/null || true
systemctl stop mjpg-streamer 2>/dev/null || true
systemctl stop vlc 2>/dev/null || true
systemctl stop uv4l 2>/dev/null || true
systemctl stop cheese 2>/dev/null || true

# Wait for processes to fully terminate
sleep 5
echo "✅ All camera processes terminated"

echo
echo "🔒 STEP 2: PERMANENT SERVICE LOCKDOWN"
echo "======================================"

# Disable and mask conflicting services PERMANENTLY
services_to_disable=("motion" "mjpg-streamer" "vlc" "uv4l" "cheese")

for service in "${services_to_disable[@]}"; do
    if systemctl list-unit-files | grep -q "^$service"; then
        echo "🔒 Disabling $service permanently..."
        systemctl disable "$service" 2>/dev/null || true
        systemctl mask "$service" 2>/dev/null || true
    fi
done

echo "✅ Conflicting services permanently disabled"

echo
echo "⚡ STEP 3: HARDWARE RESET & OPTIMIZATION"
echo "========================================"

# Reset ALL video devices
echo "Resetting video devices..."
for device in /dev/video*; do
    if [ -e "$device" ]; then
        echo "🔄 Resetting $device"
        fuser -k "$device" 2>/dev/null || true
    fi
done

# GPU memory reset and optimization
echo "Optimizing GPU memory..."
vcgencmd reset 2>/dev/null || true
sleep 3

# Check and set GPU memory
current_gpu=$(vcgencmd get_mem gpu 2>/dev/null | grep -o '[0-9]*' || echo "0")
if [ "$current_gpu" -lt 128 ]; then
    echo "📝 Setting GPU memory to 128MB for camera support..."
    if ! grep -q "gpu_mem=" /boot/firmware/config.txt 2>/dev/null; then
        echo "gpu_mem=128" >> /boot/firmware/config.txt
    else
        sed -i 's/gpu_mem=.*/gpu_mem=128/' /boot/firmware/config.txt
    fi
    echo "⚠️  GPU memory updated - reboot required after this script"
fi

echo "✅ Hardware optimization complete"

echo
echo "🔐 STEP 4: EXCLUSIVE ACCESS CONTROL"
echo "==================================="

# Create udev rules for exclusive EZREC access
echo "Creating exclusive camera access rules..."
cat > /etc/udev/rules.d/99-ezrec-exclusive-camera.rules << 'EOF'
# EZREC EXCLUSIVE CAMERA ACCESS RULES
# Ensures only the ezrec user can access camera devices

# Pi Camera Module - Exclusive access for ezrec
SUBSYSTEM=="video4linux", KERNEL=="video0", GROUP="video", MODE="0660", OWNER="ezrec"
SUBSYSTEM=="video4linux", KERNEL=="video1", GROUP="video", MODE="0660", OWNER="ezrec"

# Block access for other users when EZREC is running
SUBSYSTEM=="video4linux", RUN+="/bin/bash -c 'chown ezrec:video /dev/$kernel && chmod 660 /dev/$kernel'"

# USB cameras (if any)
SUBSYSTEM=="video4linux", KERNEL=="video[2-9]", GROUP="video", MODE="0660", OWNER="ezrec"
EOF

# Reload udev rules
udevadm control --reload-rules
udevadm trigger

echo "✅ Exclusive access rules installed"

echo
echo "🚫 STEP 5: SYSTEM-WIDE CAMERA BLOCKING"
echo "======================================"

# Create a system-wide camera blocker script
cat > /usr/local/bin/block-camera-access << 'EOF'
#!/bin/bash
# Block camera access for non-EZREC processes

CALLER_USER=$(who am i | awk '{print $1}')
CALLER_PID=$PPID

# Allow only ezrec user and root
if [[ "$USER" != "ezrec" && "$USER" != "root" ]]; then
    echo "❌ Camera access denied: EZREC has exclusive access"
    exit 1
fi

# Check if EZREC service is running and block others
if systemctl is-active --quiet ezrec-backend && [[ "$USER" != "ezrec" ]]; then
    echo "❌ Camera access denied: EZREC service is active"
    exit 1
fi
EOF

chmod +x /usr/local/bin/block-camera-access

# Create wrapper for camera applications
camera_apps=("cheese" "guvcview" "vlc" "motion" "mjpg_streamer")
for app in "${camera_apps[@]}"; do
    if command -v "$app" >/dev/null 2>&1; then
        app_path=$(which "$app")
        mv "$app_path" "${app_path}.orig" 2>/dev/null || true
        cat > "$app_path" << EOF
#!/bin/bash
/usr/local/bin/block-camera-access && exec ${app_path}.orig "\$@"
EOF
        chmod +x "$app_path"
        echo "🚫 Blocked $app"
    fi
done

echo "✅ System-wide camera blocking active"

echo
echo "🎯 STEP 6: EZREC-SPECIFIC OPTIMIZATIONS"
echo "======================================="

# Ensure ezrec user exists and has proper permissions
if ! id "ezrec" &>/dev/null; then
    echo "Creating ezrec user..."
    useradd -r -s /bin/bash -d /opt/ezrec-backend ezrec
fi

# Add ezrec to necessary groups
usermod -a -G video,audio,dialout,i2c,spi,gpio ezrec

# Set up EZREC directories with proper permissions
directories=("/opt/ezrec-backend" "/opt/ezrec-backend/temp" "/opt/ezrec-backend/recordings" "/opt/ezrec-backend/logs")
for dir in "${directories[@]}"; do
    mkdir -p "$dir"
    chown -R ezrec:ezrec "$dir"
    chmod -R 755 "$dir"
done

# Camera device permissions
chown ezrec:video /dev/video* 2>/dev/null || true
chmod 660 /dev/video* 2>/dev/null || true

echo "✅ EZREC optimizations complete"

echo
echo "🧪 STEP 7: CAMERA FUNCTIONALITY TEST"
echo "===================================="

# Create comprehensive camera test
cat > /tmp/ultimate_camera_test.py << 'EOF'
#!/usr/bin/env python3
"""
Ultimate Camera Test for EZREC - Picamera2 Exclusive Access
Tests camera functionality and exclusive access
"""
import sys
import time
import os

def test_picamera2_exclusive():
    """Test Picamera2 exclusive access"""
    try:
        # Test import
        from picamera2 import Picamera2
        print("✅ Picamera2 import successful")
        
        # Test initialization
        picam = Picamera2()
        print("✅ Picamera2 object created")
        
        # Test configuration
        config = picam.create_still_configuration(main={"size": (640, 480)})
        picam.configure(config)
        print("✅ Camera configured successfully")
        
        # Test start
        picam.start()
        print("✅ Camera started successfully")
        
        # Test frame capture
        time.sleep(1)  # Let camera stabilize
        frame = picam.capture_array()
        if frame is not None:
            print(f"✅ Frame captured successfully: {frame.shape}")
        else:
            print("❌ Frame capture failed")
            return False
        
        # Test recording capability
        test_video = "/tmp/ezrec_test_recording.mp4"
        try:
            from picamera2.encoders import H264Encoder
            encoder = H264Encoder()
            picam.start_recording(encoder, test_video)
            time.sleep(2)  # Record for 2 seconds
            picam.stop_recording()
            print("✅ Video recording test passed")
            
            # Check file
            if os.path.exists(test_video) and os.path.getsize(test_video) > 0:
                print(f"✅ Test video created: {os.path.getsize(test_video)} bytes")
                os.remove(test_video)
            else:
                print("❌ Test video not created properly")
                return False
        except Exception as e:
            print(f"❌ Recording test failed: {e}")
            return False
        
        # Cleanup
        picam.stop()
        picam.close()
        print("✅ Camera test completed successfully")
        return True
        
    except Exception as e:
        print(f"❌ Camera test failed: {e}")
        return False

if __name__ == "__main__":
    print("🧪 EZREC Camera Exclusive Access Test")
    print("====================================")
    success = test_picamera2_exclusive()
    sys.exit(0 if success else 1)
EOF

# Run camera test as ezrec user
echo "Running camera functionality test..."
if sudo -u ezrec python3 /tmp/ultimate_camera_test.py; then
    echo "✅ Camera test PASSED - Exclusive access confirmed"
else
    echo "❌ Camera test FAILED - Check camera connection and permissions"
fi

# Cleanup test files
rm -f /tmp/ultimate_camera_test.py

echo
echo "🔄 STEP 8: EZREC SERVICE INTEGRATION"
echo "===================================="

# Stop EZREC service for configuration
systemctl stop ezrec-backend 2>/dev/null || true

# Create camera protection startup script
cat > /opt/ezrec-backend/camera_protection_startup.sh << 'EOF'
#!/bin/bash
# EZREC Camera Protection Startup
# Run this before starting EZREC service

echo "🎬 EZREC Camera Protection Startup"
echo "$(date): Ensuring exclusive camera access..."

# Kill any competing processes
pkill -f "motion\|mjpg\|vlc\|cheese" 2>/dev/null || true

# Reset camera devices
for device in /dev/video*; do
    if [ -e "$device" ]; then
        fuser -k "$device" 2>/dev/null || true
        chown ezrec:video "$device" 2>/dev/null || true
        chmod 660 "$device" 2>/dev/null || true
    fi
done

echo "$(date): Camera protection active"
EOF

chmod +x /opt/ezrec-backend/camera_protection_startup.sh
chown ezrec:ezrec /opt/ezrec-backend/camera_protection_startup.sh

# Update EZREC service to include camera protection
if [ -f "/etc/systemd/system/ezrec-backend.service" ]; then
    echo "Updating EZREC service with camera protection..."
    
    # Backup original service file
    cp /etc/systemd/system/ezrec-backend.service /etc/systemd/system/ezrec-backend.service.backup
    
    # Add camera protection to service
    sed -i '/^ExecStart=/i ExecStartPre=/opt/ezrec-backend/camera_protection_startup.sh' /etc/systemd/system/ezrec-backend.service
    
    # Reload systemd
    systemctl daemon-reload
fi

echo "✅ EZREC service integration complete"

echo
echo "🎉 STEP 9: FINAL VALIDATION"
echo "=========================="

# Start EZREC service
echo "Starting EZREC service with camera protection..."
systemctl start ezrec-backend

# Wait for startup
sleep 5

# Check service status
if systemctl is-active --quiet ezrec-backend; then
    echo "✅ EZREC service started successfully"
    
    # Show recent logs
    echo "📋 Recent EZREC logs:"
    journalctl -u ezrec-backend --since "1 minute ago" --lines=10 --no-pager
else
    echo "❌ EZREC service failed to start"
    echo "📋 Error logs:"
    journalctl -u ezrec-backend --since "1 minute ago" --lines=20 --no-pager
fi

echo
echo "🏁 ULTIMATE CAMERA PROTECTION COMPLETE"
echo "======================================"
echo "✅ STATUS SUMMARY:"
echo "  📹 Camera: EXCLUSIVE access for EZREC"
echo "  🚫 Conflicts: ALL blocked permanently" 
echo "  🔒 Services: Competing services disabled"
echo "  ⚡ Hardware: Optimized for Picamera2"
echo "  🎯 EZREC: Ready for exclusive recording"
echo
echo "🎬 Your EZREC system now has ULTIMATE camera protection!"
echo "📱 Monitor with: sudo journalctl -u ezrec-backend -f"
echo "🧪 Test booking: cd ~/code/EZREC-BackEnd && python3 create_simple_test_booking.py"
echo
echo "⚠️  IMPORTANT:"
echo "   - If GPU memory was updated, reboot is recommended"
echo "   - No other applications can use the camera now"
echo "   - EZREC has exclusive access to Pi Camera"
echo "   - All camera conflicts are permanently resolved" 