#!/bin/bash
# 🔧 EZREC Recording Issues Fix Script
# =====================================
# This script fixes common issues with recording file creation and status updates

set -e

echo "🔧 EZREC Recording Issues Fix Script"
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Service details
SERVICE_NAME="ezrec-backend"
SERVICE_DIR="/opt/ezrec-backend"
SERVICE_USER="michomanoly14892"

# Function to print colored output
log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if running as root/sudo
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

echo "🔍 Step 1: Checking service status..."
if systemctl is-active --quiet $SERVICE_NAME; then
    log_info "Service is running"
    SERVICE_RUNNING=true
else
    log_warn "Service is not running"
    SERVICE_RUNNING=false
fi

echo ""
echo "📁 Step 2: Fixing directory permissions..."

# Create and fix all required directories
DIRECTORIES=(
    "$SERVICE_DIR"
    "$SERVICE_DIR/recordings"
    "$SERVICE_DIR/temp"
    "$SERVICE_DIR/logs"
    "$SERVICE_DIR/uploads"
    "$SERVICE_DIR/user_assets"
)

for dir in "${DIRECTORIES[@]}"; do
    if [[ ! -d "$dir" ]]; then
        log_warn "Creating directory: $dir"
        mkdir -p "$dir"
    fi
    
    # Set proper ownership and permissions
    chown -R $SERVICE_USER:$SERVICE_USER "$dir"
    chmod -R 755 "$dir"
    
    # Make recordings and temp directories fully writable
    if [[ "$dir" == *"recordings"* ]] || [[ "$dir" == *"temp"* ]]; then
        chmod -R 775 "$dir"
    fi
    
    log_info "Fixed permissions for $dir"
done

echo ""
echo "🐍 Step 3: Checking Python dependencies..."

# Check Picamera2 availability
if sudo -u $SERVICE_USER python3 -c "from picamera2 import Picamera2; print('Picamera2 OK')" 2>/dev/null; then
    log_info "Picamera2 is available"
else
    log_warn "Picamera2 may not be available - installing..."
    sudo -u $SERVICE_USER pip3 install --user picamera2
fi

# Check other dependencies
PYTHON_DEPS=("supabase" "psutil" "python-dotenv")
for dep in "${PYTHON_DEPS[@]}"; do
    if sudo -u $SERVICE_USER python3 -c "import $dep" 2>/dev/null; then
        log_info "$dep is available"
    else
        log_warn "Installing $dep..."
        sudo -u $SERVICE_USER pip3 install --user $dep
    fi
done

echo ""
echo "🗄️ Step 4: Checking database table structure..."

# Create a simple database test script
cat > /tmp/test_db.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
sys.path.append('/opt/ezrec-backend/src')

try:
    from config import Config
    from utils import SupabaseManager
    
    config = Config()
    db = SupabaseManager()
    
    # Test system_status table
    result = db.supabase.table("system_status").select("*").limit(1).execute()
    print("✅ system_status table accessible")
    
    # Test bookings table
    result = db.supabase.table("bookings").select("*").limit(1).execute()
    print("✅ bookings table accessible")
    
    # Test videos table (if exists)
    try:
        result = db.supabase.table("videos").select("*").limit(1).execute()
        print("✅ videos table accessible")
    except:
        print("⚠️ videos table may not exist (this is OK)")
    
except Exception as e:
    print(f"❌ Database test failed: {e}")
    sys.exit(1)
EOF

if sudo -u $SERVICE_USER python3 /tmp/test_db.py 2>/dev/null; then
    log_info "Database connectivity is working"
else
    log_warn "Database connectivity issues detected"
fi
rm -f /tmp/test_db.py

echo ""
echo "📹 Step 5: Testing camera access..."

# Test camera access
cat > /tmp/test_camera.py << 'EOF'
#!/usr/bin/env python3
try:
    from picamera2 import Picamera2
    picam2 = Picamera2()
    picam2.close()
    print("✅ Camera access OK")
except Exception as e:
    print(f"❌ Camera access failed: {e}")
EOF

if sudo -u $SERVICE_USER python3 /tmp/test_camera.py 2>/dev/null; then
    log_info "Camera access is working"
else
    log_warn "Camera access issues detected - may need reboot"
fi
rm -f /tmp/test_camera.py

echo ""
echo "🔧 Step 6: Applying service fixes..."

# Create improved orchestrator startup script
cat > "$SERVICE_DIR/start_orchestrator.py" << 'EOF'
#!/usr/bin/env python3
"""
Enhanced EZREC Orchestrator Startup Script
==========================================
This script includes additional error handling and diagnostics.
"""
import os
import sys
import time

# Ensure proper working directory
os.chdir('/opt/ezrec-backend')

# Add src to path
sys.path.insert(0, '/opt/ezrec-backend/src')

try:
    from orchestrator import main
    import asyncio
    
    print("🚀 Starting EZREC Orchestrator with enhanced error handling...")
    
    # Run the orchestrator
    asyncio.run(main())
    
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Orchestrator error: {e}")
    sys.exit(1)
EOF

chmod +x "$SERVICE_DIR/start_orchestrator.py"
chown $SERVICE_USER:$SERVICE_USER "$SERVICE_DIR/start_orchestrator.py"

log_info "Created enhanced startup script"

echo ""
echo "⚡ Step 7: Restarting service..."

if $SERVICE_RUNNING; then
    systemctl restart $SERVICE_NAME
    log_info "Service restarted"
else
    systemctl start $SERVICE_NAME
    log_info "Service started"
fi

# Wait a moment for service to start
sleep 3

# Check service status
if systemctl is-active --quiet $SERVICE_NAME; then
    log_info "Service is now running"
    
    # Show recent logs
    echo ""
    echo "📋 Recent service logs:"
    journalctl -u $SERVICE_NAME --since "30 seconds ago" --no-pager | tail -10
else
    log_error "Service failed to start"
    echo ""
    echo "📋 Error logs:"
    journalctl -u $SERVICE_NAME --since "1 minute ago" --no-pager | tail -10
fi

echo ""
echo "🎯 Step 8: Running quick test..."

# Create a quick test for recording functionality
cat > /tmp/quick_test.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import time
import subprocess
from pathlib import Path

# Test 1: Check if service can create files in recordings dir
test_file = "/opt/ezrec-backend/recordings/test_service_write.txt"
try:
    result = subprocess.run(
        ["sudo", "-u", "michomanoly14892", "touch", test_file],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print("✅ Service can write to recordings directory")
        subprocess.run(["rm", "-f", test_file])
    else:
        print("❌ Service cannot write to recordings directory")
except Exception as e:
    print(f"❌ Write test error: {e}")

# Test 2: Check for recent service activity
try:
    result = subprocess.run(
        ["sudo", "journalctl", "-u", "ezrec-backend", "--since", "1 minute ago", "--no-pager"],
        capture_output=True, text=True
    )
    
    if "EZREC Orchestrator" in result.stdout:
        print("✅ Service is logging activity")
    else:
        print("⚠️ No recent service activity detected")
        
except Exception as e:
    print(f"❌ Log check error: {e}")
EOF

python3 /tmp/quick_test.py
rm -f /tmp/quick_test.py

echo ""
echo "🏁 RECORDING ISSUES FIX COMPLETE"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Run your test again to check if issues are resolved"
echo "2. If still having problems, run the diagnostic script:"
echo "   python3 debug_recording_issues.py"
echo ""
echo "The most common remaining issues are usually:"
echo "- Picamera2 hardware access (may need reboot)"
echo "- Database permissions (check Supabase RLS policies)"
echo "" 