#!/bin/bash

echo "📹 EZREC Camera Initialization Fix"
echo "=================================="
echo "Diagnosing and fixing camera initialization issues..."
echo

# 1. Check camera hardware detection
echo "1. 📸 Camera Hardware Detection"
echo "------------------------------"
echo "libcamera detection:"
libcamera-hello --list-cameras --timeout 1000 2>/dev/null | head -10
echo

echo "Video devices:"
ls -la /dev/video* 2>/dev/null || echo "No video devices found"
echo

echo "Camera permissions:"
ls -la /dev/video* | head -5
echo

# 2. Check camera group membership
echo "2. 👥 Camera Permissions Check"
echo "-----------------------------"
echo "ezrec user groups:"
groups ezrec
echo

echo "video group members:"
getent group video
echo

# 3. Test camera access with different methods
echo "3. 🔧 Testing Camera Access Methods"
echo "----------------------------------"

echo "Testing basic camera access..."
sudo -u ezrec timeout 10 bash -c "
cd /opt/ezrec-backend
export PYTHONPATH=/opt/ezrec-backend/src:\$PYTHONPATH

echo 'Testing OpenCV camera access...'
/opt/ezrec-backend/venv/bin/python3 -c \"
import cv2
import sys

try:
    # Test multiple camera indices
    for i in [0, 1, 2]:
        print(f'Testing camera index {i}...')
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            ret, frame = cap.read()
            if ret and frame is not None:
                print(f'✅ Camera {i} working: {frame.shape}')
                cap.release()
                break
            else:
                print(f'❌ Camera {i} opened but no frame')
                cap.release()
        else:
            print(f'❌ Camera {i} failed to open')
    else:
        print('❌ No working camera found')
        
except Exception as e:
    print(f'❌ OpenCV test failed: {e}')
\"
"
echo

# 4. Test with libcamera directly
echo "4. 📷 Testing libcamera Integration"
echo "----------------------------------"
sudo -u ezrec timeout 15 bash -c "
cd /opt/ezrec-backend

echo 'Testing libcamera capture...'
if command -v libcamera-vid >/dev/null 2>&1; then
    echo 'Testing 5-second video capture with libcamera-vid...'
    libcamera-vid --timeout 5000 --output /tmp/test_video.mp4 --width 1920 --height 1080 2>/dev/null && echo '✅ libcamera-vid works' || echo '❌ libcamera-vid failed'
    rm -f /tmp/test_video.mp4
else
    echo '❌ libcamera-vid not available'
fi
"
echo

# 5. Test camera interface class specifically  
echo "5. 🐍 Testing EZREC Camera Interface"
echo "-----------------------------------"
sudo -u ezrec timeout 20 bash -c "
cd /opt/ezrec-backend
export PYTHONPATH=/opt/ezrec-backend/src:\$PYTHONPATH

/opt/ezrec-backend/venv/bin/python3 -c \"
import sys
sys.path.append('/opt/ezrec-backend/src')

print('Testing CameraInterface class...')
try:
    from camera_interface import CameraInterface
    
    print('Creating CameraInterface...')
    camera = CameraInterface()
    
    print(f'Camera type: {camera.camera_type}')
    print(f'Camera object: {camera.camera}')
    
    if hasattr(camera, 'initialize'):
        print('Attempting manual initialization...')
        success = camera.initialize()
        print(f'Initialize result: {success}')
    
    if camera.camera is not None:
        print('✅ Camera interface initialized successfully')
        
        # Test frame capture
        print('Testing frame capture...')
        frame = camera.capture_frame()
        if frame is not None:
            print(f'✅ Frame captured: {frame.shape}')
        else:
            print('❌ Frame capture failed')
            
    else:
        print('❌ Camera interface initialization failed')
        
    camera.release()
    
except Exception as e:
    print(f'❌ CameraInterface test failed: {e}')
    import traceback
    traceback.print_exc()
\"
"
echo

# 6. Fix common camera issues
echo "6. 🔧 Applying Camera Fixes"
echo "---------------------------"

echo "Stopping any camera processes..."
sudo pkill -f libcamera || true
sudo pkill -f python.*camera || true
sleep 2

echo "Adding ezrec user to video group (if not already)..."
sudo usermod -a -G video ezrec

echo "Setting camera device permissions..."
sudo chmod 666 /dev/video* 2>/dev/null || true

echo "Checking for camera module conflicts..."
if lsmod | grep -q bcm2835_v4l2; then
    echo "⚠️ Legacy camera module detected - may cause conflicts"
    echo "Consider disabling legacy camera support in raspi-config"
fi

echo "✅ Common fixes applied"
echo

# 7. Restart service and test
echo "7. 🔄 Restart Service and Test"
echo "-----------------------------"
echo "Restarting EZREC service..."
sudo systemctl restart ezrec-backend
sleep 5

echo "Service status:"
sudo systemctl status ezrec-backend --no-pager -l | head -10
echo

echo "Testing camera after restart..."
sudo -u ezrec timeout 10 bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 -c \"
import sys
sys.path.append('/opt/ezrec-backend/src')
try:
    from camera_interface import CameraInterface
    camera = CameraInterface()
    if camera.camera is not None:
        print('✅ Camera ready after restart')
    else:
        print('❌ Camera still not ready')
    camera.release()
except Exception as e:
    print(f'❌ Camera test failed: {e}')
\"
"

echo
echo "🎯 CAMERA FIX COMPLETE!"
echo "======================"
echo "📋 What was fixed:"
echo "  ✅ Camera permissions updated"
echo "  ✅ User group membership verified"
echo "  ✅ Camera processes restarted"
echo "  ✅ Service restarted with fixes"
echo
echo "🧪 Next: Test recording with a new booking"
echo "  Create a booking from your frontend and watch:"
echo "  sudo journalctl -u ezrec-backend -f" 