#!/bin/bash

echo "🔧 EZREC Final Deployment Issues Fix"
echo "===================================="

# Stop the service
echo "🛑 Stopping ezrec-backend service..."
sudo systemctl stop ezrec-backend

# Install missing Supabase module in virtual environment
echo "📦 Installing Supabase Python client..."
sudo /opt/ezrec-backend/venv/bin/pip install supabase storage3

# Copy the latest utils.py with fixed SupabaseManager
echo "🔄 Updating utils.py with fixed SupabaseManager..."
sudo cp ~/code/EZREC-BackEnd/src/utils.py /opt/ezrec-backend/src/

# Verify the SupabaseManager execute_query method is fixed
echo "✅ Checking SupabaseManager execute_query method:"
sudo grep -A 10 "async def execute_query" /opt/ezrec-backend/src/utils.py

# Clear Python cache
echo "🧹 Clearing Python cache..."
sudo find /opt/ezrec-backend -name "*.pyc" -delete
sudo find /opt/ezrec-backend -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Test imports including Supabase
echo "🧪 Testing all imports..."
sudo /opt/ezrec-backend/venv/bin/python3 -c "
import sys
sys.path.insert(0, '/opt/ezrec-backend/src')
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
    echo "📋 Recent logs (looking for fixed SupabaseManager):"
    sudo journalctl -u ezrec-backend --lines=15 --no-pager
    
    echo ""
    echo "🎯 Final status:"
    if sudo systemctl is-active --quiet ezrec-backend; then
        echo "✅ EZREC Backend is running successfully!"
        echo ""
        echo "🔍 Key indicators to look for in logs:"
        echo "  - No 'Only SELECT queries supported' warnings"
        echo "  - Supabase client initialized successfully"
        echo "  - Proper booking queries with WHERE clauses"
    else
        echo "❌ EZREC Backend failed to start"
    fi
else
    echo "❌ Import tests failed. Not starting service."
    exit 1
fi 