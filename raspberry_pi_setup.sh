#!/bin/bash
set -e

# EZREC Backend - Raspberry Pi Setup Script
# Optimized installation and configuration for Raspberry Pi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_USER="ezrec"
INSTALL_DIR="/opt/ezrec-backend"
SERVICE_NAME="ezrec-backend"
PYTHON_VERSION="python3"

# Logging function
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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if running on Raspberry Pi OS
check_platform() {
    if [[ ! -f /etc/rpi-issue ]]; then
        warning "This script is optimized for Raspberry Pi OS"
        warning "Continuing anyway, but some features may not work correctly"
    fi
}

# Update system packages
update_system() {
    log "Updating system packages..."
    apt update
    apt upgrade -y
    success "System packages updated"
}

# Install system dependencies
install_system_deps() {
    log "Installing system dependencies..."
    
    # Core system packages
    apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        git \
        curl \
        wget \
        unzip \
        build-essential \
        pkg-config
    
    # Camera and media packages
    apt install -y \
        python3-opencv \
        python3-libcamera \
        python3-picamera2 \
        libcamera-apps \
        ffmpeg \
        v4l-utils \
        libopencv-dev \
        libatlas-base-dev
    
    # Additional Pi-specific packages
    apt install -y \
        libraspberrypi-bin \
        raspi-config
    
    success "System dependencies installed"
}

# Create service user
create_service_user() {
    log "Creating service user: $SERVICE_USER"
    
    if id "$SERVICE_USER" &>/dev/null; then
        log "User $SERVICE_USER already exists"
    else
        useradd -r -s /bin/bash -d "$INSTALL_DIR" -m "$SERVICE_USER"
        # Add user to video group for camera access
        usermod -a -G video "$SERVICE_USER"
        success "Service user $SERVICE_USER created"
    fi
}

# Setup application directories
setup_directories() {
    log "Setting up application directories..."
    
    # Create main directory
    mkdir -p "$INSTALL_DIR"
    
    # Create subdirectories
    mkdir -p "$INSTALL_DIR"/{src,logs,temp,recordings,uploads,user_assets}
    
    # Copy application files
    if [[ -d "src" ]]; then
        cp -r src/* "$INSTALL_DIR/src/"
        log "Application source files copied"
    else
        error "Source directory not found. Make sure you're running this from the project root."
        exit 1
    fi
    
    # Copy configuration files
    cp requirements.txt "$INSTALL_DIR/"
    if [[ -f ".env.example" ]]; then
        cp .env.example "$INSTALL_DIR/"
    fi
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    
    # Set permissions
    chmod -R 755 "$INSTALL_DIR"
    chmod -R 775 "$INSTALL_DIR"/{logs,temp,recordings,uploads}
    
    success "Application directories configured"
}

# Setup Python virtual environment
setup_python_env() {
    log "Setting up Python virtual environment..."
    
    cd "$INSTALL_DIR"
    
    # Create virtual environment as service user
    sudo -u "$SERVICE_USER" $PYTHON_VERSION -m venv venv
    
    # Upgrade pip
    sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/pip" install --upgrade pip setuptools wheel
    
    # Install Python dependencies
    sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/pip" install -r requirements.txt
    
    success "Python environment configured"
}

# Configure environment file
configure_environment() {
    log "Configuring environment file..."
    
    if [[ ! -f "$INSTALL_DIR/.env" ]]; then
        if [[ -f "$INSTALL_DIR/.env.example" ]]; then
            cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
            chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/.env"
            chmod 600 "$INSTALL_DIR/.env"
            
            warning "Environment file created from example. Please edit $INSTALL_DIR/.env with your configuration."
        else
            error "No .env.example file found"
        fi
    else
        log "Environment file already exists"
    fi
}

# Install systemd service
install_systemd_service() {
    log "Installing systemd service..."
    
    # Copy service file
    if [[ -f "ezrec-backend.service" ]]; then
        cp ezrec-backend.service /etc/systemd/system/
        
        # Reload systemd
        systemctl daemon-reload
        
        # Enable service
        systemctl enable "$SERVICE_NAME"
        
        success "Systemd service installed and enabled"
    else
        error "Service file ezrec-backend.service not found"
        exit 1
    fi
}

# Create management script
create_management_script() {
    log "Creating management script..."
    
    cat > "$INSTALL_DIR/manage.sh" << 'EOF'
#!/bin/bash

# EZREC Backend Management Script

SERVICE_NAME="ezrec-backend"
INSTALL_DIR="/opt/ezrec-backend"

case "$1" in
    start)
        echo "Starting EZREC Backend..."
        sudo systemctl start $SERVICE_NAME
        ;;
    stop)
        echo "Stopping EZREC Backend..."
        sudo systemctl stop $SERVICE_NAME
        ;;
    restart)
        echo "Restarting EZREC Backend..."
        sudo systemctl restart $SERVICE_NAME
        ;;
    status)
        sudo systemctl status $SERVICE_NAME
        ;;
    logs)
        sudo journalctl -u $SERVICE_NAME -f
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
    update)
        echo "Updating EZREC Backend..."
        cd $INSTALL_DIR
        git pull
        sudo -u ezrec $INSTALL_DIR/venv/bin/pip install -r requirements.txt
        sudo systemctl restart $SERVICE_NAME
        echo "Update complete"
        ;;
    config)
        echo "Opening configuration file..."
        sudo nano $INSTALL_DIR/.env
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|health|update|config}"
        exit 1
        ;;
esac
EOF

    chmod +x "$INSTALL_DIR/manage.sh"
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/manage.sh"
    
    # Create symlink for easier access
    ln -sf "$INSTALL_DIR/manage.sh" /usr/local/bin/ezrec
    
    success "Management script created"
}

# Enable camera interface
enable_camera() {
    log "Checking camera interface..."
    
    if command -v raspi-config >/dev/null 2>&1; then
        # Enable camera interface via raspi-config
        raspi-config nonint do_camera 0
        log "Camera interface enabled"
    else
        log "raspi-config not found, camera interface may need manual configuration"
    fi
    
    # Check if camera is detected
    if command -v libcamera-hello >/dev/null 2>&1; then
        log "Testing camera detection..."
        timeout 10 libcamera-hello --list-cameras || warning "Camera detection test failed"
    fi
}

# Final system configuration
final_configuration() {
    log "Performing final configuration..."
    
    # Configure log rotation
    cat > /etc/logrotate.d/ezrec-backend << EOF
$INSTALL_DIR/logs/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
}
EOF
    
    # Set up automatic log cleanup
    (crontab -u "$SERVICE_USER" -l 2>/dev/null; echo "0 2 * * * find $INSTALL_DIR/temp -type f -mtime +7 -delete") | crontab -u "$SERVICE_USER" -
    
    success "Final configuration completed"
}

# Test installation
test_installation() {
    log "Testing installation..."
    
    # Test Python environment
    if sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/python" -c "import cv2, numpy; print('Python environment OK')"; then
        success "Python environment test passed"
    else
        error "Python environment test failed"
        return 1
    fi
    
    # Test camera detection
    if sudo -u "$SERVICE_USER" "$INSTALL_DIR/venv/bin/python" "$INSTALL_DIR/src/find_camera.py" >/dev/null 2>&1; then
        success "Camera detection test passed"
    else
        warning "Camera detection test failed - check camera connection"
    fi
    
    success "Installation tests completed"
}

# Main installation function
main() {
    log "Starting EZREC Backend installation..."
    
    check_root
    check_platform
    update_system
    install_system_deps
    create_service_user
    setup_directories
    setup_python_env
    configure_environment
    install_systemd_service
    create_management_script
    enable_camera
    final_configuration
    test_installation
    
    success "Installation completed successfully!"
    
    echo ""
    log "Next steps:"
    echo "1. Edit configuration: sudo nano $INSTALL_DIR/.env"
    echo "2. Start the service: sudo systemctl start $SERVICE_NAME"
    echo "3. Check status: sudo systemctl status $SERVICE_NAME"
    echo "4. View logs: sudo journalctl -u $SERVICE_NAME -f"
    echo ""
    echo "Management commands:"
    echo "  ezrec start|stop|restart|status|logs|health|update|config"
    echo ""
    
    if [[ ! -f "$INSTALL_DIR/.env" ]] || grep -q "your_" "$INSTALL_DIR/.env"; then
        warning "Don't forget to configure your environment variables in $INSTALL_DIR/.env"
    fi
}

# Run main function
main "$@" 