#!/bin/bash

echo "🔧 EZREC Pi Deployment Import Fix"
echo "================================="

# Stop the service first
echo "🛑 Stopping ezrec-backend service..."
sudo systemctl stop ezrec-backend

# Fix the import statement in the deployment directory
echo "🔧 Fixing import statement in /opt/ezrec-backend/src/utils.py..."
sudo sed -i '/from config import (/,/)/c\
from config import (\
    SUPABASE_URL, SUPABASE_ANON_KEY, USER_ID, LOGS_DIR, TEMP_DIR,\
    RECORDINGS_DIR, CAMERA_ID, DEBUG, LOG_LEVEL\
)' /opt/ezrec-backend/src/utils.py

# Verify the fix
echo "✅ Verifying import statement fix:"
sudo grep -A 5 "from config import" /opt/ezrec-backend/src/utils.py

# Clear all Python cache thoroughly
echo "🧹 Clearing Python cache..."
sudo find /opt/ezrec-backend -name "*.pyc" -delete
sudo find /opt/ezrec-backend -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
sudo find /opt/ezrec-backend -name "*.pyo" -delete 2>/dev/null || true

# Test the import
echo "🧪 Testing import..."
sudo python3 -c "
import sys
sys.path.insert(0, '/opt/ezrec-backend/src')
try:
    import utils
    print('✅ Import successful!')
    print('✅ Logger initialized successfully!')
except Exception as e:
    print(f'❌ Import failed: {e}')
    exit(1)
"

if [ $? -eq 0 ]; then
    echo "✅ Import test passed!"
    
    # Start the service
    echo "🚀 Starting ezrec-backend service..."
    sudo systemctl start ezrec-backend
    
    # Wait a moment for startup
    sleep 2
    
    # Check status
    echo "📊 Service status:"
    sudo systemctl status ezrec-backend --no-pager
    
    echo ""
    echo "📋 Recent logs:"
    sudo journalctl -u ezrec-backend --lines=10 --no-pager
    
    echo ""
    echo "🎯 Final status:"
    if sudo systemctl is-active --quiet ezrec-backend; then
        echo "✅ EZREC Backend is running successfully!"
    else
        echo "❌ EZREC Backend failed to start"
    fi
else
    echo "❌ Import test failed. Not starting service."
    exit 1
fi 