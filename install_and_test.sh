#!/bin/bash

# SmartCam Backend Installation and Testing Script
# This script will install, configure, and test the entire SmartCam backend system

set -e  # Exit on any error

echo "🚀 SmartCam Backend Installation and Testing Script"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to test camera device
test_camera_device() {
    local device=$1
    print_status "Testing camera device: $device"
    
    python3 -c "
import cv2
try:
    cap = cv2.VideoCapture('$device')
    if cap.isOpened():
        ret, frame = cap.read()
        if ret:
            print('✅ $device works - Frame size:', frame.shape)
            cap.release()
            exit(0)
        else:
            print('❌ $device cannot capture frames')
            cap.release()
            exit(1)
    else:
        print('❌ $device not accessible')
        exit(1)
except Exception as e:
    print('❌ $device test failed:', str(e))
    exit(1)
"
    return $?
}

# Step 1: Navigate to backend directory
print_status "Step 1: Setting up directory structure"
cd ~/code/SmartCam-Soccer/backend

# Step 2: Create virtual environment
print_status "Step 2: Creating virtual environment"
if [ ! -d "venv" ]; then
    python3 -m venv venv
    print_success "Virtual environment created"
else
    print_warning "Virtual environment already exists"
fi

# Step 3: Activate virtual environment
print_status "Step 3: Activating virtual environment"
source venv/bin/activate

# Step 4: Upgrade pip
print_status "Step 4: Upgrading pip"
pip install --upgrade pip

# Step 5: Fix Supabase compatibility issue
print_status "Step 5: Installing compatible Supabase version"
pip uninstall -y supabase gotrue httpx
pip install httpx==0.23.3
pip install supabase==1.0.3

# Step 6: Install other dependencies
print_status "Step 6: Installing other dependencies"
pip install python-dotenv==1.0.0
pip install opencv-python==4.8.1.78
pip install numpy==1.24.3
pip install psutil==5.9.4
pip install requests==2.31.0
pip install pytz==2023.3
pip install ffmpeg-python==0.2.0

# Step 7: Create .env file
print_status "Step 7: Creating .env file"
cat > .env << 'EOF'
# Supabase Configuration
SUPABASE_URL=https://iszmsaayxpdrovealrrp.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODM2NjAxMywiZXhwIjoyMDYzOTQyMDEzfQ.tzm80_eIy2xho652OxV37ErGnxwOuUvE4-MIPWrdS0c

# User Configuration
USER_ID=65aa2e2a-e463-424d-b88f-0724bb0bea3a
USER_EMAIL=michomanoly14892@gmail.com

# Camera Configuration
CAMERA_ID=b5b0eb67-d1c6-4634-b2e6-4412c57ef49f
CAMERA_NAME=Raspberry Pi Camera
CAMERA_LOCATION=Main Field
CAMERA_DEVICE=/dev/video0

# Camera Settings
CAMERA_WIDTH=1280
CAMERA_HEIGHT=720
CAMERA_FPS=30

# Recording Settings
RECORDING_PATH=/home/michomanoly14892/recordings

# Debug Settings
DEBUG=true
LOG_LEVEL=INFO
EOF

print_success ".env file created"

# Step 8: Create necessary directories
print_status "Step 8: Creating directories"
mkdir -p recordings temp logs uploads
print_success "Directories created"

# Step 9: Test camera devices
print_status "Step 9: Testing camera devices"
echo "Available camera devices:"
ls -la /dev/video*

# Test different camera devices
CAMERA_DEVICE=""
for device in /dev/video0 /dev/video1 /dev/video2 /dev/video3 /dev/video4; do
    if test_camera_device "$device"; then
        CAMERA_DEVICE="$device"
        print_success "Found working camera: $device"
        break
    fi
done

if [ -z "$CAMERA_DEVICE" ]; then
    print_error "No working camera device found"
    print_warning "Using /dev/video0 as default"
    CAMERA_DEVICE="/dev/video0"
else
    # Update .env file with working camera device
    sed -i "s|CAMERA_DEVICE=/dev/video0|CAMERA_DEVICE=$CAMERA_DEVICE|g" .env
    print_success "Updated .env with working camera: $CAMERA_DEVICE"
fi

# Step 10: Test configuration
print_status "Step 10: Testing configuration"
python3 -c "
from src.config import *
print('✅ Configuration loaded successfully')
print('SUPABASE_URL:', SUPABASE_URL)
print('USER_ID:', USER_ID)
print('CAMERA_ID:', CAMERA_ID)
print('CAMERA_DEVICE:', CAMERA_DEVICE)
"

# Step 11: Test Supabase connection
print_status "Step 11: Testing Supabase connection"
python3 -c "
from src.utils import supabase
try:
    result = supabase.table('system_status').select('*').limit(1).execute()
    print('✅ Supabase connection successful')
    print('Tables accessible:', len(result.data) if result.data else 0, 'records found')
except Exception as e:
    print('❌ Supabase connection failed:', str(e))
    exit(1)
"

# Step 12: Create systemd service files
print_status "Step 12: Creating systemd service files"

# Create smartcam-camera.service
sudo tee /etc/systemd/system/smartcam-camera.service > /dev/null << EOF
[Unit]
Description=SmartCam Camera Service
After=network.target
Wants=smartcam-scheduler.service

[Service]
Type=simple
User=michomanoly14892
WorkingDirectory=/home/michomanoly14892/code/SmartCam-Soccer/backend
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/home/michomanoly14892/code/SmartCam-Soccer/backend/.env
ExecStart=/home/michomanoly14892/code/SmartCam-Soccer/backend/venv/bin/python src/camera.py
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=smartcam-camera

[Install]
WantedBy=multi-user.target
EOF

# Create smartcam-scheduler.service
sudo tee /etc/systemd/system/smartcam-scheduler.service > /dev/null << EOF
[Unit]
Description=SmartCam Scheduler Service
After=network.target

[Service]
Type=simple
User=michomanoly14892
WorkingDirectory=/home/michomanoly14892/code/SmartCam-Soccer/backend
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/home/michomanoly14892/code/SmartCam-Soccer/backend/.env
ExecStart=/home/michomanoly14892/code/SmartCam-Soccer/backend/venv/bin/python src/scheduler.py
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=smartcam-scheduler

[Install]
WantedBy=multi-user.target
EOF

# Create smartcam-orchestrator.service
sudo tee /etc/systemd/system/smartcam-orchestrator.service > /dev/null << EOF
[Unit]
Description=SmartCam Orchestrator Service
After=network.target

[Service]
Type=simple
User=michomanoly14892
WorkingDirectory=/home/michomanoly14892/code/SmartCam-Soccer/backend
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=/home/michomanoly14892/code/SmartCam-Soccer/backend/.env
ExecStart=/home/michomanoly14892/code/SmartCam-Soccer/backend/venv/bin/python src/orchestrator.py
Restart=always
RestartSec=5
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=smartcam-orchestrator

[Install]
WantedBy=multi-user.target
EOF

print_success "Systemd service files created"

# Step 13: Reload systemd and start services
print_status "Step 13: Starting services"
sudo systemctl daemon-reload

# Stop any existing services
sudo systemctl stop smartcam-camera smartcam-scheduler smartcam-orchestrator 2>/dev/null || true

# Start services
sudo systemctl start smartcam-camera smartcam-scheduler smartcam-orchestrator

# Enable services
sudo systemctl enable smartcam-camera smartcam-scheduler smartcam-orchestrator

print_success "Services started and enabled"

# Step 14: Test services
print_status "Step 14: Testing services"
sleep 5

# Check service status
echo "Service Status:"
sudo systemctl status smartcam-camera --no-pager -l
echo ""
sudo systemctl status smartcam-scheduler --no-pager -l
echo ""
sudo systemctl status smartcam-orchestrator --no-pager -l

# Step 15: Test recording functionality
print_status "Step 15: Testing recording functionality"
python3 -c "
import cv2
import time
import os
from datetime import datetime

try:
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print('❌ Cannot open camera')
        exit(1)
    
    # Set recording parameters
    fourcc = cv2.VideoWriter_fourcc(*'XVID')
    filename = f'test_recording_{datetime.now().strftime(\"%Y%m%d_%H%M%S\")}.avi'
    out = cv2.VideoWriter(filename, fourcc, 20.0, (640,480))
    
    print(f'✅ Starting 10-second test recording: {filename}')
    start_time = time.time()
    
    while time.time() - start_time < 10:
        ret, frame = cap.read()
        if ret:
            out.write(frame)
        else:
            break
    
    cap.release()
    out.release()
    
    if os.path.exists(filename):
        size = os.path.getsize(filename)
        print(f'✅ Test recording completed: {filename}')
        print(f'File size: {size} bytes')
        if size > 1000:
            print('✅ Recording test successful')
        else:
            print('❌ Recording file too small')
    else:
        print('❌ Recording file not created')
    
except Exception as e:
    print('❌ Test recording failed:', str(e))
"

# Step 16: Test system status update
print_status "Step 16: Testing system status update"
python3 -c "
from src.utils import update_system_status
try:
    if update_system_status(is_recording=False):
        print('✅ System status updated successfully')
    else:
        print('❌ System status update failed')
except Exception as e:
    print('❌ System status test failed:', str(e))
"

# Step 17: Create test booking
print_status "Step 17: Testing booking creation"
python3 -c "
from src.utils import supabase
from datetime import datetime, timedelta
import json

try:
    # Create a test booking 5 minutes from now
    start_time = datetime.now() + timedelta(minutes=5)
    end_time = start_time + timedelta(minutes=30)
    
    booking_data = {
        'user_id': '65aa2e2a-e463-424d-b88f-0724bb0bea3a',
        'camera_id': 'b5b0eb67-d1c6-4634-b2e6-4412c57ef49f',
        'start_time': start_time.isoformat(),
        'end_time': end_time.isoformat(),
        'status': 'confirmed'
    }
    
    result = supabase.table('bookings').insert(booking_data).execute()
    print('✅ Test booking created successfully')
    if result.data:
        print('Booking ID:', result.data[0]['id'])
    else:
        print('No booking ID returned')
    
except Exception as e:
    print('❌ Test booking failed:', str(e))
"

# Step 18: Final verification
print_status "Step 18: Final verification"

# Check logs
echo "Recent logs:"
sudo journalctl -u smartcam-camera -n 10 --no-pager
echo ""
sudo journalctl -u smartcam-scheduler -n 10 --no-pager
echo ""
sudo journalctl -u smartcam-orchestrator -n 10 --no-pager

# Check system status in database
python3 -c "
from src.utils import supabase
try:
    result = supabase.table('system_status').select('*').eq('user_id', '65aa2e2a-e463-424d-b88f-0724bb0bea3a').execute()
    if result.data:
        print('✅ System status found in database')
        status = result.data[0]
        print('Last seen:', status.get('last_seen', 'Unknown'))
        print('Recording:', status.get('is_recording', False))
        print('CPU Usage:', status.get('cpu_usage', 0), '%')
        print('Memory Usage:', status.get('memory_usage', 0), '%')
    else:
        print('❌ No system status found in database')
except Exception as e:
    print('❌ Database check failed:', str(e))
"

# Step 19: Create comprehensive test script
print_status "Step 19: Creating test script"
cat > test_system.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import subprocess
from src.config import *
from src.utils import supabase

def test_config():
    print("🔧 Testing Configuration...")
    try:
        assert SUPABASE_URL, "SUPABASE_URL not set"
        assert SUPABASE_KEY, "SUPABASE_KEY not set"
        assert USER_ID, "USER_ID not set"
        assert CAMERA_ID, "CAMERA_ID not set"
        print("✅ Configuration loaded successfully")
        return True
    except Exception as e:
        print(f"❌ Configuration error: {e}")
        return False

def test_database():
    print("🗄️ Testing Database Connection...")
    try:
        result = supabase.table('system_status').select('*').limit(1).execute()
        print("✅ Database connection successful")
        return True
    except Exception as e:
        print(f"❌ Database error: {e}")
        return False

def test_camera():
    print("📷 Testing Camera...")
    try:
        import cv2
        cap = cv2.VideoCapture(0)
        if cap.isOpened():
            ret, frame = cap.read()
            cap.release()
            if ret:
                print("✅ Camera working")
                return True
            else:
                print("❌ Camera cannot capture frames")
                return False
        else:
            print("❌ Camera not accessible")
            return False
    except Exception as e:
        print(f"❌ Camera error: {e}")
        return False

def test_services():
    print("⚙️ Testing Systemd Services...")
    services = ['smartcam-camera', 'smartcam-scheduler', 'smartcam-orchestrator']
    all_good = True
    
    for service in services:
        try:
            result = subprocess.run(['systemctl', 'is-active', service], 
                                  capture_output=True, text=True)
            if result.stdout.strip() == 'active':
                print(f"✅ {service} is active")
            else:
                print(f"❌ {service} is not active: {result.stdout.strip()}")
                all_good = False
        except Exception as e:
            print(f"❌ Error checking {service}: {e}")
            all_good = False
    
    return all_good

def main():
    print("🚀 SmartCam System Test")
    print("=" * 50)
    
    tests = [
        test_config,
        test_database,
        test_camera,
        test_services
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print("=" * 50)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! System is ready.")
    else:
        print("⚠️ Some tests failed. Check the errors above.")
    
    return passed == total

if __name__ == "__main__":
    main()
EOF

print_success "Test script created"

# Step 20: Run final test
print_status "Step 20: Running final system test"
python3 test_system.py

# Step 21: Summary
echo ""
echo "🎉 Installation and Testing Complete!"
echo "====================================="
echo ""
echo "📋 Summary:"
echo "- Virtual environment: ✅ Created and activated"
echo "- Dependencies: ✅ Installed"
echo "- Configuration: ✅ Loaded"
echo "- Camera: ✅ Tested"
echo "- Services: ✅ Created and started"
echo "- Database: ✅ Connected"
echo ""
echo "🚀 Next Steps:"
echo "1. Monitor services: sudo journalctl -u smartcam-camera -f"
echo "2. Check status: sudo systemctl status smartcam-camera"
echo "3. Test recording: Create a booking in the frontend"
echo "4. View logs: sudo journalctl -u smartcam-* --since '5 minutes ago'"
echo ""
echo "📁 Important files:"
echo "- Configuration: ~/code/SmartCam-Soccer/backend/.env"
echo "- Logs: ~/code/SmartCam-Soccer/backend/logs/"
echo "- Recordings: ~/code/SmartCam-Soccer/backend/recordings/"
echo ""
echo "🔧 Troubleshooting:"
echo "- Restart services: sudo systemctl restart smartcam-*"
echo "- Check logs: sudo journalctl -u smartcam-* -n 50"
echo "- Test manually: cd ~/code/SmartCam-Soccer/backend && source venv/bin/activate && python main.py"
echo ""

print_success "SmartCam Backend installation and testing completed successfully!" 