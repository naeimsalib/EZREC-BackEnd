#!/bin/bash

echo "🔧 EZREC Picamera2 Fix Script"
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

# Stop the service first
echo -e "${YELLOW}🛑 Stopping EZREC service...${NC}"
sudo systemctl stop ezrec-backend.service

# Navigate to deployment directory
cd /opt/ezrec-backend || {
    echo -e "${RED}❌ Deployment directory not found${NC}"
    exit 1
}

echo -e "${YELLOW}📦 Installing picamera2 in virtual environment...${NC}"

# Activate virtual environment and install picamera2
source venv/bin/activate

# Update pip first
pip install --upgrade pip

# Install picamera2 dependencies
echo -e "${YELLOW}📋 Installing system dependencies...${NC}"
sudo apt update
sudo apt install -y python3-libcamera python3-picamera2

# Install picamera2 in virtual environment
echo -e "${YELLOW}🎥 Installing picamera2...${NC}"
pip install picamera2

# Also install other camera-related dependencies that might be needed
pip install opencv-python-headless numpy

# Verify installation
echo -e "${YELLOW}🔍 Verifying picamera2 installation...${NC}"
python -c "import picamera2; print('✅ picamera2 successfully imported')" || {
    echo -e "${RED}❌ picamera2 installation failed${NC}"
    exit 1
}

# Test camera access (if camera is connected)
echo -e "${YELLOW}📸 Testing camera access...${NC}"
python -c "
try:
    from picamera2 import Picamera2
    picam2 = Picamera2()
    camera_info = picam2.sensor_modes
    print('✅ Camera access successful')
    print(f'📊 Found {len(camera_info)} camera modes')
except Exception as e:
    print(f'⚠️  Camera test warning: {e}')
    print('📝 This is normal if no camera is connected')
" 2>/dev/null || echo -e "${YELLOW}⚠️  Camera test completed with warnings (normal if no physical camera)${NC}"

# Restart the service
echo -e "${YELLOW}🚀 Restarting EZREC service...${NC}"
sudo systemctl start ezrec-backend.service

# Check service status
sleep 2
if sudo systemctl is-active --quiet ezrec-backend.service; then
    echo -e "${GREEN}✅ EZREC service restarted successfully${NC}"
    echo -e "${GREEN}📊 Service status:${NC}"
    sudo systemctl status ezrec-backend.service --no-pager -l
else
    echo -e "${RED}❌ Service failed to start${NC}"
    echo -e "${RED}📋 Recent logs:${NC}"
    sudo journalctl -u ezrec-backend.service --no-pager -l -n 20
fi

echo -e "${GREEN}🎉 Picamera2 fix completed!${NC}"
echo -e "📋 Next steps:"
echo -e "   1. Monitor logs: sudo journalctl -u ezrec-backend.service -f"
echo -e "   2. Check that camera errors are resolved"
echo -e "   3. Test with a booking to verify recording works" 