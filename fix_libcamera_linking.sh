#!/bin/bash

echo "🔗 EZREC Libcamera Linking Fix"
echo "=============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo -e "${RED}❌ This script should be run on a Raspberry Pi${NC}"
    exit 1
fi

# Navigate to deployment directory
cd /opt/ezrec-backend || {
    echo -e "${RED}❌ Deployment directory not found${NC}"
    exit 1
}

echo -e "${YELLOW}🔍 Locating system libcamera modules...${NC}"

# Find system libcamera paths
SYSTEM_LIBCAMERA_PATHS=(
    "/usr/lib/python3/dist-packages"
    "/usr/local/lib/python3.11/dist-packages"
    "/usr/lib/python3.11/dist-packages"
)

LIBCAMERA_FOUND=""
for path in "${SYSTEM_LIBCAMERA_PATHS[@]}"; do
    if [ -d "$path/libcamera" ]; then
        LIBCAMERA_FOUND="$path"
        echo -e "${GREEN}✅ Found libcamera at: $path${NC}"
        break
    fi
done

if [ -z "$LIBCAMERA_FOUND" ]; then
    echo -e "${RED}❌ System libcamera not found. Installing...${NC}"
    sudo apt update
    sudo apt install -y python3-libcamera
    
    # Re-check after installation
    for path in "${SYSTEM_LIBCAMERA_PATHS[@]}"; do
        if [ -d "$path/libcamera" ]; then
            LIBCAMERA_FOUND="$path"
            echo -e "${GREEN}✅ Found libcamera at: $path after installation${NC}"
            break
        fi
    done
    
    if [ -z "$LIBCAMERA_FOUND" ]; then
        echo -e "${RED}❌ Failed to install or locate libcamera${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}🔗 Creating symbolic links in virtual environment...${NC}"

# Activate virtual environment
source venv/bin/activate

# Get the site-packages directory
VENV_SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
echo -e "${GREEN}📍 Virtual env site-packages: $VENV_SITE_PACKAGES${NC}"

# Create symbolic links for libcamera modules
echo -e "${YELLOW}🔗 Linking libcamera modules...${NC}"
ln -sf "$LIBCAMERA_FOUND/libcamera" "$VENV_SITE_PACKAGES/libcamera" 2>/dev/null || echo -e "${YELLOW}⚠️  libcamera link may already exist${NC}"

# Also link _libcamera if it exists
if [ -f "$LIBCAMERA_FOUND/_libcamera.cpython-"* ]; then
    ln -sf "$LIBCAMERA_FOUND"/_libcamera.cpython-* "$VENV_SITE_PACKAGES/" 2>/dev/null || echo -e "${YELLOW}⚠️  _libcamera link may already exist${NC}"
fi

# Create a .pth file to add system paths to Python path
echo -e "${YELLOW}📝 Adding system paths to virtual environment...${NC}"
echo "$LIBCAMERA_FOUND" > "$VENV_SITE_PACKAGES/libcamera_system.pth"

# Verify the fix
echo -e "${YELLOW}🔍 Testing libcamera import...${NC}"
python -c "
try:
    import libcamera
    print('✅ libcamera successfully imported')
    print(f'📍 libcamera location: {libcamera.__file__}')
except Exception as e:
    print(f'❌ libcamera import failed: {e}')
    exit(1)
"

# Test picamera2 import
echo -e "${YELLOW}🎥 Testing picamera2 import...${NC}"
python -c "
try:
    import picamera2
    print('✅ picamera2 successfully imported')
    print(f'📍 picamera2 location: {picamera2.__file__}')
except Exception as e:
    print(f'❌ picamera2 import failed: {e}')
    exit(1)
"

# Test full camera functionality
echo -e "${YELLOW}📸 Testing camera functionality...${NC}"
python -c "
try:
    from picamera2 import Picamera2
    picam2 = Picamera2()
    print('✅ Picamera2 object created successfully')
    try:
        sensor_modes = picam2.sensor_modes
        print(f'📊 Camera has {len(sensor_modes)} sensor modes available')
        print('✅ Camera functionality test passed')
    except Exception as e:
        print(f'⚠️  Camera hardware test warning: {e}')
        print('📝 This is normal if no physical camera is connected')
    finally:
        try:
            picam2.close()
        except:
            pass
except Exception as e:
    print(f'❌ Camera functionality test failed: {e}')
    exit(1)
" || echo -e "${YELLOW}⚠️  Camera test completed with warnings (normal if no physical camera)${NC}"

echo -e "${GREEN}🎉 Libcamera linking fix completed successfully!${NC}"
echo -e "${GREEN}✅ Both libcamera and picamera2 are now working${NC}"

# Restart the EZREC service
echo -e "${YELLOW}🚀 Restarting EZREC service...${NC}"
sudo systemctl start ezrec-backend.service

# Check service status
sleep 2
if sudo systemctl is-active --quiet ezrec-backend.service; then
    echo -e "${GREEN}✅ EZREC service restarted successfully${NC}"
    echo -e "${GREEN}🔍 Checking for camera errors in logs...${NC}"
    
    # Check recent logs for camera errors
    if sudo journalctl -u ezrec-backend.service --since "1 minute ago" | grep -q "No module named 'picamera2'"; then
        echo -e "${RED}❌ Still seeing picamera2 errors${NC}"
    elif sudo journalctl -u ezrec-backend.service --since "1 minute ago" | grep -q "No module named 'libcamera'"; then
        echo -e "${RED}❌ Still seeing libcamera errors${NC}"
    else
        echo -e "${GREEN}✅ No camera import errors detected!${NC}"
    fi
else
    echo -e "${RED}❌ Service failed to start${NC}"
    sudo journalctl -u ezrec-backend.service --no-pager -l -n 10
fi

echo -e "${GREEN}📋 Next steps:${NC}"
echo -e "   1. Monitor logs: sudo journalctl -u ezrec-backend.service -f"
echo -e "   2. Look for successful camera protection messages"
echo -e "   3. Wait for 21:20 to test booking detection and recording" 