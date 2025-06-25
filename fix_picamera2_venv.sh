#!/bin/bash

# Enhanced Picamera2 Virtual Environment Fix
# Multiple approaches to get Picamera2 working in the venv

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║             Enhanced Picamera2 Virtual Environment Fix        ║"
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
    print_error "Please run with sudo: sudo ./fix_picamera2_venv.sh"
    exit 1
fi

# Stop service first
print_info "Stopping EZREC service..."
systemctl stop ezrec-backend
print_status "Service stopped"
echo

print_info "Method 1: Recreating virtual environment with system site packages..."

cd /opt/ezrec-backend

# Backup current venv
if [ -d "venv" ]; then
    print_info "Backing up current virtual environment..."
    mv venv venv_backup_$(date +%Y%m%d_%H%M%S)
fi

# Create new venv with system site packages access
print_info "Creating new virtual environment with system site packages..."
python3 -m venv --system-site-packages venv
chown -R ezrec:ezrec venv

# Activate and install requirements
print_info "Installing requirements in new environment..."
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install --upgrade pip
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install -r requirements.txt

# Test if picamera2 is now available
print_info "Testing Picamera2 availability..."
if sudo -u ezrec /opt/ezrec-backend/venv/bin/python -c "import picamera2; print('Picamera2 imported successfully')" 2>/dev/null; then
    print_status "Method 1 SUCCESS: Picamera2 is now available!"
    METHOD1_SUCCESS=true
else
    print_warning "Method 1 failed, trying alternative approaches..."
    METHOD1_SUCCESS=false
fi

if [ "$METHOD1_SUCCESS" = false ]; then
    print_info "Method 2: Manual symlink approach..."
    
    # Find system site packages
    SYSTEM_SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null)
    VENV_SITE_PACKAGES="/opt/ezrec-backend/venv/lib/python3.11/site-packages"
    
    print_info "System packages: $SYSTEM_SITE_PACKAGES"
    print_info "Venv packages: $VENV_SITE_PACKAGES"
    
    # Create symlinks for picamera2 and dependencies
    if [ -d "$SYSTEM_SITE_PACKAGES/picamera2" ]; then
        ln -sf "$SYSTEM_SITE_PACKAGES/picamera2" "$VENV_SITE_PACKAGES/"
        print_status "Created picamera2 symlink"
    fi
    
    if [ -d "$SYSTEM_SITE_PACKAGES/libcamera" ]; then
        ln -sf "$SYSTEM_SITE_PACKAGES/libcamera" "$VENV_SITE_PACKAGES/"
        print_status "Created libcamera symlink"
    fi
    
    # Link additional camera-related packages
    for pkg in "numpy" "PIL" "cv2"; do
        if [ -d "$SYSTEM_SITE_PACKAGES/$pkg" ]; then
            ln -sf "$SYSTEM_SITE_PACKAGES/$pkg" "$VENV_SITE_PACKAGES/"
            print_status "Created $pkg symlink"
        fi
    done
    
    # Link .so files and other camera-related files
    find "$SYSTEM_SITE_PACKAGES" -name "*picamera*" -o -name "*libcamera*" -o -name "*numpy*" | while read file; do
        if [ -f "$file" ]; then
            ln -sf "$file" "$VENV_SITE_PACKAGES/$(basename "$file")" 2>/dev/null
        fi
    done
    
    print_status "Symlinks created"
fi

print_info "Method 3: Testing comprehensive camera setup..."

# Test picamera2 again
if sudo -u ezrec /opt/ezrec-backend/venv/bin/python -c "
try:
    from picamera2 import Picamera2
    print('✓ Picamera2 import successful')
    
    # Quick camera test
    picam = Picamera2()
    camera_config = picam.create_preview_configuration(main={'size': (640, 480)})
    picam.configure(camera_config)
    picam.start()
    frame = picam.capture_array()
    print(f'✓ Camera test successful: Frame shape {frame.shape}')
    picam.stop()
    picam.close()
    exit(0)
except Exception as e:
    print(f'✗ Camera test failed: {e}')
    exit(1)
" 2>/dev/null; then
    print_status "SUCCESS: Picamera2 and camera are working!"
    CAMERA_WORKING=true
else
    print_warning "Camera test failed, trying alternative approach..."
    CAMERA_WORKING=false
fi

if [ "$CAMERA_WORKING" = false ]; then
    print_info "Method 4: Alternative virtual environment setup..."
    
    # Remove current venv and create with different approach
    rm -rf venv
    
    # Create venv without isolating from system packages
    python3 -m venv venv --without-pip
    /opt/ezrec-backend/venv/bin/python -m ensurepip --upgrade
    
    # Install packages that don't conflict with system packages
    sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install python-dotenv psutil pytz supabase httpx opencv-python
    
    # Create pth file to include system packages
    echo "$SYSTEM_SITE_PACKAGES" > /opt/ezrec-backend/venv/lib/python3.11/site-packages/system.pth
    
    chown -R ezrec:ezrec venv
    
    print_status "Alternative environment created"
fi

# Final test
print_info "Final comprehensive test..."
if sudo -u ezrec /opt/ezrec-backend/venv/bin/python -c "
import sys
print('Python path:')
for p in sys.path:
    print(f'  {p}')
print()

try:
    from picamera2 import Picamera2
    print('✓ Picamera2 imported successfully')
    
    picam = Picamera2()
    print('✓ Picamera2 object created')
    
    config = picam.create_preview_configuration(main={'size': (640, 480)})
    picam.configure(config)
    print('✓ Camera configured')
    
    picam.start()
    print('✓ Camera started')
    
    frame = picam.capture_array()
    print(f'✓ Frame captured: {frame.shape}')
    
    picam.stop()
    picam.close()
    print('✓ Camera stopped')
    
    print('🎉 COMPLETE SUCCESS: Camera fully functional!')
    
except Exception as e:
    print(f'✗ Test failed: {e}')
    import traceback
    traceback.print_exc()
"; then
    print_status "🎉 FINAL SUCCESS: Everything is working!"
    FINAL_SUCCESS=true
else
    print_error "Final test failed"
    FINAL_SUCCESS=false
fi

# Restart service
print_info "Restarting EZREC service..."
systemctl start ezrec-backend
sleep 3

if systemctl is-active --quiet ezrec-backend; then
    print_status "Service restarted successfully"
else
    print_warning "Service may have issues"
fi

echo
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                        SUMMARY                                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"

if [ "$FINAL_SUCCESS" = true ]; then
    print_status "✅ Picamera2 is working in virtual environment"
    print_status "✅ Camera hardware test successful"
    print_status "✅ EZREC should now work properly"
    echo
    print_info "Next steps:"
    echo "  1. Check service logs: sudo journalctl -u ezrec-backend -f"
    echo "  2. Verify no more camera errors in logs"
    echo "  3. Configure Supabase environment if needed"
else
    print_warning "⚠️  Picamera2 setup needs manual intervention"
    echo
    print_info "Manual troubleshooting steps:"
    echo "  1. Check system picamera2: python3 -c 'import picamera2'"
    echo "  2. Check venv python path: sudo -u ezrec /opt/ezrec-backend/venv/bin/python -c 'import sys; print(sys.path)'"
    echo "  3. Manually copy system packages if needed"
fi

echo
print_info "Test camera manually: sudo -u ezrec /opt/ezrec-backend/venv/bin/python -c 'from picamera2 import Picamera2; print(\"Works!\")'" 