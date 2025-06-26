#!/bin/bash

# 🚀 EZREC Deployment Script - Complete Production Deployment
# Deploys code from ~/code/EZREC-BackEnd to /opt/ezrec-backend
# Version: Enhanced Production Deployment

set -e  # Exit on any error

echo "🚀 EZREC PRODUCTION DEPLOYMENT"
echo "=============================="
echo "📅 Started at: $(date)"
echo ""

# Configuration
USER_HOME="/home/michomanoly14892"
REPO_DIR="$USER_HOME/code/EZREC-BackEnd"
DEPLOY_DIR="/opt/ezrec-backend"
SERVICE_NAME="ezrec-backend"
SERVICE_USER="michomanoly14892"
VENV_PATH="$REPO_DIR/venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print status messages
print_status() { echo -e "${BLUE}📋 $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }

# Check if running as correct user
if [[ "$USER" != "$SERVICE_USER" ]]; then
    print_error "Must run as user: $SERVICE_USER"
    exit 1
fi

# Verify repository exists
if [[ ! -d "$REPO_DIR" ]]; then
    print_error "Repository directory not found: $REPO_DIR"
    print_status "Please run: cd ~/code && git clone <repo-url> EZREC-BackEnd"
    exit 1
fi

# Verify virtual environment exists
if [[ ! -f "$VENV_PATH/bin/python3" ]]; then
    print_warning "Virtual environment not found, creating..."
    cd "$REPO_DIR"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    print_success "Virtual environment created and configured"
fi

# Verify .env file exists
if [[ ! -f "$REPO_DIR/.env" ]]; then
    print_error ".env file not found in repository"
    print_status "Please create .env file with Supabase credentials"
    exit 1
fi

print_status "Stopping $SERVICE_NAME service..."
sudo systemctl stop $SERVICE_NAME 2>/dev/null || print_warning "Service was not running"

print_status "Creating deployment directories..."
sudo mkdir -p $DEPLOY_DIR/{recordings,uploads,logs,temp}

print_status "Copying application files..."
# Copy main application files
sudo cp "$REPO_DIR/main.py" $DEPLOY_DIR/
sudo cp "$REPO_DIR/system_status.py" $DEPLOY_DIR/
sudo cp "$REPO_DIR/requirements.txt" $DEPLOY_DIR/
sudo cp "$REPO_DIR/.env" $DEPLOY_DIR/

print_status "Installing/updating systemd service..."
sudo cp "$REPO_DIR/ezrec-backend.service" /etc/systemd/system/

print_status "Setting ownership and permissions..."
sudo chown -R $SERVICE_USER:$SERVICE_USER $DEPLOY_DIR
sudo chmod -R 755 $DEPLOY_DIR
sudo chmod -R 775 $DEPLOY_DIR/{recordings,uploads,logs,temp}
sudo chmod +x $DEPLOY_DIR/main.py $DEPLOY_DIR/system_status.py

print_status "Reloading systemd and enabling service..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

print_status "Starting service..."
sudo systemctl start $SERVICE_NAME

# Wait for startup and check status
print_status "Waiting for service to initialize..."
sleep 5

# Check service status
if sudo systemctl is-active --quiet $SERVICE_NAME; then
    print_success "Service started successfully"
    
    print_status "Service status:"
    sudo systemctl status $SERVICE_NAME --no-pager -l
    
    echo ""
    print_status "Recent service logs:"
    sudo journalctl -u $SERVICE_NAME --lines=15 --no-pager
    
else
    print_error "Service failed to start"
    echo ""
    print_status "Service status:"
    sudo systemctl status $SERVICE_NAME --no-pager -l
    echo ""
    print_status "Service logs:"
    sudo journalctl -u $SERVICE_NAME --lines=20 --no-pager
    exit 1
fi

echo ""
echo "🎉 EZREC DEPLOYMENT COMPLETE"
echo "============================"
echo "✅ Service Status: $(sudo systemctl is-active $SERVICE_NAME)"
echo "✅ Service Enabled: $(sudo systemctl is-enabled $SERVICE_NAME)"
echo ""
echo "📊 Monitoring Commands:"
echo "  View logs: sudo journalctl -u $SERVICE_NAME -f"
echo "  Service status: sudo systemctl status $SERVICE_NAME"
echo "  Stop service: sudo systemctl stop $SERVICE_NAME"
echo "  Start service: sudo systemctl start $SERVICE_NAME"
echo "  Restart service: sudo systemctl restart $SERVICE_NAME"
echo ""
echo "📁 Deployment structure:"
echo "  Development: $REPO_DIR"
echo "  Production: $DEPLOY_DIR"
echo "  Virtual Env: $VENV_PATH"
echo ""
print_success "🚀 Deployment completed successfully!"
print_status "Monitor the logs to verify proper operation."
