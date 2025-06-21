#!/bin/bash

# EZREC Backend - Complete Update Script
# This script completes the interrupted update and fixes the .env file

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

echo "EZREC Backend - Complete Update"
echo "=============================="
echo ""

# Set the installation directory
EXISTING_DIR="/home/michomanoly14892/code/SmartCam-Soccer/backend"
SERVICE_USER="michomanoly14892"

print_status "Completing update for: $EXISTING_DIR"

# Stop existing services first
print_status "Stopping existing services..."
systemctl stop smartcam.service 2>/dev/null || true
systemctl stop smartcam-manager.service 2>/dev/null || true
systemctl stop smartcam-status.service 2>/dev/null || true
systemctl stop camera.service 2>/dev/null || true
systemctl stop orchestrator.service 2>/dev/null || true
systemctl stop scheduler.service 2>/dev/null || true

echo ""

# Update .env file with missing variables
print_status "Updating .env file with missing variables..."

# Backup current .env
cp "$EXISTING_DIR/.env" "$EXISTING_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"

# Create updated .env file
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

print_info "Updated .env file with all correct keys."

echo ""

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p "$EXISTING_DIR/recordings"
mkdir -p "$EXISTING_DIR/logs"
mkdir -p "$EXISTING_DIR/temp"
mkdir -p "$EXISTING_DIR/uploads"
mkdir -p "$EXISTING_DIR/user_assets"

echo ""

# Update Python dependencies
print_status "Updating Python dependencies..."
cd "$EXISTING_DIR"

if [ -d "venv" ]; then
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    print_info "Updated existing virtual environment"
else
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    print_info "Created new virtual environment"
fi

echo ""

# Create systemd services
print_status "Creating systemd services..."

cat > /etc/systemd/system/ezrec-backend.service << EOL
[Unit]
Description=EZREC Backend Service
After=network.target
Wants=ezrec-orchestrator.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$EXISTING_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$EXISTING_DIR/.env
ExecStart=$EXISTING_DIR/venv/bin/python src/orchestrator_clean.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-backend

[Install]
WantedBy=multi-user.target
EOL

cat > /etc/systemd/system/ezrec-orchestrator.service << EOL
[Unit]
Description=EZREC Orchestrator Service
After=network.target
PartOf=ezrec-backend.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$EXISTING_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$EXISTING_DIR/.env
ExecStart=$EXISTING_DIR/venv/bin/python src/orchestrator_clean.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-orchestrator

[Install]
WantedBy=multi-user.target
EOL

cat > /etc/systemd/system/ezrec-scheduler.service << EOL
[Unit]
Description=EZREC Scheduler Service
After=network.target
PartOf=ezrec-backend.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$EXISTING_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$EXISTING_DIR/.env
ExecStart=$EXISTING_DIR/venv/bin/python src/scheduler.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-scheduler

[Install]
WantedBy=multi-user.target
EOL

cat > /etc/systemd/system/ezrec-status.service << EOL
[Unit]
Description=EZREC Status Service
After=network.target
PartOf=ezrec-backend.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$EXISTING_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$EXISTING_DIR/.env
ExecStart=$EXISTING_DIR/venv/bin/python -c "from src.utils import update_system_status; import time; [update_system_status() or time.sleep(15) for _ in iter(int, 1)]"
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-status

[Install]
WantedBy=multi-user.target
EOL

echo ""

# Remove old service files
print_status "Removing old service files..."
rm -f /etc/systemd/system/smartcam.service
rm -f /etc/systemd/system/smartcam-manager.service
rm -f /etc/systemd/system/smartcam-status.service
rm -f /etc/systemd/system/camera.service
rm -f /etc/systemd/system/orchestrator.service
rm -f /etc/systemd/system/scheduler.service
rm -f /etc/systemd/system/zoomcam.service

# Reload systemd
systemctl daemon-reload

echo ""

# Set permissions
print_status "Setting permissions..."
chown -R "$SERVICE_USER:$SERVICE_USER" "$EXISTING_DIR"
chmod -R 755 "$EXISTING_DIR"
chmod -R 777 "$EXISTING_DIR/temp" "$EXISTING_DIR/recordings" "$EXISTING_DIR/logs" "$EXISTING_DIR/uploads"

echo ""

# Enable and start new services
print_status "Enabling and starting new services..."
systemctl enable ezrec-backend.service
systemctl enable ezrec-orchestrator.service
systemctl enable ezrec-scheduler.service
systemctl enable ezrec-status.service

systemctl start ezrec-backend.service

echo ""

# Create management script
print_status "Creating management script..."
cat > "$EXISTING_DIR/manage.sh" << 'EOL'
#!/bin/bash
# EZREC Backend Management Script

APP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SERVICE_USER="michomanoly14892"

case "$1" in
    start)
        echo "Starting EZREC Backend services..."
        systemctl start ezrec-backend.service
        ;;
    stop)
        echo "Stopping EZREC Backend services..."
        systemctl stop ezrec-backend.service
        ;;
    restart)
        echo "Restarting EZREC Backend services..."
        systemctl restart ezrec-backend.service
        ;;
    status)
        echo "EZREC Backend Service Status:"
        systemctl status ezrec-backend.service --no-pager
        echo ""
        echo "All EZREC Services:"
        systemctl status ezrec-*.service --no-pager
        ;;
    logs)
        echo "Showing recent logs..."
        journalctl -u ezrec-backend.service -f
        ;;
    health)
        echo "EZREC Backend Health Check"
        echo "========================="
        
        # Check services
        for service in ezrec-backend ezrec-orchestrator ezrec-scheduler ezrec-status; do
            if systemctl is-active --quiet "$service.service"; then
                echo "✓ $service.service is running"
            else
                echo "✗ $service.service is not running"
            fi
        done
        
        # Check disk space
        usage=$(df "$APP_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
        if [ "$usage" -lt 90 ]; then
            echo "✓ Disk space OK: ${usage}% used"
        else
            echo "✗ Disk space critical: ${usage}% used"
        fi
        
        # Check camera
        if v4l2-ctl --list-devices | grep -q "video"; then
            echo "✓ Camera detected"
        else
            echo "✗ No camera detected"
        fi
        
        echo ""
        echo "For detailed logs: journalctl -u ezrec-backend.service -f"
        ;;
    update)
        echo "Updating EZREC Backend..."
        cd "$APP_DIR"
        git pull
        source venv/bin/activate
        pip install -r requirements.txt
        systemctl restart ezrec-backend.service
        echo "Update complete!"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|health|update}"
        exit 1
        ;;
esac
EOL

chmod +x "$EXISTING_DIR/manage.sh"

echo ""

# Create logrotate configuration
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/ezrec-backend << EOL
$EXISTING_DIR/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
    postrotate
        systemctl reload ezrec-backend.service
    endscript
}
EOL

echo ""

# Final status check
print_status "Final status check..."
sleep 3

if systemctl is-active --quiet ezrec-backend.service; then
    print_status "✓ EZREC Backend service is running"
else
    print_warning "✗ EZREC Backend service is not running"
    print_info "Check logs: journalctl -u ezrec-backend.service -n 50"
fi

echo ""
print_status "Update completed successfully!"
echo ""
print_info "Installation directory: $EXISTING_DIR"
echo ""
print_info "Available commands:"
echo "  sudo $EXISTING_DIR/manage.sh start"
echo "  sudo $EXISTING_DIR/manage.sh stop"
echo "  sudo $EXISTING_DIR/manage.sh restart"
echo "  sudo $EXISTING_DIR/manage.sh status"
echo "  sudo $EXISTING_DIR/manage.sh logs"
echo "  sudo $EXISTING_DIR/manage.sh health"
echo "  sudo $EXISTING_DIR/manage.sh update"
echo ""
print_warning "IMPORTANT: All keys have been updated. No manual .env edit is needed."
echo "You can now manage the service with ./manage.sh" 