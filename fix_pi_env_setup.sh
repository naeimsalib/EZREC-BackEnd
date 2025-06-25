#!/bin/bash
# 🔧 EZREC Raspberry Pi Environment Setup Fix
# This script fixes the API key authentication issues

echo "🔧 EZREC Raspberry Pi Environment Setup Fix"
echo "============================================="
echo "Time: $(date)"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Check if base directory exists
if [ ! -d "/opt/ezrec-backend" ]; then
    echo "❌ EZREC backend directory not found at /opt/ezrec-backend"
    echo "   Please install EZREC first"
    exit 1
fi

echo "📝 Creating corrected .env file with proper Supabase keys..."

# Create the corrected .env file
cat > /opt/ezrec-backend/.env << 'EOF'
# EZREC Backend Environment Configuration - CORRECTED
# =============================================================================
# SUPABASE CONFIGURATION (Required) - FIXED KEYS
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
# CAMERA CONFIGURATION
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
# SYSTEM PATHS (For Raspberry Pi deployment)
# =============================================================================
EZREC_BASE_DIR=/opt/ezrec-backend

# =============================================================================
# SYSTEM INTERVALS (seconds) - FIXED: 3-second real-time updates
# =============================================================================
STATUS_UPDATE_INTERVAL=3
BOOKING_CHECK_INTERVAL=5
HEARTBEAT_INTERVAL=3

# =============================================================================
# LOGGING & DEBUG
# =============================================================================
DEBUG=false
LOG_LEVEL=INFO

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================
NETWORK_TIMEOUT=30
UPLOAD_RETRY_COUNT=3
UPLOAD_RETRY_DELAY=60
EOF

echo "✅ .env file created with correct Supabase keys"

# Set proper ownership and permissions
chown ezrec:ezrec /opt/ezrec-backend/.env
chmod 600 /opt/ezrec-backend/.env

echo "🔒 Set proper file permissions"

# Test the environment
echo "🧪 Testing environment setup..."
cd /opt/ezrec-backend

# Test configuration loading
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 -c "
import sys
sys.path.insert(0, '/opt/ezrec-backend/src')
from dotenv import load_dotenv
import os

# Load environment
load_dotenv('/opt/ezrec-backend/.env')

print('📊 Environment Configuration Test:')
print(f'   SUPABASE_URL: {\"SET\" if os.getenv(\"SUPABASE_URL\") else \"NOT SET\"}')
print(f'   SERVICE_ROLE_KEY: {\"SET\" if os.getenv(\"SUPABASE_SERVICE_ROLE_KEY\") else \"NOT SET\"}')
print(f'   ANON_KEY: {\"SET\" if os.getenv(\"SUPABASE_ANON_KEY\") else \"NOT SET\"}')
print(f'   USER_ID: {os.getenv(\"USER_ID\", \"NOT SET\")}')
print(f'   CAMERA_ID: {os.getenv(\"CAMERA_ID\", \"NOT SET\")}')

# Test config import
try:
    from config import USER_ID, CAMERA_ID, SUPABASE_URL
    print('✅ Config module loads successfully')
    print(f'   Configured USER_ID: {USER_ID}')
    print(f'   Configured CAMERA_ID: {CAMERA_ID}')
except Exception as e:
    print(f'❌ Config import failed: {e}')
"

echo

# Test Supabase connection
echo "🌐 Testing Supabase connection..."
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 -c "
import sys
sys.path.insert(0, '/opt/ezrec-backend/src')

try:
    from utils import supabase, logger
    if supabase:
        print('✅ Supabase client initialized successfully')
        
        # Test a simple query
        response = supabase.table('bookings').select('id').limit(1).execute()
        print('✅ Database connection working')
        
        # Test user-specific query
        from config import USER_ID
        response = supabase.table('system_status').select('user_id').eq('user_id', USER_ID).limit(1).execute()
        print('✅ User-specific queries working')
        
    else:
        print('❌ Supabase client not initialized')
except Exception as e:
    print(f'❌ Connection test failed: {e}')
"

echo
echo "🎯 Restarting EZREC service with fixed configuration..."
systemctl restart ezrec-backend

echo "⏰ Waiting 5 seconds for service to start..."
sleep 5

echo "📊 Checking service status:"
systemctl status ezrec-backend --no-pager -l

echo
echo "✅ Environment fix complete!"
echo
echo "🔍 Monitor the service logs:"
echo "sudo journalctl -u ezrec-backend -f"
echo
echo "🧪 Test with the system workflow:"
echo "cd /opt/ezrec-backend"
echo "sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 test_full_system_workflow.py"
echo
echo "📋 Create a test booking:"
echo "sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 /opt/ezrec-backend/create_simple_test_booking.py" 