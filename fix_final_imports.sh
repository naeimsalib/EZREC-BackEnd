#!/bin/bash

echo "🔧 EZREC Final Import Fix"
echo "========================"

# Stop the service
echo "🛑 Stopping ezrec-backend service..."
sudo systemctl stop ezrec-backend

# Copy the corrected utils.py from source to deployment
echo "📋 Copying corrected utils.py to deployment directory..."
sudo cp ~/code/EZREC-BackEnd/src/utils.py /opt/ezrec-backend/src/

# Verify the import statement is correct
echo "✅ Verifying corrected import statement:"
sudo grep -A 5 "from config import" /opt/ezrec-backend/src/utils.py

# Clear all Python cache
echo "🧹 Clearing Python cache..."
sudo find /opt/ezrec-backend -name "*.pyc" -delete
sudo find /opt/ezrec-backend -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Test the import
echo "🧪 Testing import with corrected utils.py..."
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
    print('✅ Logger initialized successfully!')
    
    # Test Supabase import
    from supabase import create_client
    print('✅ Supabase import successful!')
    
    print('✅ All imports working correctly!')
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
    sleep 4
    
    # Check status
    echo "📊 Service status:"
    sudo systemctl status ezrec-backend --no-pager
    
    echo ""
    echo "📋 Recent logs (checking for success indicators):"
    sudo journalctl -u ezrec-backend --lines=20 --no-pager
    
    echo ""
    echo "🎯 Final verification:"
    if sudo systemctl is-active --quiet ezrec-backend; then
        echo "✅ EZREC Backend is running successfully!"
        echo ""
        echo "🔍 Success indicators to look for:"
        echo "  ✅ 'EZREC Backend Logging Initialized - FIXED VERSION'"
        echo "  ✅ 'Supabase client initialized successfully'"
        echo "  ✅ No 'Only SELECT queries supported' warnings"
        echo "  ✅ Proper booking queries being executed"
        echo ""
        echo "🎉 EZREC system should now be fully operational!"
    else
        echo "❌ EZREC Backend failed to start"
        echo "📋 Checking error logs:"
        sudo journalctl -u ezrec-backend --lines=10 --no-pager
    fi
else
    echo "❌ Import tests failed. Not starting service."
    exit 1
fi 