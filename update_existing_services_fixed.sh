#!/bin/bash

# EZREC Backend - Update Existing Services Script (Fixed)
# This script updates existing systemd services instead of creating new ones

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

echo "EZREC Backend - Update Existing Services (Fixed)"
echo "================================================"
echo ""

# Function to find existing services
find_existing_services() {
    local services=()
    local patterns=("smartcam" "ezrec" "camera" "orchestrator" "scheduler" "status")
    
    for pattern in "${patterns[@]}"; do
        local found=$(systemctl list-units --type=service --all | grep -i "$pattern" | awk '{print $1}' | sed 's/\.service$//')
        if [ ! -z "$found" ]; then
            services+=($found)
        fi
    done
    
    echo "${services[@]}"
}

# Function to find existing installation directory
find_existing_installation() {
    local dirs=(
        "/opt/ezrec-backend"
        "/opt/smartcam"
        "/home/michomanoly14892/code/SmartCam-Soccer"
        "/home/pi/code/EZREC-BackEnd"
        "/home/pi/SmartCam-Soccer"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ] && [ -f "$dir/main.py" ]; then
            echo "$dir"
            return 0
        fi
    done
    
    return 1
}

# Find existing services
print_status "Finding existing services..."
EXISTING_SERVICES=($(find_existing_services))

if [ ${#EXISTING_SERVICES[@]} -eq 0 ]; then
    print_warning "No existing services found. Running fresh installation..."
    exec ./raspberry_pi_setup.sh
fi

print_info "Found ${#EXISTING_SERVICES[@]} existing service(s):"
for service in "${EXISTING_SERVICES[@]}"; do
    status=$(systemctl is-active "$service.service" 2>/dev/null || echo "unknown")
    enabled=$(systemctl is-enabled "$service.service" 2>/dev/null || echo "unknown")
    print_info "  - $service.service (Status: $status, Enabled: $enabled)"
done

echo ""

# Find existing installation
print_status "Finding existing installation..."
EXISTING_DIR=$(find_existing_installation)

if [ -z "$EXISTING_DIR" ]; then
    print_error "No existing installation found. Please run the full setup first."
    exit 1
fi

print_info "Found existing installation at: $EXISTING_DIR"

# Check if we're in the right directory
CURRENT_DIR=$(pwd)
if [ "$CURRENT_DIR" != "$EXISTING_DIR" ]; then
    print_warning "You're not in the installation directory. Please run this from: $EXISTING_DIR"
    print_info "Current directory: $CURRENT_DIR"
    print_info "Expected directory: $EXISTING_DIR"
    exit 1
fi

# Backup existing configuration
print_status "Backing up existing configuration..."
BACKUP_DIR="/opt/ezrec-backend-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup .env file
if [ -f "$EXISTING_DIR/.env" ]; then
    cp "$EXISTING_DIR/.env" "$BACKUP_DIR/.env.backup"
    print_info "Backed up .env file"
else
    print_warning "No .env file found. Will create one."
fi

# Backup service files
for service in "${EXISTING_SERVICES[@]}"; do
    if [ -f "/etc/systemd/system/$service.service" ]; then
        cp "/etc/systemd/system/$service.service" "$BACKUP_DIR/$service.service.backup"
        print_info "Backed up $service.service"
    fi
done

echo ""

# Stop existing services
print_status "Stopping existing services..."
for service in "${EXISTING_SERVICES[@]}"; do
    if systemctl is-active --quiet "$service.service" 2>/dev/null; then
        systemctl stop "$service.service"
        print_info "Stopped $service.service"
    fi
done

echo ""

# Clean up disk space first
print_status "Cleaning up disk space..."
# Remove old recordings (older than 7 days)
find "$EXISTING_DIR/recordings" -name "*.mp4" -mtime +7 -delete 2>/dev/null || true
# Remove old logs (older than 30 days)
find "$EXISTING_DIR/logs" -name "*.log" -mtime +30 -delete 2>/dev/null || true
# Clean temp files
rm -rf "$EXISTING_DIR/temp"/* 2>/dev/null || true

print_info "Disk cleanup completed"

echo ""

# Update the existing installation
print_status "Updating existing installation..."

# Copy new files to existing directory (if they exist in current dir)
if [ -d "src" ]; then
    cp -r src/ "$EXISTING_DIR/"
    print_info "Updated src directory"
fi

if [ -f "main.py" ]; then
    cp main.py "$EXISTING_DIR/"
    print_info "Updated main.py"
fi

if [ -f "requirements.txt" ]; then
    cp requirements.txt "$EXISTING_DIR/"
    print_info "Updated requirements.txt"
fi

# Create necessary directories if they don't exist
mkdir -p "$EXISTING_DIR/recordings"
mkdir -p "$EXISTING_DIR/logs"
mkdir -p "$EXISTING_DIR/temp"
mkdir -p "$EXISTING_DIR/uploads"
mkdir -p "$EXISTING_DIR/user_assets"

# Update Python dependencies
print_status "Updating Python dependencies..."
cd "$EXISTING_DIR"

if [ -d "venv" ]; then
    # Update existing virtual environment
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    print_info "Updated existing virtual environment"
else
    # Create new virtual environment
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    print_info "Created new virtual environment"
fi

echo ""

# Create .env file if it doesn't exist
if [ ! -f "$EXISTING_DIR/.env" ]; then
    print_status "Creating .env file..."
    cat > "$EXISTING_DIR/.env" << EOL
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
RECORDING_DIR=$EXISTING_DIR/recordings
LOG_DIR=$EXISTING_DIR/logs
TEMP_DIR=$EXISTING_DIR/temp
UPLOAD_DIR=$EXISTING_DIR/uploads

# System Configuration
DEBUG=false
LOG_LEVEL=INFO
EOL
    print_warning "Created .env file. Please edit it with your actual configuration!"
fi

# Update systemd services
print_status "Updating systemd services..."

# Determine the service user from existing services
SERVICE_USER="michomanoly14892"
if [ -f "/etc/systemd/system/${EXISTING_SERVICES[0]}.service" ]; then
    SERVICE_USER=$(grep "^User=" "/etc/systemd/system/${EXISTING_SERVICES[0]}.service" | cut -d= -f2)
    if [ -z "$SERVICE_USER" ]; then
        SERVICE_USER="michomanoly14892"
    fi
fi

print_info "Using service user: $SERVICE_USER"

# Create updated service files
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

# Remove old service files
print_status "Removing old service files..."
for service in "${EXISTING_SERVICES[@]}"; do
    if [ -f "/etc/systemd/system/$service.service" ]; then
        rm "/etc/systemd/system/$service.service"
        print_info "Removed $service.service"
    fi
done

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
print_info "Backup location: $BACKUP_DIR"
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
print_warning "IMPORTANT: Edit your .env file with Supabase credentials:"
echo "  sudo nano $EXISTING_DIR/.env"
echo ""
print_warning "If you encounter issues, you can restore from backup:"
echo "  sudo cp $BACKUP_DIR/.env.backup $EXISTING_DIR/.env"
echo "  sudo systemctl restart ezrec-backend.service" 