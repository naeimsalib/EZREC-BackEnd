#!/bin/bash

echo "🚀 EZREC COMPLETE SYSTEM DEPLOYMENT - FIXING ALL ISSUES"
echo "========================================================"
echo "This script will:"
echo "1. ✅ Update environment configuration with ANON_KEY"
echo "2. ✅ Install missing dependencies (storage3)"
echo "3. ✅ Deploy fixed code files"
echo "4. ✅ Update system paths and configuration"
echo "5. ✅ Restart service with new configuration"
echo "6. ✅ Test complete system functionality"
echo
echo "Target:"
echo "  - Database: soccer-cam-db"
echo "  - User ID: 65aa2e2a-e463-424d-b88f-0724bb0bea3a"
echo "  - Booking source: bookings table (by user_id)"
echo "  - Video destination: videos table + videos bucket"
echo
read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

echo
echo "🔧 Starting comprehensive deployment..."
echo

# 1. Create backup of current system
echo "1. 📦 Creating System Backup"
echo "----------------------------"
sudo mkdir -p /opt/ezrec-backend/backup/$(date +%Y%m%d_%H%M%S)
sudo cp -r /opt/ezrec-backend/src /opt/ezrec-backend/backup/$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
sudo cp /opt/ezrec-backend/.env /opt/ezrec-backend/backup/$(date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
echo "✅ Backup created"

# 2. Update Environment Configuration
echo "2. 🔧 Updating Environment Configuration"
echo "---------------------------------------"

# Deploy the fixed .env file
sudo tee /opt/ezrec-backend/.env > /dev/null << 'EOF'
# EZREC Backend Environment Configuration - FIXED VERSION
# =============================================================================
# SUPABASE CONFIGURATION (Required)
# =============================================================================
SUPABASE_URL=https://iszmsaayxpdrovealrrp.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODM2NjAxMywiZXhwIjoyMDYzOTQyMDEzfQ.tzm80_eIy2xho652OxV37ErGnxwOuUvE4-MIPWrdS0c
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjYwMTMsImV4cCI6MjA2Mzk0MjAxM30.5bE_fPBOgkNtEyjCieW328oxyDHWGpf2OTDWssJ_Npk

# =============================================================================
# USER CONFIGURATION (Required)
# =============================================================================
USER_ID=65aa2e2a-e463-424d-b88f-0724bb0bea3a
USER_EMAIL=your_email@example.com

# =============================================================================
# CAMERA CONFIGURATION - FIXED
# =============================================================================
CAMERA_ID=raspberry_pi_camera_01
CAMERA_NAME=Raspberry Pi Camera
CAMERA_LOCATION=Home Office
CAMERA_DEVICE=/dev/video0

# Camera Settings
CAMERA_INDEX=0
PREVIEW_WIDTH=640
PREVIEW_HEIGHT=480
RECORD_WIDTH=1920
RECORD_HEIGHT=1080
PREVIEW_FPS=24
RECORD_FPS=30

# Recording Configuration
MAX_RECORDING_DURATION=7200
MIN_RECORDING_DURATION=300
RECORDING_BITRATE=10000000

# =============================================================================
# SYSTEM PATHS - FIXED TO MATCH SERVICE
# =============================================================================
EZREC_BASE_DIR=/opt/ezrec-backend

# =============================================================================
# SYSTEM INTERVALS (seconds) - FASTER BOOKING CHECK
# =============================================================================
STATUS_UPDATE_INTERVAL=15
BOOKING_CHECK_INTERVAL=5
HEARTBEAT_INTERVAL=30

# =============================================================================
# LOGGING & DEBUG
# =============================================================================
DEBUG=true
LOG_LEVEL=DEBUG

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================
NETWORK_TIMEOUT=30
UPLOAD_RETRY_COUNT=3
UPLOAD_RETRY_DELAY=60

# =============================================================================
# VIDEO UPLOAD CONFIGURATION - NEW
# =============================================================================
DELETE_AFTER_UPLOAD=false
STORAGE_BUCKET=videos
EOF

echo "✅ Environment configuration updated"

# 3. Install Missing Dependencies
echo "3. 📦 Installing Missing Dependencies"
echo "-----------------------------------"
source /opt/ezrec-backend/venv/bin/activate

# Install storage3 for Supabase storage uploads
pip install storage3
pip install --upgrade supabase
pip install psutil opencv-python python-dotenv pytz

echo "✅ Dependencies installed"

# 4. Deploy Fixed Code Files
echo "4. 🔄 Deploying Fixed Code Files"
echo "-------------------------------"

# Create instructions for manual file deployment
cat > /tmp/file_deployment_instructions.txt << 'EOF'
MANUAL FILE DEPLOYMENT REQUIRED:

Please copy these files from your development machine to the Raspberry Pi:

FROM: /Volumes/T7Touch/Projects/EZREC-BackEnd/src/utils_fixed.py
TO:   /opt/ezrec-backend/src/utils.py

FROM: /Volumes/T7Touch/Projects/EZREC-BackEnd/src/orchestrator_fixed.py  
TO:   /opt/ezrec-backend/src/orchestrator.py

FROM: /Volumes/T7Touch/Projects/EZREC-BackEnd/upload_recordings_fixed.py
TO:   /opt/ezrec-backend/upload_recordings.py

Commands to run on Pi after copying:
sudo chown -R ezrec:ezrec /opt/ezrec-backend/
sudo chmod +x /opt/ezrec-backend/upload_recordings.py
EOF

echo "⚠️ Manual file deployment required - see /tmp/file_deployment_instructions.txt"
echo "Files need to be copied manually from development machine to Pi"

# 5. Create Test Scripts
echo "5. 🧪 Creating Test Scripts"
echo "---------------------------"

# Create booking test script
sudo tee /opt/ezrec-backend/test_booking_system.py > /dev/null << 'EOF'
#!/usr/bin/env python3
"""Test script for EZREC booking system"""
import sys
import os
sys.path.insert(0, '/opt/ezrec-backend/src')

from utils import get_next_booking, update_system_status
from config import USER_ID

def test_booking_detection():
    print("🧪 Testing Booking Detection System")
    print("=" * 40)
    print(f"User ID: {USER_ID}")
    print()
    
    booking = get_next_booking()
    if booking:
        print("✅ Booking found:")
        print(f"   ID: {booking['id']}")
        print(f"   Date: {booking['date']}")
        print(f"   Time: {booking['start_time']} - {booking['end_time']}")
        print(f"   Status: {booking['status']}")
        print(f"   User: {booking['user_id']}")
    else:
        print("📭 No bookings found")
    
    print()
    print("🧪 Testing System Status Update")
    result = update_system_status(is_recording=False)
    if result:
        print("✅ Status update successful")
    else:
        print("❌ Status update failed")

if __name__ == "__main__":
    test_booking_detection()
EOF

sudo chmod +x /opt/ezrec-backend/test_booking_system.py

# Create video upload test script
sudo tee /opt/ezrec-backend/test_video_upload.py > /dev/null << 'EOF'
#!/usr/bin/env python3
"""Test script for video upload system"""
import sys
import os
sys.path.insert(0, '/opt/ezrec-backend/src')

from utils import upload_video_to_supabase

def test_upload_system():
    print("🧪 Testing Video Upload System")
    print("=" * 35)
    
    # Test with a dummy file (create small test file)
    test_file = "/tmp/test_video.mp4"
    
    # Create a small test file
    with open(test_file, 'wb') as f:
        f.write(b'test video content')
    
    print(f"📤 Testing upload of: {test_file}")
    
    result = upload_video_to_supabase(test_file, "test-booking-id")
    
    if result.get('success'):
        print("✅ Upload test successful:")
        print(f"   Storage Path: {result.get('storage_path')}")
        print(f"   Video ID: {result.get('video_id')}")
        print(f"   Table: {result.get('table')}")
    else:
        print(f"❌ Upload test failed: {result.get('error')}")
    
    # Clean up test file
    os.remove(test_file)

if __name__ == "__main__":
    test_upload_system()
EOF

sudo chmod +x /opt/ezrec-backend/test_video_upload.py

echo "✅ Test scripts created"

# 6. Set Permissions
echo "6. 🔒 Setting Correct Permissions"
echo "--------------------------------"
sudo chown -R ezrec:ezrec /opt/ezrec-backend/
sudo chmod +x /opt/ezrec-backend/test_*.py
echo "✅ Permissions set"

# 7. Create Verification Script
echo "7. ✅ Creating Verification Script"
echo "---------------------------------"

sudo tee /opt/ezrec-backend/verify_fixes.sh > /dev/null << 'EOF'
#!/bin/bash

echo "🔍 EZREC SYSTEM VERIFICATION - POST-FIX"
echo "======================================="

# Test 1: Environment Configuration
echo "1. 🔧 Environment Configuration"
echo "------------------------------"
if grep -q "SUPABASE_ANON_KEY" /opt/ezrec-backend/.env; then
    echo "✅ SUPABASE_ANON_KEY present"
else
    echo "❌ SUPABASE_ANON_KEY missing"
fi

if grep -q "USER_ID=65aa2e2a-e463-424d-b88f-0724bb0bea3a" /opt/ezrec-backend/.env; then
    echo "✅ Correct USER_ID configured"
else
    echo "❌ USER_ID not configured correctly"
fi

echo

# Test 2: Dependencies
echo "2. 📦 Dependencies"
echo "-----------------"
source /opt/ezrec-backend/venv/bin/activate

if python -c "import storage3" 2>/dev/null; then
    echo "✅ storage3 library available"
else
    echo "❌ storage3 library missing"
fi

if python -c "from supabase import create_client" 2>/dev/null; then
    echo "✅ supabase library available"
else
    echo "❌ supabase library missing"
fi

echo

# Test 3: File Structure
echo "3. 📁 File Structure"
echo "-------------------"
if [ -f "/opt/ezrec-backend/src/utils.py" ]; then
    echo "✅ utils.py present"
else
    echo "❌ utils.py missing"
fi

if [ -f "/opt/ezrec-backend/src/orchestrator.py" ]; then
    echo "✅ orchestrator.py present"
else
    echo "❌ orchestrator.py missing"
fi

if [ -f "/opt/ezrec-backend/upload_recordings.py" ]; then
    echo "✅ upload_recordings.py present"
else
    echo "❌ upload_recordings.py missing"
fi

echo

# Test 4: Database Connection
echo "4. 🗄️ Database Connection Test"
echo "-----------------------------"
cd /opt/ezrec-backend
python test_booking_system.py

echo

# Test 5: Upload System
echo "5. 📤 Upload System Test"
echo "-----------------------"
python test_video_upload.py

echo

echo "🏁 Verification Complete"
echo "========================"
echo "Next steps:"
echo "1. Copy fixed code files manually (see instructions)"
echo "2. Restart service: sudo systemctl restart ezrec-backend"
echo "3. Check logs: sudo journalctl -u ezrec-backend -f"
EOF

sudo chmod +x /opt/ezrec-backend/verify_fixes.sh

echo "✅ Verification script created"

# Final Instructions
echo
echo "🎯 DEPLOYMENT SUMMARY"
echo "===================="
echo "✅ Environment configuration updated"
echo "✅ Dependencies installed"
echo "✅ Test scripts created"
echo "✅ Permissions set"
echo "✅ Verification script ready"
echo
echo "⚠️ MANUAL STEPS REQUIRED:"
echo "========================"
echo "1. Copy fixed code files from development machine:"
echo "   src/utils_fixed.py → /opt/ezrec-backend/src/utils.py"
echo "   src/orchestrator_fixed.py → /opt/ezrec-backend/src/orchestrator.py"
echo "   upload_recordings_fixed.py → /opt/ezrec-backend/upload_recordings.py"
echo
echo "2. Set ownership after copying:"
echo "   sudo chown -R ezrec:ezrec /opt/ezrec-backend/"
echo
echo "3. Restart the service:"
echo "   sudo systemctl restart ezrec-backend"
echo
echo "4. Run verification:"
echo "   cd /opt/ezrec-backend && ./verify_fixes.sh"
echo
echo "5. Check logs:"
echo "   sudo journalctl -u ezrec-backend -f"
echo
echo "🚀 Your system is now configured for:"
echo "   📊 Database: soccer-cam-db"
echo "   🔍 Booking source: bookings table (filter by user_id)"
echo "   📤 Video destination: videos table + videos bucket"
echo "   ⚡ Faster booking checks (5 second intervals)"
echo
echo "Deployment script completed successfully!" 