#!/bin/bash
# EZREC Environment Setup Script
# Run this on your Raspberry Pi to create the .env file

echo "Creating .env file for EZREC Backend..."

cat > .env << 'ENVEOF'
# EZREC Backend Environment Configuration
# =============================================================================
# SUPABASE CONFIGURATION (Required)
# =============================================================================
# Get these from your Supabase project dashboard: https://supabase.com/dashboard
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# =============================================================================
# USER CONFIGURATION (Required)
# =============================================================================
# Your unique user ID from your Supabase auth.users table
USER_ID=your_user_uuid_here
USER_EMAIL=your_email@example.com

# =============================================================================
# CAMERA CONFIGURATION
# =============================================================================
CAMERA_ID=raspberry_pi_camera_01
CAMERA_NAME=Raspberry Pi Camera
CAMERA_LOCATION=Home Office
CAMERA_DEVICE=/dev/video0

# Camera Settings - Optimized for Pi Camera
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

# Hardware Encoder for Pi
HARDWARE_ENCODER=h264_omx

# =============================================================================
# SYSTEM PATHS
# =============================================================================
# For Raspberry Pi deployment (production)
EZREC_BASE_DIR=/opt/ezrec-backend

# =============================================================================
# SYSTEM INTERVALS (seconds)
# =============================================================================
STATUS_UPDATE_INTERVAL=15
BOOKING_CHECK_INTERVAL=60
HEARTBEAT_INTERVAL=30

# =============================================================================
# LOGGING & DEBUG
# =============================================================================
DEBUG=false
LOG_LEVEL=INFO
LOG_MAX_BYTES=10485760
LOG_BACKUP_COUNT=5

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================
NETWORK_TIMEOUT=30
UPLOAD_RETRY_COUNT=3
UPLOAD_RETRY_DELAY=60
ENVEOF

echo "✅ .env file created successfully!"
echo ""
echo "🔧 NEXT STEPS:"
echo "1. Edit the .env file and add your actual Supabase credentials:"
echo "   nano .env"
echo ""
echo "2. Update these required fields:"
echo "   - SUPABASE_URL (from your Supabase dashboard)"
echo "   - SUPABASE_SERVICE_ROLE_KEY (from your Supabase dashboard)"
echo "   - USER_ID (your user UUID from Supabase)"
echo "   - USER_EMAIL (your email address)"
echo ""
echo "3. Your Supabase dashboard URL: https://supabase.com/dashboard"

