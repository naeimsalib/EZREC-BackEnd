#!/bin/bash

echo "🔧 EZREC COMPLETE SYSTEM FIX"
echo "============================"
echo "Fixing all database connections, video uploads, and configuration issues..."
echo

# 1. Fix Environment Configuration
echo "1. 🔧 Fixing Environment Configuration"
echo "-------------------------------------"

# Get the anon key from Supabase (you provided earlier)
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjYwMTMsImV4cCI6MjA2Mzk0MjAxM30.5bE_fPBOgkNtEyjCieW328oxyDHWGpf2OTDWssJ_Npk"

# Create the fixed .env file for Pi
cat > .env.pi.fixed << 'EOF'
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
# SYSTEM INTERVALS (seconds)
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

echo "✅ Created fixed .env configuration"

# 2. Install missing dependencies
echo "2. 📦 Installing Missing Dependencies"
echo "-----------------------------------"
cat > install_dependencies.sh << 'EOF'
#!/bin/bash
echo "Installing missing Python dependencies..."

# Activate virtual environment
source /opt/ezrec-backend/venv/bin/activate

# Install storage3 for Supabase storage uploads
pip install storage3

# Install any other missing dependencies
pip install --upgrade supabase
pip install psutil opencv-python python-dotenv pytz

echo "✅ Dependencies installed"
EOF

chmod +x install_dependencies.sh
echo "✅ Created dependency installation script"

echo "Script created! Copy this to your Pi and run it."
echo
echo "INSTRUCTIONS FOR RASPBERRY PI:"
echo "=============================="
echo "1. Copy .env.pi.fixed to your Pi as .env in /opt/ezrec-backend/"
echo "2. Run: chmod +x install_dependencies.sh && ./install_dependencies.sh"
echo "3. Restart the service: sudo systemctl restart ezrec-backend"
echo "4. Check logs: sudo journalctl -u ezrec-backend -f" 