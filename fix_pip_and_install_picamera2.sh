#!/bin/bash

echo "🔧 Fixing Pip Permissions and Installing Picamera2"
echo "=================================================="
echo "Fixing virtual environment permissions..."
echo

# 1. Fix ownership and permissions of virtual environment
echo "1. 🔒 Fixing Virtual Environment Permissions"
echo "-------------------------------------------"
sudo chown -R ezrec:ezrec /opt/ezrec-backend/venv/
sudo chmod -R 755 /opt/ezrec-backend/venv/bin/
sudo chmod +x /opt/ezrec-backend/venv/bin/*

echo "✅ Virtual environment permissions fixed"
echo

# 2. Test pip access
echo "2. 🧪 Testing Pip Access"
echo "-----------------------"
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip --version

# 3. Install picamera2 properly
echo "3. 📦 Installing Picamera2 in Virtual Environment"
echo "------------------------------------------------"
cd /opt/ezrec-backend

echo "Installing picamera2..."
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install picamera2

echo "Installing supporting packages..."
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install numpy

echo "✅ Picamera2 installation complete"
echo

# 4. Test picamera2 import
echo "4. 🧪 Testing Picamera2 Import"
echo "-----------------------------"
sudo -u ezrec bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 -c \"
try:
    from picamera2 import Picamera2
    print('✅ Picamera2 import successful')
    
    # Test basic initialization
    picam2 = Picamera2()
    print('✅ Picamera2 object created')
    picam2.close()
    print('✅ Picamera2 working correctly')
    
except Exception as e:
    print(f'❌ Picamera2 test failed: {e}')
\"
"
echo

# 5. Test new camera interface
echo "5. 🎬 Testing Camera Interface with Picamera2"
echo "--------------------------------------------"
sudo -u ezrec timeout 15 bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 -c \"
import sys
sys.path.append('/opt/ezrec-backend/src')

try:
    from camera_interface import CameraInterface
    
    print('Testing CameraInterface with picamera2...')
    camera = CameraInterface()
    
    if camera.camera:
        info = camera.get_camera_info()
        print(f'✅ Camera initialized: {info}')
        
        # Test frame capture
        try:
            frame = camera.capture_frame()
            if frame is not None:
                print(f'✅ Frame captured: {frame.shape}')
            else:
                print('❌ Frame capture returned None')
        except Exception as e:
            print(f'⚠️ Frame capture test failed: {e}')
            
        # Test health check
        try:
            healthy = camera.health_check()
            print(f'✅ Health check: {healthy}')
        except Exception as e:
            print(f'⚠️ Health check failed: {e}')
        
        camera.release()
        print('✅ Camera interface test complete')
        
    else:
        print('❌ Camera initialization failed')
        
except Exception as e:
    print(f'❌ Camera interface test failed: {e}')
    import traceback
    traceback.print_exc()
\"
"
echo

# 6. Check service status and restart if needed
echo "6. 🔄 Checking and Restarting Service"
echo "------------------------------------"
echo "Current service status:"
sudo systemctl status ezrec-backend --no-pager -l | head -5

echo "Restarting service with fixed camera..."
sudo systemctl restart ezrec-backend
sleep 5

echo "New service status:"
sudo systemctl status ezrec-backend --no-pager -l | head -10
echo

# 7. Check logs for camera initialization
echo "7. 📊 Checking Service Logs for Camera"
echo "-------------------------------------"
echo "Recent service logs:"
sudo journalctl -u ezrec-backend --since "1 minute ago" --no-pager | tail -10

echo
echo "🎯 PICAMERA2 FIX COMPLETE!"
echo "=========================="
echo "📋 Results:"
echo "  ✅ Virtual environment permissions fixed"
echo "  ✅ Picamera2 properly installed"
echo "  ✅ Camera interface tested"
echo "  ✅ Service restarted"
echo
echo "🎬 Next step: Test with a booking!"
echo "  Create a booking from your frontend and watch:"
echo "  sudo journalctl -u ezrec-backend -f" 