#!/bin/bash

# EZREC Backend Environment Setup Script for Raspberry Pi
# This script creates the necessary .env file with all required configuration

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                 EZREC Environment Configuration                ║"
echo "║                      Raspberry Pi Setup                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo

# Check if running on Pi
if [ ! -f /opt/ezrec-backend/.env ]; then
    echo "Creating environment configuration file..."
    
    # Create the .env file with comprehensive settings
    sudo tee /opt/ezrec-backend/.env > /dev/null << 'EOF'
# EZREC Backend Configuration for Raspberry Pi
# Generated automatically - Edit as needed

# ============================================================================
# REQUIRED: Supabase Configuration
# ============================================================================
# Get these from your Supabase project dashboard: https://supabase.com/dashboard
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# Alternative key name (some versions use this)
SUPABASE_SERVICE_KEY=your_service_role_key_here

# ============================================================================
# REQUIRED: User Configuration
# ============================================================================
# Your unique user ID from the EZREC dashboard
USER_ID=your_user_id_here

# Your email address
USER_EMAIL=your_email@example.com

# ============================================================================
# Camera Configuration
# ============================================================================
# Unique identifier for this camera/Pi
CAMERA_ID=raspberry_pi_camera_01

# Human-readable camera name
CAMERA_NAME=Soccer Field Camera 1

# Physical location description
CAMERA_LOCATION=Soccer Field Main

# Camera device (usually auto-detected)
CAMERA_DEVICE=/dev/video0

# ============================================================================
# Recording Settings (Optimized for Pi Camera)
# ============================================================================
# Recording resolution (1920x1080 for Full HD)
RECORD_WIDTH=1920
RECORD_HEIGHT=1080

# Recording frame rate (30fps recommended)
RECORD_FPS=30

# Preview resolution (lower for performance)
PREVIEW_WIDTH=640
PREVIEW_HEIGHT=480
PREVIEW_FPS=24

# Recording bitrate (10Mbps for good quality)
RECORDING_BITRATE=10000000

# Hardware encoder for Pi
HARDWARE_ENCODER=h264_omx

# ============================================================================
# System Configuration
# ============================================================================
# Base installation directory
EZREC_BASE_DIR=/opt/ezrec-backend

# Debug mode (set to true for troubleshooting)
DEBUG=false

# Logging level (DEBUG, INFO, WARNING, ERROR)
LOG_LEVEL=INFO

# Log file rotation settings
LOG_MAX_BYTES=10485760
LOG_BACKUP_COUNT=5

# ============================================================================
# Performance & Timing Settings
# ============================================================================
# How often to check for new bookings (seconds)
BOOKING_CHECK_INTERVAL=60

# How often to update system status (seconds)
STATUS_UPDATE_INTERVAL=15

# Heartbeat interval for monitoring (seconds)
HEARTBEAT_INTERVAL=30

# Network timeout for API calls (seconds)
NETWORK_TIMEOUT=30

# Upload retry settings
UPLOAD_RETRY_COUNT=3
UPLOAD_RETRY_DELAY=60

# ============================================================================
# Recording Duration Limits
# ============================================================================
# Maximum recording duration (2 hours = 7200 seconds)
MAX_RECORDING_DURATION=7200

# Minimum recording duration (5 minutes = 300 seconds)
MIN_RECORDING_DURATION=300

EOF

    # Set proper ownership and permissions
    sudo chown ezrec:ezrec /opt/ezrec-backend/.env
    sudo chmod 600 /opt/ezrec-backend/.env
    
    echo "✓ Environment file created at /opt/ezrec-backend/.env"
    echo
else
    echo "Environment file already exists at /opt/ezrec-backend/.env"
    echo
fi

echo "════════════════════════════════════════════════════════════════"
echo "IMPORTANT: You must edit the environment file with your settings!"
echo "════════════════════════════════════════════════════════════════"
echo
echo "Required steps:"
echo "1. Edit the configuration file:"
echo "   sudo nano /opt/ezrec-backend/.env"
echo
echo "2. Update these REQUIRED fields:"
echo "   - SUPABASE_URL (from your Supabase dashboard)"
echo "   - SUPABASE_SERVICE_ROLE_KEY (from your Supabase dashboard)"
echo "   - USER_ID (your unique user ID)"
echo "   - USER_EMAIL (your email address)"
echo
echo "3. Restart the service:"
echo "   sudo systemctl restart ezrec-backend"
echo
echo "4. Check the status:"
echo "   sudo systemctl status ezrec-backend"
echo
echo "5. View live logs:"
echo "   sudo journalctl -u ezrec-backend -f"
echo
echo "════════════════════════════════════════════════════════════════" 