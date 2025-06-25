#!/bin/bash
# Deploy EZREC Scripts to Pi Installation Directory
# Ensures all scripts are available in /opt/ezrec-backend/

echo "📦 EZREC Pi Scripts Deployment"
echo "=============================="
echo "Time: $(date)"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Source directory (current git repo)
SOURCE_DIR="$(pwd)"
DEST_DIR="/opt/ezrec-backend"

echo "📂 Source: $SOURCE_DIR"
echo "📂 Destination: $DEST_DIR"
echo

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Copy essential scripts to Pi installation directory
echo "📋 Copying essential scripts..."

# Test booking script
if [ -f "$SOURCE_DIR/create_test_booking_pi.py" ]; then
    cp "$SOURCE_DIR/create_test_booking_pi.py" "$DEST_DIR/"
    chmod +x "$DEST_DIR/create_test_booking_pi.py"
    chown ezrec:ezrec "$DEST_DIR/create_test_booking_pi.py"
    echo "✅ create_test_booking_pi.py deployed"
else
    echo "❌ create_test_booking_pi.py not found in source"
fi

# Camera fix script
if [ -f "$SOURCE_DIR/ultimate_camera_fix.sh" ]; then
    cp "$SOURCE_DIR/ultimate_camera_fix.sh" "$DEST_DIR/"
    chmod +x "$DEST_DIR/ultimate_camera_fix.sh"
    chown ezrec:ezrec "$DEST_DIR/ultimate_camera_fix.sh"
    echo "✅ ultimate_camera_fix.sh deployed"
else
    echo "❌ ultimate_camera_fix.sh not found in source"
fi

# Verification scripts
for script in verify_pi_setup.py troubleshoot_recording.sh check_booking_status.sh; do
    if [ -f "$SOURCE_DIR/$script" ]; then
        cp "$SOURCE_DIR/$script" "$DEST_DIR/"
        chmod +x "$DEST_DIR/$script"
        chown ezrec:ezrec "$DEST_DIR/$script"
        echo "✅ $script deployed"
    fi
done

echo
echo "📊 Deployment Summary:"
echo "====================="
ls -la "$DEST_DIR"/*.py "$DEST_DIR"/*.sh 2>/dev/null | grep -E "(create_test_booking_pi|ultimate_camera_fix|verify_pi_setup|troubleshoot_recording|check_booking_status)"

echo
echo "✅ Scripts deployed successfully!"
echo
echo "🎯 Next steps on Pi:"
echo "1. Run camera fix: sudo /opt/ezrec-backend/ultimate_camera_fix.sh"
echo "2. Create test booking: sudo python3 /opt/ezrec-backend/create_test_booking_pi.py"
echo "3. Monitor logs: sudo journalctl -u ezrec-backend -f" 