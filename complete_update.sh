#!/bin/bash

# EZREC Backend - Final Update Script
# This script consolidates all services into a single one and fixes Python import errors.

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

echo "EZREC Backend - Final Update"
echo "============================"
echo ""

# Set the installation directory
EXISTING_DIR="/home/michomanoly14892/code/SmartCam-Soccer/backend"
SERVICE_USER="michomanoly14892"

print_status "Finalizing update for: $EXISTING_DIR"

# Stop and disable all old services first
print_status "Stopping and disabling all old services..."
systemctl stop ezrec-backend.service ezrec-orchestrator.service ezrec-scheduler.service ezrec-status.service 2>/dev/null || true
systemctl disable ezrec-backend.service ezrec-orchestrator.service ezrec-scheduler.service ezrec-status.service 2>/dev/null || true
systemctl stop smartcam.service smartcam-manager.service smartcam-status.service camera.service orchestrator.service scheduler.service zoomcam.service 2>/dev/null || true
systemctl disable smartcam.service smartcam-manager.service smartcam-status.service camera.service orchestrator.service scheduler.service zoomcam.service 2>/dev/null || true
print_info "All old services stopped and disabled."
echo ""

# Remove all old service files to ensure a clean slate
print_status "Removing all old service files..."
rm -f /etc/systemd/system/ezrec-*.service
rm -f /etc/systemd/system/smartcam*.service
rm -f /etc/systemd/system/camera.service
rm -f /etc/systemd/system/orchestrator.service
rm -f /etc/systemd/system/scheduler.service
rm -f /etc/systemd/system/zoomcam.service
print_info "Old service files removed."
echo ""

# Reload systemd to apply the removal
systemctl daemon-reload

# Update .env file
print_status "Updating .env file..."
cat > "$EXISTING_DIR/.env" << EOL
# Supabase Configuration
SUPABASE_URL=https://iszmsaayxpdrovealrrp.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODM2NjAxMywiZXhwIjoyMDYzOTQyMDEzfQ.tzm80_eIy2xho652OxV37ErGnxwOuUvE4-MIPWrdS0c
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjYwMTMsImV4cCI6MjA2Mzk0MjAxM30.5bE_fPBOgkNtEyjCieW328oxyDHWGpf2OTDWssJ_Npk

# User Configuration
USER_ID=65aa2e2a-e463-424d-b88f-0724bb0bea3a
USER_EMAIL=michomanoly14892@gmail.com

# Camera Configuration
CAMERA_ID=b5b0eb67-d1c6-4634-b2e6-4412c57ef49f
CAMERA_NAME=Raspberry Pi Camera
CAMERA_LOCATION=Main Field
CAMERA_DEVICE=/dev/video0

# Camera Settings
CAMERA_WIDTH=1280
CAMERA_HEIGHT=720
CAMERA_FPS=30

# Recording Configuration
RECORDING_DIR=$EXISTING_DIR/recordings
LOG_DIR=$EXISTING_DIR/logs
TEMP_DIR=$EXISTING_DIR/temp
UPLOAD_DIR=$EXISTING_DIR/uploads

# System Configuration
DEBUG=true
LOG_LEVEL=INFO
EOL
print_info "✓ .env file is now correct."
echo ""

# Create the single, unified systemd service
print_status "Creating unified systemd service..."
cat > /etc/systemd/system/ezrec.service << EOL
[Unit]
Description=EZREC Unified Backend Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$EXISTING_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$EXISTING_DIR/.env
# Run the orchestrator as a module to fix import errors
ExecStart=$EXISTING_DIR/venv/bin/python -m src.orchestrator_clean
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec

[Install]
WantedBy=multi-user.target
EOL
print_info "✓ Created ezrec.service"
echo ""

# Reload systemd to recognize the new service
systemctl daemon-reload

# Enable and start the new service
print_status "Enabling and starting the new service..."
systemctl enable ezrec.service
systemctl start ezrec.service
print_info "✓ Service enabled and started."
echo ""

# Create the simplified management script
print_status "Creating simplified management script..."
cat > "$EXISTING_DIR/manage.sh" << 'EOL'
#!/bin/bash
# EZREC Backend Management Script

APP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Ensure the script is run with sudo for service commands
if [[ $EUID -ne 0 ]] && [[ "$1" == "start" || "$1" == "stop" || "$1" == "restart" ]]; then
   echo "This command must be run with sudo." 
   exit 1
fi

case "$1" in
    start)
        echo "Starting EZREC Backend service..."
        systemctl start ezrec.service
        ;;
    stop)
        echo "Stopping EZREC Backend service..."
        systemctl stop ezrec.service
        ;;
    restart)
        echo "Restarting EZREC Backend service..."
        systemctl restart ezrec.service
        ;;
    status)
        echo "EZREC Backend Service Status:"
        systemctl status ezrec.service --no-pager
        ;;
    logs)
        echo "Showing recent logs (-f for follow)..."
        journalctl -u ezrec.service -n 50 --no-pager
        ;;
    health)
        echo "EZREC Backend Health Check"
        echo "========================="
        
        # Check service
        if systemctl is-active --quiet "ezrec.service"; then
            echo "✓ EZREC Service is running"
        else
            echo "✗ EZREC Service is NOT running"
        fi
        
        # Check disk space
        usage=$(df -h "$APP_DIR" | tail -1 | awk '{print $5}')
        echo "✓ Disk space usage: ${usage}"
        
        # Check camera
        if v4l2-ctl --list-devices 2>/dev/null | grep -q "video"; then
            echo "✓ Camera detected"
        else
            echo "✗ No camera detected"
        fi
        
        echo ""
        echo "For detailed logs: journalctl -u ezrec.service -f"
        ;;
    update)
        echo "Updating EZREC Backend..."
        cd "$APP_DIR"
        git pull
        echo "Updating Python dependencies..."
        source venv/bin/activate
        pip install -r requirements.txt
        echo "Restarting service..."
        sudo systemctl restart ezrec.service
        echo "Update complete!"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|health|update}"
        exit 1
        ;;
esac
EOL
chmod +x "$EXISTING_DIR/manage.sh"
chown "$SERVICE_USER:$SERVICE_USER" "$EXISTING_DIR/manage.sh"
print_info "✓ Created manage.sh"
echo ""


# Final status check
print_status "Final status check..."
sleep 3

if systemctl is-active --quiet ezrec.service; then
    print_status "✓✓✓ EZREC Backend service is now running correctly! ✓✓✓"
else
    print_error "✗✗✗ EZREC Backend service failed to start. ✗✗✗"
    print_info "Please check the logs for errors:"
    print_info "  sudo ./manage.sh logs"
fi

echo ""
print_status "Update completed successfully!"
echo ""
print_info "The entire system is now managed by the 'ezrec.service' and the 'manage.sh' script."
print_info "All old services have been removed."
echo ""
print_info "Try these commands now:"
echo "  sudo ./manage.sh status"
echo "  sudo ./manage.sh health"
echo "  sudo ./manage.sh logs"
echo "" 