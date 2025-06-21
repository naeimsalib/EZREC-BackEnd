#!/bin/bash

# EZREC Backend - Raspberry Pi Setup Script
# THIS IS THE ONLY SUPPORTED INSTALL/UPDATE SCRIPT FOR RASPBERRY PI
# This script installs and configures the EZREC backend on a Raspberry Pi

set -e

# Remove legacy/unsupported scripts if present
if [ -f "complete_update.sh" ]; then
    echo -e "\033[1;33m[!] Removing deprecated complete_update.sh (use only this script for Pi)\033[0m"
    rm -f complete_update.sh
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
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

# Configuration
APP_NAME="EZREC-Backend"
APP_DIR="/opt/ezrec-backend"
SERVICE_USER="ezrec"
SERVICE_GROUP="ezrec"

print_status "Starting EZREC Backend installation on Raspberry Pi..."

# Update system
print_status "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install system dependencies
print_status "Installing system dependencies..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-opencv \
    ffmpeg \
    v4l-utils \
    libopencv-dev \
    libatlas-base-dev \
    libhdf5-dev \
    libhdf5-serial-dev \
    libopenjp2-7 \
    libtiff-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev \
    libjpeg-dev \
    libpng-dev \
    gfortran \
    libopenblas-dev \
    liblapack-dev \
    libimath-dev \
    libopenexr-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    git \
    curl \
    wget

# Create service user
print_status "Creating service user..."
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/bash -d "$APP_DIR" -m "$SERVICE_USER"
    usermod -a -G video "$SERVICE_USER"
    print_status "Created user: $SERVICE_USER"
else
    print_info "User $SERVICE_USER already exists"
fi

# Create application directory
print_status "Setting up application directory..."
mkdir -p "$APP_DIR"
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$APP_DIR"

# Copy application files
print_status "Copying application files..."
cp -r . "$APP_DIR/"
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$APP_DIR"

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p "$APP_DIR/recordings"
mkdir -p "$APP_DIR/logs"
mkdir -p "$APP_DIR/temp"
mkdir -p "$APP_DIR/uploads"
mkdir -p "$APP_DIR/user_assets"
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$APP_DIR"

# Setup Python environment
print_status "Setting up Python virtual environment..."
cd "$APP_DIR"
sudo -u "$SERVICE_USER" python3 -m venv venv
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install --upgrade pip
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install -r requirements.txt

# Create .env file if it doesn't exist
if [ ! -f "$APP_DIR/.env" ]; then
    print_status "Creating .env file..."
    cat > "$APP_DIR/.env" << EOL
# Supabase Configuration
SUPABASE_URL=your_supabase_url_here
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key_here
SUPABASE_ANON_KEY=your_supabase_anon_key_here

# User Configuration
USER_ID=your_user_id_here
USER_EMAIL=your_email_here

# Camera Configuration
CAMERA_ID=raspberry_pi_camera
CAMERA_NAME=Raspberry Pi Camera
CAMERA_LOCATION=Your Location
CAMERA_DEVICE=/dev/video0
CAMERA_WIDTH=1920
CAMERA_HEIGHT=1080
CAMERA_FPS=30

# Recording Configuration
RECORDING_DIR=$APP_DIR/recordings
LOG_DIR=$APP_DIR/logs
TEMP_DIR=$APP_DIR/temp
UPLOAD_DIR=$APP_DIR/uploads

# System Configuration
DEBUG=false
LOG_LEVEL=INFO
EOL
    chown "$SERVICE_USER:$SERVICE_GROUP" "$APP_DIR/.env"
    print_warning "Please edit $APP_DIR/.env with your actual configuration"
fi

# Create systemd service files
print_status "Creating systemd services..."

# Main service
cat > /etc/systemd/system/ezrec-backend.service << EOL
[Unit]
Description=EZREC Backend Service
After=network.target
Wants=ezrec-orchestrator.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$APP_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/python src/orchestrator.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-backend

[Install]
WantedBy=multi-user.target
EOL

# Orchestrator service
cat > /etc/systemd/system/ezrec-orchestrator.service << EOL
[Unit]
Description=EZREC Orchestrator Service
After=network.target
PartOf=ezrec-backend.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$APP_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/python src/orchestrator.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-orchestrator

[Install]
WantedBy=multi-user.target
EOL

# Scheduler service
cat > /etc/systemd/system/ezrec-scheduler.service << EOL
[Unit]
Description=EZREC Scheduler Service
After=network.target
PartOf=ezrec-backend.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$APP_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/python src/scheduler.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-scheduler

[Install]
WantedBy=multi-user.target
EOL

# Status service
cat > /etc/systemd/system/ezrec-status.service << EOL
[Unit]
Description=EZREC Status Service
After=network.target
PartOf=ezrec-backend.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$APP_DIR
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/python src/utils.py --status-service
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-status

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd
systemctl daemon-reload

# Enable services
print_status "Enabling services..."
systemctl enable ezrec-backend.service
systemctl enable ezrec-orchestrator.service
systemctl enable ezrec-scheduler.service
systemctl enable ezrec-status.service

# Set permissions
print_status "Setting final permissions..."
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$APP_DIR"
chmod -R 755 "$APP_DIR"
chmod -R 777 "$APP_DIR/temp" "$APP_DIR/recordings" "$APP_DIR/logs" "$APP_DIR/uploads"

# Create logrotate configuration
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/ezrec-backend << EOL
$APP_DIR/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_GROUP
    postrotate
        systemctl reload ezrec-backend.service
    endscript
}
EOL

# Create health check script
print_status "Creating health check script..."
cat > "$APP_DIR/health_check.sh" << 'EOL'
#!/bin/bash
# Health check script for EZREC Backend

APP_DIR="/opt/ezrec-backend"
SERVICE_USER="ezrec"

# Check if services are running
check_service() {
    local service_name=$1
    if systemctl is-active --quiet "$service_name"; then
        echo "✓ $service_name is running"
        return 0
    else
        echo "✗ $service_name is not running"
        return 1
    fi
}

# Check disk space
check_disk_space() {
    local usage=$(df "$APP_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$usage" -lt 90 ]; then
        echo "✓ Disk space OK: ${usage}% used"
        return 0
    else
        echo "✗ Disk space critical: ${usage}% used"
        return 1
    fi
}

# Check camera
check_camera() {
    if v4l2-ctl --list-devices | grep -q "video"; then
        echo "✓ Camera detected"
        return 0
    else
        echo "✗ No camera detected"
        return 1
    fi
}

# Main health check
echo "EZREC Backend Health Check"
echo "========================="

check_service "ezrec-backend.service"
check_service "ezrec-orchestrator.service"
check_service "ezrec-scheduler.service"
check_service "ezrec-status.service"
check_disk_space
check_camera

echo ""
echo "For detailed logs: journalctl -u ezrec-backend.service -f"
EOL

chmod +x "$APP_DIR/health_check.sh"

# Create management script
print_status "Creating management script..."
cat > "$APP_DIR/manage.sh" << 'EOL'
#!/bin/bash
# EZREC Backend Management Script

APP_DIR="/opt/ezrec-backend"
SERVICE_USER="ezrec"

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
        "$APP_DIR/health_check.sh"
        ;;
    update)
        echo "Updating EZREC Backend..."
        cd "$APP_DIR"
        git pull
        sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install -r requirements.txt
        systemctl restart ezrec-backend.service
        echo "Update complete!"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|health|update}"
        exit 1
        ;;
esac
EOL

chmod +x "$APP_DIR/manage.sh"

print_status "Installation completed successfully!"
echo ""
print_info "Next steps:"
echo "1. Edit the configuration file: sudo nano $APP_DIR/.env"
echo "2. Start the services: sudo $APP_DIR/manage.sh start"
echo "3. Check status: sudo $APP_DIR/manage.sh status"
echo "4. View logs: sudo $APP_DIR/manage.sh logs"
echo "5. Health check: sudo $APP_DIR/manage.sh health"
echo ""
print_warning "Make sure to configure your Supabase credentials in $APP_DIR/.env"
print_warning "The services will start automatically on boot" 