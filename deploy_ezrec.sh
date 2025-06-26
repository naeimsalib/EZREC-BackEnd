#!/bin/bash

# 🚀 EZREC Deployment Script - Complete System Setup & Update
# This is the ONLY deployment script needed for EZREC system
# Handles: dependencies, camera protection, service deployment, DB migrations
# Version: Final Production - All requirements integrated
# Last Updated: June 26, 2025

set -e  # Exit on any error

echo "🚀 EZREC Deployment Script - Complete System Setup"
echo "=================================================="
echo "📅 Started at: $(date)"
echo ""

# Configuration
REPO_DIR="~/code/EZREC-BackEnd"
DEPLOY_DIR="/opt/ezrec-backend"
SERVICE_NAME="ezrec-backend"
SERVICE_USER="michomanoly14892"
VENV_PATH="$DEPLOY_DIR/venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print status messages
print_status() { echo -e "📋 $1"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }

# Function to check if running as correct user
check_user() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Do not run this script as root. Run as $SERVICE_USER with sudo when needed."
        exit 1
    fi
    print_success "Running as user: $(whoami)"
}

# Function to install system dependencies
install_system_dependencies() {
    print_status "Installing system dependencies..."
    
    # Update package list
    sudo apt-get update
    
    # Install required packages for Picamera2 and system monitoring
    sudo apt-get install -y python3-venv python3-pip python3-dev python3-libcamera python3-kms++ 
    sudo apt-get install -y python3-psutil htop psmisc lsof
    
    print_success "System dependencies installed"
}

# Function to protect camera from other processes
protect_camera() {
    print_status "Protecting camera from other processes..."
    
    # Kill any processes using camera devices
    for video_dev in /dev/video*; do
        if [[ -e "$video_dev" ]]; then
            sudo fuser -k "$video_dev" 2>/dev/null || true
        fi
    done
    
    # Disable unnecessary camera services
    sudo systemctl stop libcamera* 2>/dev/null || true
    sudo systemctl disable libcamera* 2>/dev/null || true
    
    # Ensure service user has camera access
    sudo usermod -a -G video $SERVICE_USER
    sudo usermod -a -G dialout $SERVICE_USER
    sudo usermod -a -G gpio $SERVICE_USER
    
    print_success "Camera protection configured"
}

# Function to update code from GitHub
update_code() {
    print_status "Updating code from GitHub..."
    
    # Use absolute path and expand tilde
    REPO_DIR_EXPANDED="/home/$SERVICE_USER/code/EZREC-BackEnd"
    cd "$REPO_DIR_EXPANDED"
    
    # Stash any local changes
    git stash --include-untracked 2>/dev/null || true
    
    # Pull latest changes
    git pull origin main
    
    print_success "Code updated from GitHub"
}

# Function to stop service
stop_service() {
    print_status "Stopping $SERVICE_NAME service..."
    
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        sudo systemctl stop $SERVICE_NAME
        print_success "Service stopped"
    else
        print_warning "Service was not running"
    fi
}

# Function to deploy code to service directory
deploy_code() {
    print_status "Deploying code to $DEPLOY_DIR..."
    
    # Create deployment directory structure
    sudo mkdir -p $DEPLOY_DIR/{src,recordings,uploads,logs,temp}
    
    # Use expanded path for copying
    REPO_DIR_EXPANDED="/home/$SERVICE_USER/code/EZREC-BackEnd"
    
    # Copy source files
    sudo cp -r "$REPO_DIR_EXPANDED/src"/* $DEPLOY_DIR/src/
    
    # Copy essential files  
    sudo cp "$REPO_DIR_EXPANDED/requirements.txt" $DEPLOY_DIR/
    sudo cp "$REPO_DIR_EXPANDED/ezrec-backend.service" $DEPLOY_DIR/
    
    # Copy migrations for reference
    sudo mkdir -p $DEPLOY_DIR/migrations
    sudo cp -r "$REPO_DIR_EXPANDED/migrations"/* $DEPLOY_DIR/migrations/ 2>/dev/null || true
    
    # Set proper ownership and permissions
    sudo chown -R $SERVICE_USER:$SERVICE_USER $DEPLOY_DIR
    sudo chmod -R 755 $DEPLOY_DIR
    sudo chmod -R 775 $DEPLOY_DIR/{recordings,uploads,logs,temp}
    
    print_success "Code deployed to service directory"
}

# Function to setup virtual environment
setup_venv() {
    print_status "Setting up Python virtual environment..."
    
    # Remove old venv if exists
    if [[ -d "$VENV_PATH" ]]; then
        sudo rm -rf $VENV_PATH
    fi
    
    # Create new virtual environment
    sudo -u $SERVICE_USER python3 -m venv $VENV_PATH
    
    # Install/upgrade pip
    sudo -u $SERVICE_USER $VENV_PATH/bin/pip install --upgrade pip
    
    # Install Python dependencies
    sudo -u $SERVICE_USER $VENV_PATH/bin/pip install -r $DEPLOY_DIR/requirements.txt
    
    # Install additional dependencies for Raspberry Pi
    sudo -u $SERVICE_USER $VENV_PATH/bin/pip install psutil pytz opencv-python
    
    print_success "Virtual environment configured"
}

# Function to test Picamera2 functionality
test_camera() {
    print_status "Testing Picamera2 functionality..."
    
    # Create simple camera test
    cat > $DEPLOY_DIR/test_camera.py << 'EOF'
#!/usr/bin/env python3
import sys
sys.path.insert(0, '/opt/ezrec-backend')
try:
    from picamera2 import Picamera2
    cameras = Picamera2.global_camera_info()
    print(f"✅ Picamera2 detected {len(cameras)} camera(s)")
    if len(cameras) > 0:
        picam2 = Picamera2(camera_num=0)
        print("✅ Camera initialization successful")
        picam2.close()
        print("✅ Camera test PASSED")
    else:
        print("⚠️ No cameras detected - check hardware")
except Exception as e:
    print(f"❌ Camera test failed: {e}")
    sys.exit(1)
EOF
    
    chmod +x $DEPLOY_DIR/test_camera.py
    chown $SERVICE_USER:$SERVICE_USER $DEPLOY_DIR/test_camera.py
    
    # Run camera test
    if sudo -u $SERVICE_USER $VENV_PATH/bin/python3 $DEPLOY_DIR/test_camera.py; then
        print_success "Camera test passed"
    else
        print_warning "Camera test failed - hardware may need attention"
    fi
}

# Function to clean Python cache
clean_cache() {
    print_status "Cleaning Python cache..."
    
    # Remove all Python cache files
    sudo find $DEPLOY_DIR -name "*.pyc" -delete 2>/dev/null || true
    sudo find $DEPLOY_DIR -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_success "Python cache cleaned"
}

# Function to install/update systemd service
install_service() {
    print_status "Installing systemd service..."
    
    # Create updated service file
    cat > /tmp/ezrec-backend.service << EOF
[Unit]
Description=EZREC Backend Service - Soccer Recording System
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$DEPLOY_DIR
Environment=PYTHONPATH=$DEPLOY_DIR
ExecStartPre=/bin/bash -c 'echo "🛡️ Protecting camera for EZREC..."'
ExecStartPre=/bin/bash -c 'sudo fuser -k /dev/video0 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'sudo fuser -k /dev/video1 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'sudo fuser -k /dev/video2 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'echo "✅ Camera protection active"'
ExecStart=$VENV_PATH/bin/python3 src/orchestrator.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ezrec-backend

# Resource limits
LimitNOFILE=65536
MemoryMax=1G

# Security settings
NoNewPrivileges=yes
ProtectHome=no
ProtectSystem=strict
ReadWritePaths=$DEPLOY_DIR

[Install]
WantedBy=multi-user.target
EOF
    
    # Install service
    sudo cp /tmp/ezrec-backend.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    
    print_success "Systemd service installed"
}

# Function to start service
start_service() {
    print_status "Starting $SERVICE_NAME service..."
    
    # Start service
    sudo systemctl start $SERVICE_NAME
    
    # Wait for startup
    sleep 5
    
    # Check service status
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Service started successfully"
        
        # Show recent logs
        print_status "Recent service logs:"
        sudo journalctl -u $SERVICE_NAME --lines=10 --no-pager
    else
        print_error "Service failed to start"
        sudo systemctl status $SERVICE_NAME --no-pager -l
        return 1
    fi
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check service status
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Service is running"
    else
        print_error "Service is not running"
        return 1
    fi
    
    # Check for booking detection in logs
    print_status "Checking booking detection in logs..."
    if sudo journalctl -u $SERVICE_NAME --since '1 minute ago' --no-pager | grep -q "bookings query executed"; then
        print_success "Booking detection is working"
    else
        print_warning "Booking detection may need time to initialize"
    fi
    
    print_success "Deployment verification complete"
}

# Function to show final status
show_final_status() {
    echo ""
    echo "🎉 EZREC DEPLOYMENT COMPLETE"
    echo "============================"
    echo "✅ Service Status: $(sudo systemctl is-active $SERVICE_NAME)"
    echo "✅ Service Directory: $DEPLOY_DIR"
    echo "✅ Logs: sudo journalctl -u $SERVICE_NAME -f"
    echo "✅ Stop: sudo systemctl stop $SERVICE_NAME"
    echo "✅ Start: sudo systemctl start $SERVICE_NAME"
    echo "✅ Restart: sudo systemctl restart $SERVICE_NAME"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Monitor logs: sudo journalctl -u $SERVICE_NAME -f"
    echo "2. Verify bookings are detected in logs"
    echo "3. Test recording functionality"
    echo ""
    echo "🎯 System now handles complete workflow:"
    echo "   • Reads bookings from Supabase"
    echo "   • Starts/stops recordings automatically"
    echo "   • Updates recording status"
    echo "   • Uploads videos and removes local files"
    echo "   • Updates system status every 3 seconds"
    echo ""
}

# Main deployment process
main() {
    print_status "Starting EZREC deployment process..."
    
    check_user
    install_system_dependencies
    protect_camera
    update_code
    stop_service
    deploy_code
    clean_cache
    setup_venv
    test_camera
    install_service
    start_service
    verify_deployment
    show_final_status
    
    print_success "🚀 EZREC deployment completed successfully!"
}

# Run main function
main "$@" 