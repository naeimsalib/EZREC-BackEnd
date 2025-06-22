#!/bin/bash

# EZREC Backend - Simple libcamera Fix Script
# This script installs the Python libcamera module without touching system packages

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[-]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

APP_DIR="/home/michomanoly14892/code/SmartCam-Soccer/backend"
SERVICE_USER="michomanoly14892"

print_status "Starting simple libcamera fix..."

# Step 1: Stop the service
print_status "Step 1: Stopping service..."
systemctl stop ezrec.service 2>/dev/null || true

# Step 2: Install Python libcamera module in virtual environment
print_status "Step 2: Installing Python libcamera module..."

cd "$APP_DIR"

# Install libcamera Python module
print_info "Installing libcamera Python module..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install libcamera==0.2.0

# Install picamera2 Python module
print_info "Installing picamera2 Python module..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install picamera2==0.3.27

# Step 3: Test the installation
print_status "Step 3: Testing libcamera installation..."

# Create a simple test script
cat > "$APP_DIR/test_libcamera_simple.py" << 'EOL'
#!/usr/bin/env python3
"""
Simple libcamera test script
"""

import sys

def test_libcamera_import():
    """Test if libcamera can be imported"""
    print("Testing libcamera import...")
    try:
        import libcamera
        print("✓ libcamera imported successfully")
        return True
    except ImportError as e:
        print(f"✗ libcamera import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ libcamera import failed (other): {e}")
        return False

def test_picamera2_import():
    """Test if picamera2 can be imported"""
    print("Testing picamera2 import...")
    try:
        from picamera2 import Picamera2
        print("✓ picamera2 imported successfully")
        return True
    except ImportError as e:
        print(f"✗ picamera2 import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ picamera2 import failed (other): {e}")
        return False

def main():
    print("EZREC Backend - Simple libcamera Test")
    print("=" * 40)
    
    libcamera_ok = test_libcamera_import()
    print()
    picamera2_ok = test_picamera2_import()
    
    print("\nTest Summary:")
    print(f"libcamera: {'✓' if libcamera_ok else '✗'}")
    print(f"picamera2: {'✓' if picamera2_ok else '✗'}")
    
    if libcamera_ok and picamera2_ok:
        print("\n✓ Both libcamera and picamera2 are working!")
        return True
    else:
        print("\n✗ Some components are missing!")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
EOL

chmod +x "$APP_DIR/test_libcamera_simple.py"

# Run the test
print_info "Running simple libcamera test..."
if sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" "$APP_DIR/test_libcamera_simple.py"; then
    print_status "✓ libcamera test passed!"
else
    print_error "✗ libcamera test failed"
    print_warning "This may indicate a deeper system issue"
fi

# Step 4: Start the service
print_status "Step 4: Starting service..."
systemctl start ezrec.service

# Step 5: Verify it's working
print_status "Step 5: Verifying service status..."
sleep 5

if systemctl is-active --quiet ezrec.service; then
    print_status "✓ Service is running successfully!"
else
    print_error "✗ Service failed to start. Checking logs..."
    journalctl -u ezrec.service -n 10
    print_warning "Service failed, but libcamera Python modules should now be available"
fi

print_status "Simple libcamera fix completed!"

print_info "Next steps:"
echo "1. Test libcamera: sudo -u $SERVICE_USER $APP_DIR/venv/bin/python $APP_DIR/test_libcamera_simple.py"
echo "2. Check service status: sudo $APP_DIR/manage.sh status"
echo "3. View logs: sudo $APP_DIR/manage.sh logs"

print_warning "The Python libcamera modules have been installed!"
print_warning "If the service still fails, there may be hardware or system-level issues." 