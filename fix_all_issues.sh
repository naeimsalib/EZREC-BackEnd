#!/bin/bash

# EZREC Backend - Complete Fix Script
# This script fixes all the issues we've identified

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

print_status "Starting comprehensive EZREC Backend fix..."

# Step 1: Stop and clean up any existing services
print_status "Step 1: Cleaning up existing services..."
systemctl stop ezrec.service 2>/dev/null || true
systemctl disable ezrec.service 2>/dev/null || true
systemctl stop ezrec-backend.service 2>/dev/null || true
systemctl disable ezrec-backend.service 2>/dev/null || true

# Remove old service files
rm -f /etc/systemd/system/ezrec*.service
systemctl daemon-reload

# Step 2: Fix virtual environment and dependencies
print_status "Step 2: Fixing virtual environment and dependencies..."
cd "$APP_DIR"

# Remove existing venv
print_info "Removing existing virtual environment..."
rm -rf venv

# Create new venv
print_info "Creating new virtual environment..."
sudo -u "$SERVICE_USER" python3 -m venv venv
chown -R "$SERVICE_USER:$SERVICE_USER" venv

# Install dependencies
print_info "Installing Python dependencies..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install --upgrade pip

# Install with --no-deps first to avoid conflicts
print_warning "Installing dependencies with conflict resolution..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install -r requirements.txt --no-deps

# Install dependencies individually to resolve conflicts
print_warning "Installing dependencies individually..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install python-dotenv==1.0.0
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install supabase==2.2.1
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install gotrue==2.9.1
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install postgrest==0.13.0
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install httpx==0.26.0
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install opencv-python==4.8.1.78
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install numpy==1.26.4
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install psutil==5.9.4
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install pytz==2023.3
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install ffmpeg-python==0.2.0
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install picamera2==0.3.27

# Step 3: Create correct service file
print_status "Step 3: Creating correct service file..."
cat > /etc/systemd/system/ezrec.service << EOL
[Unit]
Description=EZREC Backend Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$APP_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/python src/orchestrator.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec

[Install]
WantedBy=multi-user.target
EOL

# Step 4: Create management script
print_status "Step 4: Creating management script..."
cat > "$APP_DIR/manage.sh" << 'EOL'
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
        echo "Showing live logs (Ctrl+C to exit)..."
        journalctl -u ezrec.service -f -n 50 --no-pager
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
        "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"
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

# Step 5: Set permissions
print_status "Step 5: Setting permissions..."
chmod +x "$APP_DIR/manage.sh"
chown "$SERVICE_USER:$SERVICE_USER" "$APP_DIR/manage.sh"
chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"

# Step 6: Enable service
print_status "Step 6: Enabling service..."
systemctl daemon-reload
systemctl enable ezrec.service

# Step 7: Test setup
print_status "Step 7: Testing setup..."
if [ -f "$APP_DIR/test_setup.py" ]; then
    sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" test_setup.py
else
    print_warning "⚠️ Setup test had issues, but continuing..."
fi

print_status "Fix completed successfully!"

print_info "Next steps:"
echo "1. Edit your .env file: sudo nano $APP_DIR/.env"
echo "2. Start the service: sudo $APP_DIR/manage.sh start"
echo "3. Check status: sudo $APP_DIR/manage.sh status"
echo "4. View logs: sudo $APP_DIR/manage.sh logs"
echo "5. Health check: sudo $APP_DIR/manage.sh health"

print_warning "Make sure to configure your Supabase credentials in $APP_DIR/.env" 