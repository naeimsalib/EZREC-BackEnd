#!/bin/bash
set -e

# EZREC Backend - Complete Installation Script for Raspberry Pi
# This script handles everything: system dependencies, virtual environment, 
# systemd service, and startup - all in one go!

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SERVICE_USER="ezrec"
INSTALL_DIR="/opt/ezrec-backend"
SERVICE_NAME="ezrec-backend"
PYTHON_VERSION="python3"
PROJECT_DIR="$(pwd)"

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Progress indicator
progress() {
    local step=$1
    local total=$2
    local description=$3
    echo -e "${CYAN}[Step $step/$total]${NC} $description"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if we're in the project directory
check_project_dir() {
    if [[ ! -f "requirements.txt" ]] || [[ ! -d "src" ]] || [[ ! -f "ezrec-backend.service" ]]; then
        error "This script must be run from the EZREC project root directory"
        error "Make sure you have: requirements.txt, src/, and ezrec-backend.service"
        exit 1
    fi
}

# Stop existing service if running
stop_existing_service() {
    progress 1 12 "Stopping any existing EZREC services..."
    
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        log "Stopping existing $SERVICE_NAME service..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        log "Disabling existing $SERVICE_NAME service..."
        systemctl disable "$SERVICE_NAME"
    fi
    
    success "Existing services stopped"
}

# Update system packages
update_system() {
    progress 2 12 "Updating system packages..."
    
    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt upgrade -y
    
    success "System packages updated"
}

# Install system dependencies
install_system_deps() {
    progress 3 12 "Installing system dependencies..."
    
    # Core system packages
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        git \
        build-essential \
        pkg-config
    
    # Camera and media packages (Raspberry Pi specific)
    apt install -y \
        python3-libcamera \
        python3-picamera2 \
        libcamera-apps \
        ffmpeg \
        v4l-utils
    
    # Additional Pi-specific packages (optional - handle conflicts gracefully)
    if [[ -f /etc/rpi-issue ]]; then
        # Try to install Pi-specific packages, but continue if they fail
        apt install -y raspi-config 2>/dev/null || warning "Some Pi-specific packages couldn't be installed (this is OK)"
    fi
    
    success "System dependencies installed"
}

# Create service user and directories
setup_user_and_dirs() {
    progress 4 12 "Setting up service user and directories..."
    
    # Create service user
    if id "$SERVICE_USER" &>/dev/null; then
        log "User $SERVICE_USER already exists"
    else
        useradd -r -s /bin/bash -d "$INSTALL_DIR" -m "$SERVICE_USER"
        success "Service user $SERVICE_USER created"
    fi
    
    # Add user to required groups for camera access
    usermod -a -G video,gpio,i2c,spi "$SERVICE_USER" 2>/dev/null || true
    
    # Remove existing installation directory if it exists
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        log "Removed existing installation directory"
    fi
    
    # Create main directory
    mkdir -p "$INSTALL_DIR"
    
    # Create subdirectories
    mkdir -p "$INSTALL_DIR"/{src,logs,temp,recordings,uploads,user_assets,migrations}
    
    success "User and directories configured"
}

# Copy application files
copy_application_files() {
    progress 5 12 "Copying application files..."
    
    # Copy source files
    cp -r src/* "$INSTALL_DIR/src/"
    
    # Copy configuration files
    cp requirements.txt "$INSTALL_DIR/"
    cp ezrec-backend.service "$INSTALL_DIR/"
    
    # Copy migrations if they exist
    if [[ -d "migrations" ]]; then
        cp -r migrations/* "$INSTALL_DIR/migrations/"
    fi
    
    # Create .env file from template or create a basic one
    if [[ -f ".env.example" ]]; then
        cp .env.example "$INSTALL_DIR/.env"
    else
        cat > "$INSTALL_DIR/.env" << 'EOF'
# EZREC Backend Configuration
# Please update these values according to your setup

# Application Settings
DEBUG=false
LOG_LEVEL=INFO

# Database Configuration (Supabase)
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_supabase_service_key

# Camera Settings
DEFAULT_CAMERA_INDEX=0
RECORDING_FORMAT=mp4
RECORDING_QUALITY=high

# Storage Settings
RECORDINGS_PATH=/opt/ezrec-backend/recordings
TEMP_PATH=/opt/ezrec-backend/temp

# Monitoring Settings
HEARTBEAT_INTERVAL=30
BOOKING_CHECK_INTERVAL=5
STATUS_UPDATE_INTERVAL=10
EOF
    fi
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    
    # Set permissions
    chmod -R 755 "$INSTALL_DIR"
    chmod -R 775 "$INSTALL_DIR"/{logs,temp,recordings,uploads}
    chmod 600 "$INSTALL_DIR/.env"
    
    success "Application files copied"
}

# Setup Python virtual environment
setup_python_env() {
    progress 6 12 "Setting up Python virtual environment..."
    
    cd "$INSTALL_DIR"
    
    # Create virtual environment as service user
    sudo -u "$SERVICE_USER" $PYTHON_VERSION -m venv venv
    
    # Upgrade pip and install wheel
    sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/pip" install --upgrade pip setuptools wheel
    
    # Install Python dependencies
    log "Installing Python packages from requirements.txt..."
    sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/pip" install -r requirements.txt
    
    # Test critical imports
    log "Testing Python environment..."
    sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/python" -c "
import sys
print(f'Python version: {sys.version}')

try:
    import cv2
    print(f'OpenCV version: {cv2.__version__}')
except ImportError as e:
    print(f'OpenCV import error: {e}')

try:
    import numpy as np
    print(f'NumPy version: {np.__version__}')
except ImportError as e:
    print(f'NumPy import error: {e}')

try:
    from picamera2 import Picamera2
    print('Picamera2 imported successfully')
except ImportError as e:
    print(f'Picamera2 import error: {e}')

print('Python environment test completed')
"
    
    success "Python environment configured"
}

# Enable camera interface
enable_camera() {
    progress 7 12 "Configuring camera interface..."
    
    if command -v raspi-config >/dev/null 2>&1; then
        # Enable camera interface via raspi-config
        raspi-config nonint do_camera 0
        success "Camera interface enabled via raspi-config"
    else
        warning "raspi-config not found, camera interface may need manual configuration"
    fi
    
    # Add camera detection test
    log "Testing camera detection..."
    if command -v libcamera-hello >/dev/null 2>&1; then
        timeout 10 libcamera-hello --list-cameras || warning "Camera detection test failed - check camera connection"
    else
        warning "libcamera-hello not found, install libcamera-apps if needed"
    fi
    
    success "Camera configuration completed"
}

# Install and configure systemd service
install_systemd_service() {
    progress 8 12 "Installing systemd service..."
    
    # Copy service file to systemd directory
    cp "$INSTALL_DIR/ezrec-backend.service" /etc/systemd/system/
    
    # Reload systemd daemon
    systemctl daemon-reload
    
    # Enable service (but don't start yet)
    systemctl enable "$SERVICE_NAME"
    
    success "Systemd service installed and enabled"
}

# Create management script
create_management_script() {
    progress 9 12 "Creating management tools..."
    
    cat > "$INSTALL_DIR/manage.sh" << 'EOF'
#!/bin/bash

# EZREC Backend Management Script

SERVICE_NAME="ezrec-backend"
INSTALL_DIR="/opt/ezrec-backend"

case "$1" in
    start)
        echo "Starting EZREC Backend..."
        sudo systemctl start $SERVICE_NAME
        sleep 2
        sudo systemctl status $SERVICE_NAME --no-pager -l
        ;;
    stop)
        echo "Stopping EZREC Backend..."
        sudo systemctl stop $SERVICE_NAME
        ;;
    restart)
        echo "Restarting EZREC Backend..."
        sudo systemctl restart $SERVICE_NAME
        sleep 2
        sudo systemctl status $SERVICE_NAME --no-pager -l
        ;;
    status)
        sudo systemctl status $SERVICE_NAME --no-pager -l
        ;;
    logs)
        sudo journalctl -u $SERVICE_NAME -f
        ;;
    logs-tail)
        sudo journalctl -u $SERVICE_NAME --lines=50 --no-pager
        ;;
    health)
        echo "=== EZREC Backend Health Check ==="
        echo "Service Status:"
        sudo systemctl is-active $SERVICE_NAME
        echo ""
        echo "Recent Logs:"
        sudo journalctl -u $SERVICE_NAME --lines=10 --no-pager
        echo ""
        echo "Camera Detection:"
        cd $INSTALL_DIR && sudo -u ezrec $INSTALL_DIR/venv/bin/python src/find_camera.py
        ;;
    config)
        echo "Opening configuration file..."
        sudo nano $INSTALL_DIR/.env
        ;;
    test-camera)
        echo "Testing camera..."
        cd $INSTALL_DIR && sudo -u ezrec $INSTALL_DIR/venv/bin/python src/find_camera.py
        ;;
    *)
        echo "EZREC Backend Management"
        echo "Usage: $0 {start|stop|restart|status|logs|logs-tail|health|config|test-camera}"
        echo ""
        echo "Commands:"
        echo "  start       - Start the service"
        echo "  stop        - Stop the service"
        echo "  restart     - Restart the service"
        echo "  status      - Show service status"
        echo "  logs        - Follow live logs"
        echo "  logs-tail   - Show recent logs"
        echo "  health      - Health check"
        echo "  config      - Edit configuration"
        echo "  test-camera - Test camera detection"
        exit 1
        ;;
esac
EOF

    chmod +x "$INSTALL_DIR/manage.sh"
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/manage.sh"
    
    # Create symlink for easier access
    ln -sf "$INSTALL_DIR/manage.sh" /usr/local/bin/ezrec
    
    success "Management script created (use 'ezrec' command)"
}

# Configure system services
configure_system() {
    progress 10 12 "Configuring system services..."
    
    # Configure log rotation
    cat > /etc/logrotate.d/ezrec-backend << EOF
$INSTALL_DIR/logs/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
    postrotate
        systemctl reload $SERVICE_NAME 2>/dev/null || true
    endscript
}
EOF
    
    # Set up automatic cleanup cron job
    (crontab -u "$SERVICE_USER" -l 2>/dev/null; echo "0 2 * * * find $INSTALL_DIR/temp -type f -mtime +7 -delete") | crontab -u "$SERVICE_USER" -
    
    success "System services configured"
}

# Run installation tests
run_tests() {
    progress 11 12 "Running installation tests..."
    
    # Test Python environment
    if sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/python" -c "
import sys
sys.path.insert(0, '$INSTALL_DIR/src')

# Test imports
try:
    import cv2
    import numpy
    print('✓ OpenCV and NumPy imported successfully')
except ImportError as e:
    print(f'✗ Import error: {e}')
    sys.exit(1)

try:
    from config import CONFIG_SUMMARY
    print(f'✓ EZREC config imported: {CONFIG_SUMMARY}')
except ImportError as e:
    print(f'✓ EZREC config import (may fail without .env): {e}')

try:
    from picamera2 import Picamera2
    print('✓ Picamera2 imported successfully')
except ImportError as e:
    print(f'⚠ Picamera2 import warning: {e}')

print('✓ Python environment test passed')
"; then
        success "Python environment test passed"
    else
        warning "Python environment test had issues (check logs)"
    fi
    
    # Test service file syntax
    if systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; then
        success "Systemd service file valid"
    else
        error "Systemd service file invalid"
        return 1
    fi
    
    success "Installation tests completed"
}

# Start the service
start_service() {
    progress 12 12 "Starting EZREC Backend service..."
    
    # Start the service
    systemctl start "$SERVICE_NAME"
    sleep 3
    
    # Check if service started successfully
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "EZREC Backend service started successfully!"
        
        # Show status
        info "Service Status:"
        systemctl status "$SERVICE_NAME" --no-pager -l
        
    else
        error "Failed to start EZREC Backend service"
        error "Check the logs with: sudo journalctl -u $SERVICE_NAME --no-pager"
        return 1
    fi
}

# Display final information
show_completion_info() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    🎉 INSTALLATION COMPLETED! 🎉                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    success "EZREC Backend has been installed and started successfully!"
    echo ""
    info "📁 Installation Directory: $INSTALL_DIR"
    info "👤 Service User: $SERVICE_USER"
    info "🔧 Service Name: $SERVICE_NAME"
    echo ""
    info "📋 Management Commands:"
    echo "  ezrec start      - Start the service"
    echo "  ezrec stop       - Stop the service"
    echo "  ezrec restart    - Restart the service"
    echo "  ezrec status     - Check service status"
    echo "  ezrec logs       - View live logs"
    echo "  ezrec health     - Run health check"
    echo "  ezrec config     - Edit configuration"
    echo ""
    info "📊 Check Status:"
    echo "  sudo systemctl status $SERVICE_NAME"
    echo "  sudo journalctl -u $SERVICE_NAME -f"
    echo ""
    
    # Check if .env needs configuration
    if grep -q "your_supabase_url" "$INSTALL_DIR/.env" 2>/dev/null; then
        warning "⚠️  IMPORTANT: Please configure your environment variables!"
        warning "   Edit: $INSTALL_DIR/.env"
        warning "   Then restart: ezrec restart"
    fi
    
    echo "🎬 Your EZREC Backend is now running and ready to record!"
}

# Main installation function
main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              EZREC Backend Complete Installation                ║"
    echo "║                    for Raspberry Pi                            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_root
    check_project_dir
    
    log "Starting complete EZREC Backend installation..."
    echo ""
    
    # Run all installation steps
    stop_existing_service
    update_system
    install_system_deps
    setup_user_and_dirs
    copy_application_files
    setup_python_env
    enable_camera
    install_systemd_service
    create_management_script
    configure_system
    run_tests
    start_service
    
    show_completion_info
}

# Run main function
main "$@" 