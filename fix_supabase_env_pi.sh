#!/bin/bash
# EZREC Supabase Environment Fix for Raspberry Pi
# This script sets up the proper .env file with all required variables

echo "🔧 EZREC Supabase Environment Setup for Raspberry Pi"
echo "===================================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ Don't run this script as root. Run as regular user (michomanoly14892)"
   exit 1
fi

# Set the target directory
EZREC_DIR="/opt/ezrec-backend"

echo "📍 Target directory: $EZREC_DIR"
echo "👤 Current user: $(whoami)"

# Check if directory exists
if [ ! -d "$EZREC_DIR" ]; then
    echo "❌ EZREC directory not found: $EZREC_DIR"
    echo "Please ensure EZREC is installed first"
    exit 1
fi

# Check if .env already exists
if [ -f "$EZREC_DIR/.env" ]; then
    echo "⚠️ .env file already exists. Creating backup..."
    sudo cp "$EZREC_DIR/.env" "$EZREC_DIR/.env.backup.$(date +%s)"
    echo "✅ Backup created"
fi

echo ""
echo "🔑 Please provide your Supabase credentials:"
echo "You can find these in your Supabase Dashboard > Settings > API"
echo ""

# Get Supabase URL
read -p "📌 Enter your SUPABASE_URL (e.g., https://xxx.supabase.co): " SUPABASE_URL
if [ -z "$SUPABASE_URL" ]; then
    echo "❌ SUPABASE_URL is required"
    exit 1
fi

# Get Service Role Key
read -s -p "🔐 Enter your SUPABASE_SERVICE_ROLE_KEY: " SUPABASE_SERVICE_KEY
echo ""
if [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo "❌ SUPABASE_SERVICE_ROLE_KEY is required"
    exit 1
fi

# Get Anon Key
read -s -p "🔓 Enter your SUPABASE_ANON_KEY: " SUPABASE_ANON_KEY
echo ""
if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "❌ SUPABASE_ANON_KEY is required"
    exit 1
fi

# Get User ID
read -p "👤 Enter your USER_ID: " USER_ID
if [ -z "$USER_ID" ]; then
    USER_ID="65aa2e2a-e463-424d-b88f-0724bb0bea3a"
    echo "Using default USER_ID: $USER_ID"
fi

# Create the .env file
echo "📝 Creating .env file..."

sudo tee "$EZREC_DIR/.env" > /dev/null << EOF
# EZREC Backend Environment Configuration
# Generated on: $(date)

# Supabase Configuration (Required)
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_KEY
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# User Configuration
USER_ID=$USER_ID
USER_EMAIL=user@example.com

# Camera Configuration
CAMERA_ID=raspberry_pi_camera_01
CAMERA_NAME=Raspberry Pi Camera
CAMERA_LOCATION=Living Room

# EZREC Configuration
EZREC_BASE_DIR=/opt/ezrec-backend

# System Configuration - FIXED: 3-second intervals
STATUS_UPDATE_INTERVAL=3
BOOKING_CHECK_INTERVAL=5
HEARTBEAT_INTERVAL=3

# Recording Configuration
MAX_RECORDING_DURATION=7200
RECORDING_BITRATE=10000000
RECORD_WIDTH=1920
RECORD_HEIGHT=1080
RECORD_FPS=30

# Video Upload Configuration - FIXED
DELETE_AFTER_UPLOAD=true

# Debug Configuration
DEBUG=false
LOG_LEVEL=INFO
EOF

# Set proper permissions
sudo chown ezrec:ezrec "$EZREC_DIR/.env"
sudo chmod 600 "$EZREC_DIR/.env"

echo "✅ .env file created successfully!"

# Test the configuration
echo ""
echo "🧪 Testing Supabase connection..."

# Create test script
cat > /tmp/test_supabase.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/opt/ezrec-backend/src')

# Load environment
from dotenv import load_dotenv
load_dotenv('/opt/ezrec-backend/.env')

print(f"🔍 Environment Variables:")
print(f"SUPABASE_URL: {'SET' if os.getenv('SUPABASE_URL') else 'NOT SET'}")
print(f"SUPABASE_SERVICE_ROLE_KEY: {'SET' if os.getenv('SUPABASE_SERVICE_ROLE_KEY') else 'NOT SET'}")
print(f"SUPABASE_ANON_KEY: {'SET' if os.getenv('SUPABASE_ANON_KEY') else 'NOT SET'}")
print(f"USER_ID: {os.getenv('USER_ID', 'NOT SET')}")

try:
    # Test Supabase connection
    from supabase import create_client
    
    supabase_url = os.getenv('SUPABASE_URL')
    supabase_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
    
    client = create_client(supabase_url, supabase_key)
    
    # Test database query
    response = client.table("bookings").select("id").limit(1).execute()
    
    print("✅ Supabase connection successful!")
    print(f"📊 Database accessible")
    
    # Test booking query for user
    user_id = os.getenv('USER_ID')
    user_bookings = client.table("bookings").select("*").eq("user_id", user_id).execute()
    print(f"📋 Found {len(user_bookings.data)} bookings for user")
    
except Exception as e:
    print(f"❌ Supabase connection failed: {e}")
    sys.exit(1)
EOF

# Run test
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 /tmp/test_supabase.py

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Configuration successful! Now restart the EZREC service:"
    echo "sudo systemctl restart ezrec-backend"
    echo ""
    echo "📱 Test booking creation:"
    echo "cd ~/code/EZREC-BackEnd"
    echo "python3 create_simple_test_booking.py"
else
    echo ""
    echo "❌ Configuration test failed. Please check your credentials and try again."
    exit 1
fi

# Cleanup
rm -f /tmp/test_supabase.py

echo ""
echo "✅ Supabase environment setup complete!" 