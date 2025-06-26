#!/bin/bash

echo "🔧 EZREC Environment Variables Fix"
echo "=================================="

# Stop the service
echo "🛑 Stopping ezrec-backend service..."
sudo systemctl stop ezrec-backend

# Fix the .env file to match our code expectations
echo "🔧 Fixing .env file variables..."

# Copy .env to deployment directory if it doesn't exist
if [ ! -f /opt/ezrec-backend/.env ]; then
    echo "📋 Copying .env to deployment directory..."
    sudo cp ~/.env /opt/ezrec-backend/.env
fi

# Fix SUPABASE_KEY -> SUPABASE_ANON_KEY in deployment .env
echo "🔧 Updating SUPABASE_KEY to SUPABASE_ANON_KEY..."
sudo sed -i 's/^SUPABASE_KEY=/SUPABASE_ANON_KEY=/' /opt/ezrec-backend/.env

# Fix directory names to match our code
echo "🔧 Fixing directory variable names..."
sudo sed -i 's/^RECORDING_DIR=/RECORDINGS_DIR=/' /opt/ezrec-backend/.env
sudo sed -i 's/^LOG_DIR=/LOGS_DIR=/' /opt/ezrec-backend/.env

# Fix CAMERA_ID to be numeric instead of string
echo "🔧 Fixing CAMERA_ID to be numeric..."
sudo sed -i 's/^CAMERA_ID=pi_camera_1/CAMERA_ID=0/' /opt/ezrec-backend/.env

# Show the fixed variables
echo "✅ Checking fixed environment variables:"
echo "SUPABASE_ANON_KEY:"
sudo grep "SUPABASE_ANON_KEY=" /opt/ezrec-backend/.env
echo "RECORDINGS_DIR:"
sudo grep "RECORDINGS_DIR=" /opt/ezrec-backend/.env
echo "LOGS_DIR:"
sudo grep "LOGS_DIR=" /opt/ezrec-backend/.env
echo "CAMERA_ID:"
sudo grep "CAMERA_ID=" /opt/ezrec-backend/.env

# Clear Python cache
echo "🧹 Clearing Python cache..."
sudo find /opt/ezrec-backend -name "*.pyc" -delete
sudo find /opt/ezrec-backend -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Test imports with the fixed environment
echo "🧪 Testing imports with fixed environment..."
cd /opt/ezrec-backend
sudo /opt/ezrec-backend/venv/bin/python3 -c "
import sys
import os
sys.path.insert(0, '/opt/ezrec-backend/src')

# Load environment variables
from dotenv import load_dotenv
load_dotenv('/opt/ezrec-backend/.env')

try:
    import utils
    print('✅ Utils import successful!')
    
    # Test Supabase import
    from supabase import create_client
    print('✅ Supabase import successful!')
    
    # Test storage3 import
    from storage3 import create_client as create_storage_client
    print('✅ Storage3 import successful!')
    
    print('✅ All imports working!')
except Exception as e:
    print(f'❌ Import failed: {e}')
    import traceback
    traceback.print_exc()
    exit(1)
"

if [ $? -eq 0 ]; then
    echo "✅ All import tests passed!"
    
    # Start the service
    echo "🚀 Starting ezrec-backend service..."
    sudo systemctl start ezrec-backend
    
    # Wait for startup
    sleep 3
    
    # Check status
    echo "📊 Service status:"
    sudo systemctl status ezrec-backend --no-pager
    
    echo ""
    echo "📋 Recent logs:"
    sudo journalctl -u ezrec-backend --lines=15 --no-pager
    
    echo ""
    echo "🎯 Final status:"
    if sudo systemctl is-active --quiet ezrec-backend; then
        echo "✅ EZREC Backend is running successfully!"
        echo ""
        echo "🔍 Looking for these success indicators:"
        echo "  - 'Supabase client initialized successfully'"
        echo "  - No 'Only SELECT queries supported' warnings"
        echo "  - Proper booking queries being executed"
    else
        echo "❌ EZREC Backend failed to start"
    fi
else
    echo "❌ Import tests failed. Not starting service."
    exit 1
fi 