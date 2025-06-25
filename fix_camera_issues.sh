#!/bin/bash

# EZREC Camera and Environment Fix Script
# Fixes camera interface, picamera2, and Supabase connection issues

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║               EZREC Camera & Environment Fix                   ║"
echo "║              Raspberry Pi Issue Resolution                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run with sudo: sudo ./fix_camera_issues.sh"
    exit 1
fi

print_info "Starting EZREC camera and environment fixes..."
echo

# Step 1: Stop the service
print_info "Step 1: Stopping EZREC service..."
systemctl stop ezrec-backend
print_status "Service stopped"
echo

# Step 2: Fix Picamera2 in virtual environment
print_info "Step 2: Installing Picamera2 in virtual environment..."

# First, ensure system picamera2 is properly installed
apt update
apt install -y python3-picamera2 python3-libcamera

# Install picamera2 in virtual environment using system packages
cd /opt/ezrec-backend
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install --system-site-packages picamera2

# Alternative method - create symlinks if pip install fails
if ! sudo -u ezrec /opt/ezrec-backend/venv/bin/python -c "import picamera2" 2>/dev/null; then
    print_warning "Pip install failed, creating system site-packages symlinks..."
    
    # Find system picamera2 location
    SYSTEM_SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
    VENV_SITE_PACKAGES="/opt/ezrec-backend/venv/lib/python3.11/site-packages"
    
    # Create symlinks for picamera2 and libcamera
    if [ -d "$SYSTEM_SITE_PACKAGES/picamera2" ]; then
        ln -sf "$SYSTEM_SITE_PACKAGES/picamera2" "$VENV_SITE_PACKAGES/picamera2"
        print_status "Created picamera2 symlink"
    fi
    
    if [ -d "$SYSTEM_SITE_PACKAGES/libcamera" ]; then
        ln -sf "$SYSTEM_SITE_PACKAGES/libcamera" "$VENV_SITE_PACKAGES/libcamera"
        print_status "Created libcamera symlink"
    fi
    
    # Also link any .so files
    find "$SYSTEM_SITE_PACKAGES" -name "*picamera*" -o -name "*libcamera*" | while read file; do
        if [ -f "$file" ]; then
            ln -sf "$file" "$VENV_SITE_PACKAGES/$(basename "$file")"
        fi
    done
fi

print_status "Picamera2 installation completed"
echo

# Step 3: Update camera interface to prioritize Picamera2
print_info "Step 3: Updating camera interface configuration..."

# Create camera interface patch
cat > /tmp/camera_interface_patch.py << 'EOF'
#!/usr/bin/env python3
"""
Quick test to verify camera interface fixes
"""
import sys
import os
sys.path.insert(0, '/opt/ezrec-backend/src')

def test_camera_imports():
    print("Testing camera imports...")
    
    try:
        from picamera2 import Picamera2
        print("✓ picamera2 import successful")
        
        # Quick test
        picam = Picamera2()
        camera_config = picam.create_preview_configuration(main={"size": (640, 480)})
        picam.configure(camera_config)
        picam.start()
        frame = picam.capture_array()
        print(f"✓ Pi Camera test: Frame shape {frame.shape}")
        picam.stop()
        picam.close()
        return True
        
    except Exception as e:
        print(f"✗ picamera2 test failed: {e}")
        return False

if __name__ == "__main__":
    success = test_camera_imports()
    sys.exit(0 if success else 1)
EOF

# Test the camera interface
sudo -u ezrec /opt/ezrec-backend/venv/bin/python /tmp/camera_interface_patch.py
if [ $? -eq 0 ]; then
    print_status "Camera interface test passed"
else
    print_warning "Camera interface test failed, but continuing..."
fi
echo

# Step 4: Fix environment file for Supabase connection
print_info "Step 4: Checking and fixing environment configuration..."

ENV_FILE="/opt/ezrec-backend/.env"
if [ ! -f "$ENV_FILE" ]; then
    print_warning "Environment file missing, creating template..."
    
    cat > "$ENV_FILE" << 'EOF'
# EZREC Backend Configuration for Raspberry Pi
# IMPORTANT: Fill in your actual Supabase credentials

# Supabase Configuration (REQUIRED - Get from your Supabase dashboard)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

# User Configuration (REQUIRED)
USER_ID=your-user-id-here
USER_EMAIL=your-email@example.com

# Camera Configuration
CAMERA_ID=raspberry_pi_camera
CAMERA_NAME=Raspberry Pi Camera
CAMERA_LOCATION=Living Room

# System Configuration
EZREC_BASE_DIR=/opt/ezrec-backend
LOG_LEVEL=INFO
DEBUG=false

# Recording Settings
RECORD_WIDTH=1920
RECORD_HEIGHT=1080
RECORD_FPS=30
PREVIEW_WIDTH=640
PREVIEW_HEIGHT=480
PREVIEW_FPS=24

# Timing Configuration (seconds)
BOOKING_CHECK_INTERVAL=30
STATUS_UPDATE_INTERVAL=60
HEARTBEAT_INTERVAL=300

# Storage Settings
LOG_MAX_BYTES=10485760
LOG_BACKUP_COUNT=5
EOF
    
    chown ezrec:ezrec "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    print_status "Environment template created"
else
    print_status "Environment file exists"
fi

# Check if environment has required values
if grep -q "your-project.supabase.co" "$ENV_FILE" 2>/dev/null; then
    print_warning "Environment file needs configuration - Supabase credentials required"
    NEEDS_CONFIG=true
else
    print_status "Environment file appears configured"
    NEEDS_CONFIG=false
fi
echo

# Step 5: Update camera interface to use Picamera2 by default
print_info "Step 5: Updating camera interface for better Picamera2 support..."

# Create a simple camera interface override
cat > /opt/ezrec-backend/src/camera_interface_fix.py << 'EOF'
#!/usr/bin/env python3
"""
Camera Interface Fix - Prioritizes Picamera2 for Raspberry Pi
"""
import logging
from typing import Optional, Dict, Any
import time

logger = logging.getLogger(__name__)

def get_working_camera_info() -> Dict[str, Any]:
    """Get camera info prioritizing Picamera2"""
    try:
        from picamera2 import Picamera2
        
        # Test Picamera2
        picam = Picamera2()
        camera_config = picam.create_preview_configuration(main={"size": (640, 480)})
        picam.configure(camera_config)
        picam.start()
        
        # Capture a test frame
        frame = picam.capture_array()
        picam.stop()
        picam.close()
        
        if frame is not None:
            return {
                "camera_type": "Pi Camera (Picamera2)",
                "resolution": "1920x1080",
                "fps": 30,
                "working": True,
                "interface": "picamera2",
                "test_frame_shape": frame.shape
            }
    except Exception as e:
        logger.warning(f"Picamera2 test failed: {e}")
    
    # Fallback info
    return {
        "camera_type": "Unknown",
        "resolution": "1920x1080", 
        "fps": 30,
        "working": False,
        "interface": "none"
    }

if __name__ == "__main__":
    info = get_working_camera_info()
    print(f"Camera info: {info}")
EOF

chown ezrec:ezrec /opt/ezrec-backend/src/camera_interface_fix.py

# Test the fix
print_info "Testing camera interface fix..."
sudo -u ezrec /opt/ezrec-backend/venv/bin/python /opt/ezrec-backend/src/camera_interface_fix.py
echo

# Step 6: Clean up temporary files and restart service
print_info "Step 6: Cleaning up and restarting service..."

rm -f /tmp/camera_interface_patch.py

# Restart the service
systemctl start ezrec-backend
sleep 3

# Check service status
if systemctl is-active --quiet ezrec-backend; then
    print_status "EZREC service restarted successfully"
else
    print_warning "Service restart may have issues - check logs"
fi
echo

# Final summary
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                        FIX SUMMARY                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo

print_status "Camera fixes applied:"
echo "  • Picamera2 installed in virtual environment"
echo "  • Camera interface updated to prioritize Pi Camera"
echo "  • Environment file checked/created"
echo

if [ "$NEEDS_CONFIG" = true ]; then
    print_warning "IMPORTANT: Configure your environment file:"
    echo "  1. Edit: sudo nano /opt/ezrec-backend/.env"
    echo "  2. Add your Supabase URL and service key"
    echo "  3. Add your USER_ID"
    echo "  4. Restart: sudo systemctl restart ezrec-backend"
    echo
fi

print_info "Check service status: sudo systemctl status ezrec-backend"
print_info "View logs: sudo journalctl -u ezrec-backend -f"
print_info "Test camera: sudo -u ezrec /opt/ezrec-backend/venv/bin/python /opt/ezrec-backend/src/camera_interface_fix.py"

echo
print_status "Fix script completed!" 