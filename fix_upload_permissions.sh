#!/bin/bash
# Fix EZREC Upload Script Permissions Issue

echo "🔧 EZREC Upload Permissions Fix"
echo "================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Create the upload script directory structure with proper ownership
echo "📁 Creating directory structure..."
mkdir -p /opt/ezrec-backend/temp
mkdir -p /opt/ezrec-backend/recordings
mkdir -p /opt/ezrec-backend/uploads
mkdir -p /opt/ezrec-backend/logs
mkdir -p /opt/ezrec-backend/user_assets

# Set proper ownership for all directories
echo "👤 Setting directory ownership to ezrec user..."
chown -R ezrec:ezrec /opt/ezrec-backend/temp
chown -R ezrec:ezrec /opt/ezrec-backend/recordings
chown -R ezrec:ezrec /opt/ezrec-backend/uploads
chown -R ezrec:ezrec /opt/ezrec-backend/logs
chown -R ezrec:ezrec /opt/ezrec-backend/user_assets

# Set proper permissions
echo "🔒 Setting directory permissions..."
chmod 755 /opt/ezrec-backend/temp
chmod 755 /opt/ezrec-backend/recordings
chmod 755 /opt/ezrec-backend/uploads
chmod 755 /opt/ezrec-backend/logs
chmod 755 /opt/ezrec-backend/user_assets

# Copy the upload script if it's not already there
if [ ! -f /opt/ezrec-backend/upload_recordings.py ]; then
    echo "📄 Copying upload script..."
    cp upload_recordings.py /opt/ezrec-backend/
    chown ezrec:ezrec /opt/ezrec-backend/upload_recordings.py
    chmod +x /opt/ezrec-backend/upload_recordings.py
fi

# Ensure the .env file exists and has proper ownership
echo "⚙️ Checking .env file..."
if [ ! -f /opt/ezrec-backend/.env ]; then
    echo "❌ .env file not found at /opt/ezrec-backend/.env"
    echo "   Please create it with your Supabase credentials"
    echo "   Example:"
    echo "   SUPABASE_URL=https://your-project.supabase.co"
    echo "   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key"
    echo "   USER_ID=your_user_id"
    echo "   CAMERA_ID=raspberry_pi_camera"
    echo "   DELETE_AFTER_UPLOAD=false"
    exit 1
else
    chown ezrec:ezrec /opt/ezrec-backend/.env
    chmod 600 /opt/ezrec-backend/.env
fi

# Create a simple environment test script
cat > /opt/ezrec-backend/test_env.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
sys.path.insert(0, '/opt/ezrec-backend/src')
from dotenv import load_dotenv

print("🔍 Environment Test:")
print(f"Current working directory: {os.getcwd()}")
print(f"Python path: {sys.path}")

# Load .env file
load_dotenv('/opt/ezrec-backend/.env')

print(f"EZREC_BASE_DIR: {os.getenv('EZREC_BASE_DIR', 'NOT SET')}")
print(f"SUPABASE_URL: {'SET' if os.getenv('SUPABASE_URL') else 'NOT SET'}")
print(f"USER_ID: {'SET' if os.getenv('USER_ID') else 'NOT SET'}")

# Test config import
try:
    from config import BASE_DIR, TEMP_DIR, RECORDING_DIR
    print(f"✅ Config loaded successfully")
    print(f"   BASE_DIR: {BASE_DIR}")
    print(f"   TEMP_DIR: {TEMP_DIR}")
    print(f"   RECORDING_DIR: {RECORDING_DIR}")
except Exception as e:
    print(f"❌ Config import failed: {e}")
EOF

chown ezrec:ezrec /opt/ezrec-backend/test_env.py
chmod +x /opt/ezrec-backend/test_env.py

echo ""
echo "✅ Permissions fixed!"
echo ""
echo "🧪 Testing environment setup:"
cd /opt/ezrec-backend
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 test_env.py

echo ""
echo "🎯 Now try running the upload script:"
echo "cd /opt/ezrec-backend"
echo "sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 upload_recordings.py" 