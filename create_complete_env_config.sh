#!/bin/bash
# 🎬 EZREC Complete Environment Configuration Script
# Creates .env files with actual Supabase credentials and user information
# For both main app directory and deployment directory

echo "🎬 EZREC Complete Environment Configuration"
echo "==========================================="
echo "🕐 Time: $(date)"
echo "👤 User: michomanoly@gmail.com"
echo "🆔 User ID: 65aa2e2a-e463-424d-b88f-0724bb0bea3a"
echo

# Check if running as root for deployment directory
if [[ $EUID -eq 0 ]]; then
    CURRENT_USER_HOME="/home/$SUDO_USER"
    echo "🔐 Running as root - will create files for both directories"
else
    CURRENT_USER_HOME="$HOME"
    echo "👤 Running as user - will create files where possible"
fi

MAIN_APP_DIR="$CURRENT_USER_HOME/code/EZREC-BackEnd"
DEPLOY_DIR="/opt/ezrec-backend"

echo "📁 Main App Directory: $MAIN_APP_DIR"
echo "🎯 Deploy Directory: $DEPLOY_DIR"
echo

# Create the complete .env configuration
ENV_CONTENT='# EZREC Environment Configuration
# Generated: 2025-01-27 for soccer-cam-db project
# User: michomanoly@gmail.com

# Supabase Configuration - ACTUAL CREDENTIALS
SUPABASE_URL=https://iszmsaayxpdrovealrrp.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjYwMTMsImV4cCI6MjA2Mzk0MjAxM30.5bE_fPBOgkNtEyjCieW328oxyDHWGpf2OTDWssJ_Npk
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjYwMTMsImV4cCI6MjA2Mzk0MjAxM30.5bE_fPBOgkNtEyjCieW328oxyDHWGpf2OTDWssJ_Npk

# Project Information
PROJECT_ID=iszmsaayxpdrovealrrp
PROJECT_NAME=soccer-cam-db
PROJECT_REGION=us-east-2
DATABASE_HOST=db.iszmsaayxpdrovealrrp.supabase.co

# User Configuration - ACTUAL USER INFO
USER_ID=65aa2e2a-e463-424d-b88f-0724bb0bea3a
USER_EMAIL=michomanoly@gmail.com
DEFAULT_USER_ID=65aa2e2a-e463-424d-b88f-0724bb0bea3a

# System Configuration
RECORDING_DIR=/opt/ezrec-backend/recordings
TEMP_DIR=/opt/ezrec-backend/temp
LOG_DIR=/opt/ezrec-backend/logs

# Camera Configuration
CAMERA_ID=pi_camera_1
RECORD_WIDTH=1920
RECORD_HEIGHT=1080
RECORD_FPS=30
RECORDING_BITRATE=10000000

# Pi-specific settings
PI_CAMERA_ENABLED=true
GPU_MEMORY=128
CAMERA_ROTATION=0
CAMERA_HFLIP=false
CAMERA_VFLIP=false

# Upload settings
DELETE_AFTER_UPLOAD=true
UPLOAD_TIMEOUT=300

# Status update interval (3 seconds as requested)
STATUS_UPDATE_INTERVAL=3
HEARTBEAT_INTERVAL=10

# Debug settings
DEBUG=false
LOG_LEVEL=INFO

# Booking management
BOOKING_CHECK_INTERVAL=5
MAX_RECORDING_DURATION=7200

# Storage settings
STORAGE_BUCKET=videos
MAX_LOCAL_STORAGE_GB=10

# System monitoring
ENABLE_SYSTEM_MONITORING=true
CPU_TEMP_WARNING_THRESHOLD=70
MEMORY_WARNING_THRESHOLD=85

# Network settings
NETWORK_TIMEOUT=30
MAX_RETRY_ATTEMPTS=3
RETRY_DELAY=5

# Recording settings
ENABLE_MOTION_DETECTION=false
RECORDING_QUALITY=high
AUTO_ADJUST_QUALITY=true

# Notification settings
ENABLE_EMAIL_NOTIFICATIONS=false
NOTIFICATION_EMAIL=michomanoly@gmail.com

# Development settings
DEVELOPMENT_MODE=false
ENABLE_DEBUG_LOGGING=true'

echo "📝 STEP 1: Creating .env for Main App Directory"
echo "==============================================="

if [ -d "$MAIN_APP_DIR" ]; then
    echo "$ENV_CONTENT" > "$MAIN_APP_DIR/.env"
    
    # Add development-specific settings for main app
    echo "" >> "$MAIN_APP_DIR/.env"
    echo "# Development-specific settings" >> "$MAIN_APP_DIR/.env"
    echo "DEVELOPMENT_MODE=true" >> "$MAIN_APP_DIR/.env"
    echo "RECORDING_DIR=$MAIN_APP_DIR/recordings" >> "$MAIN_APP_DIR/.env"
    echo "TEMP_DIR=$MAIN_APP_DIR/temp" >> "$MAIN_APP_DIR/.env"
    echo "LOG_DIR=$MAIN_APP_DIR/logs" >> "$MAIN_APP_DIR/.env"
    
    # Set ownership for main app directory
    if [[ $EUID -eq 0 ]] && [ "$SUDO_USER" ]; then
        chown "$SUDO_USER:$SUDO_USER" "$MAIN_APP_DIR/.env"
        chmod 600 "$MAIN_APP_DIR/.env"
    else
        chmod 600 "$MAIN_APP_DIR/.env"
    fi
    
    echo "✅ Created: $MAIN_APP_DIR/.env"
    
    # Create directories for main app
    mkdir -p "$MAIN_APP_DIR"/{recordings,temp,logs}
    if [[ $EUID -eq 0 ]] && [ "$SUDO_USER" ]; then
        chown -R "$SUDO_USER:$SUDO_USER" "$MAIN_APP_DIR"/{recordings,temp,logs}
    fi
    
else
    echo "⚠️  Main app directory not found: $MAIN_APP_DIR"
fi

echo
echo "📝 STEP 2: Creating .env for Deployment Directory"
echo "=================================================="

if [[ $EUID -eq 0 ]]; then
    # Create deployment directory if it doesn't exist
    mkdir -p "$DEPLOY_DIR"
    
    echo "$ENV_CONTENT" > "$DEPLOY_DIR/.env"
    
    # Set ownership and permissions for deployment
    chown ezrec:ezrec "$DEPLOY_DIR/.env" 2>/dev/null || echo "⚠️  ezrec user not found - will set later"
    chmod 600 "$DEPLOY_DIR/.env"
    
    echo "✅ Created: $DEPLOY_DIR/.env"
    
    # Create deployment directories
    mkdir -p "$DEPLOY_DIR"/{recordings,temp,logs}
    chown -R ezrec:ezrec "$DEPLOY_DIR"/{recordings,temp,logs} 2>/dev/null || echo "⚠️  ezrec user not found - will set later"
    
else
    echo "⚠️  Need root access to create deployment .env file"
    echo "Run this script with sudo to create deployment configuration"
fi

echo
echo "📝 STEP 3: Creating Test Booking Script with User Info"
echo "======================================================="

# Create updated test booking script with actual user info
TEST_BOOKING_SCRIPT='#!/usr/bin/env python3
"""
🎬 EZREC Simple Test Booking Creator with Actual User Info
Creates a test booking for user: michomanoly@gmail.com
"""

import os
import sys
import asyncio
from datetime import datetime, timedelta

# Add project root to path
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, project_root)

try:
    from src.utils import SupabaseManager
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)

async def create_test_booking():
    """Create a test booking with actual user information"""
    print("🎬 EZREC Test Booking Creator")
    print("============================")
    print("👤 User: michomanoly@gmail.com")
    print("🆔 User ID: 65aa2e2a-e463-424d-b88f-0724bb0bea3a")
    print()
    
    db = SupabaseManager()
    
    # Create test booking starting in 30 seconds
    start_time = datetime.now() + timedelta(seconds=30)
    end_time = start_time + timedelta(minutes=2)  # 2-minute test recording
    
    booking_data = {
        "user_id": "65aa2e2a-e463-424d-b88f-0724bb0bea3a",
        "camera_id": "pi_camera_1",
        "title": "Test Recording - Pi Camera",
        "description": "Test booking for EZREC system validation",
        "date": start_time.strftime("%Y-%m-%d"),
        "start_time": start_time.strftime("%H:%M:%S"),
        "end_time": end_time.strftime("%H:%M:%S"),
        "status": "scheduled",
        "created_at": datetime.now().isoformat()
    }
    
    print(f"📅 Creating test booking:")
    print(f"   🗓️  Date: {booking_data[\"date\"]}")
    print(f"   ⏰ Start: {booking_data[\"start_time\"]} (in 30 seconds)")
    print(f"   ⏹️  End: {booking_data[\"end_time\"]}")
    print(f"   📹 Camera: {booking_data[\"camera_id\"]}")
    print(f"   👤 User: {booking_data[\"user_id\"]}")
    
    try:
        result = await db.create_record("bookings", booking_data)
        
        if result["success"]:
            booking_id = result["data"]["id"]
            print(f"✅ Test booking created successfully!")
            print(f"📋 Booking ID: {booking_id}")
            print()
            print("🎬 NEXT STEPS:")
            print("1. Monitor the EZREC service logs:")
            print("   sudo journalctl -u ezrec-backend -f")
            print()
            print("2. The system should:")
            print("   - Detect the booking in ~30 seconds")
            print("   - Start recording automatically")
            print("   - Record for 2 minutes")
            print("   - Stop and upload to Supabase")
            print("   - Clean up local files")
            print()
            return True
        else:
            print(f"❌ Failed to create booking: {result[\"error\"]}")
            return False
            
    except Exception as e:
        print(f"❌ Error creating test booking: {e}")
        return False

if __name__ == "__main__":
    success = asyncio.run(create_test_booking())
    if success:
        print("🎉 Test booking created successfully!")
        print("📱 Monitor the system to see it in action!")
    else:
        print("❌ Test booking creation failed")
        sys.exit(1)
'

# Create test booking script in both locations
if [ -d "$MAIN_APP_DIR" ]; then
    echo "$TEST_BOOKING_SCRIPT" > "$MAIN_APP_DIR/create_test_booking_with_user.py"
    chmod +x "$MAIN_APP_DIR/create_test_booking_with_user.py"
    
    if [[ $EUID -eq 0 ]] && [ "$SUDO_USER" ]; then
        chown "$SUDO_USER:$SUDO_USER" "$MAIN_APP_DIR/create_test_booking_with_user.py"
    fi
    
    echo "✅ Created: $MAIN_APP_DIR/create_test_booking_with_user.py"
fi

if [[ $EUID -eq 0 ]] && [ -d "$DEPLOY_DIR" ]; then
    echo "$TEST_BOOKING_SCRIPT" > "$DEPLOY_DIR/create_test_booking_with_user.py"
    chmod +x "$DEPLOY_DIR/create_test_booking_with_user.py"
    chown ezrec:ezrec "$DEPLOY_DIR/create_test_booking_with_user.py" 2>/dev/null || true
    
    echo "✅ Created: $DEPLOY_DIR/create_test_booking_with_user.py"
fi

echo
echo "🎉 CONFIGURATION COMPLETE!"
echo "=========================="
echo "✅ Environment files created with:"
echo "   📧 User Email: michomanoly@gmail.com"
echo "   🆔 User ID: 65aa2e2a-e463-424d-b88f-0724bb0bea3a"
echo "   🔗 Supabase URL: https://iszmsaayxpdrovealrrp.supabase.co"
echo "   🗂️  Project: soccer-cam-db"
echo
echo "📁 Files created:"
if [ -f "$MAIN_APP_DIR/.env" ]; then
    echo "   ✅ $MAIN_APP_DIR/.env"
fi
if [ -f "$DEPLOY_DIR/.env" ]; then
    echo "   ✅ $DEPLOY_DIR/.env"
fi
if [ -f "$MAIN_APP_DIR/create_test_booking_with_user.py" ]; then
    echo "   ✅ $MAIN_APP_DIR/create_test_booking_with_user.py"
fi
if [ -f "$DEPLOY_DIR/create_test_booking_with_user.py" ]; then
    echo "   ✅ $DEPLOY_DIR/create_test_booking_with_user.py"
fi
echo
echo "🚀 READY TO CONTINUE WITH EZREC DEPLOYMENT!"
echo "Next: Start the EZREC service and run tests" 