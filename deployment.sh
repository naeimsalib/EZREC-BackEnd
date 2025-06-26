#!/bin/bash

# 🚀 EZREC Deployment Script - Simplified Structure
# Deploys code from ~/code/EZREC-BackEnd to /opt/ezrec-backend
# Version: Production Clean Structure

set -e  # Exit on any error

echo "🚀 EZREC Deployment - Simplified Structure"
echo "=========================================="
echo "📅 Started at: $(date)"
echo ""

# Configuration
REPO_DIR="~/code/EZREC-BackEnd"
DEPLOY_DIR="/opt/ezrec-backend"
SERVICE_NAME="ezrec-backend"
SERVICE_USER="michomanoly14892"

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

print_status "Stopping $SERVICE_NAME service..."
sudo systemctl stop $SERVICE_NAME 2>/dev/null || print_warning "Service was not running"

print_status "Copying code to $DEPLOY_DIR..."

# Ensure deployment directory exists
sudo mkdir -p $DEPLOY_DIR/{recordings,uploads,logs,temp}

# Expand tilde in path
REPO_DIR_EXPANDED="/home/$SERVICE_USER/code/EZREC-BackEnd"

# Copy only the required files for clean structure
print_status "Copying main files..."
sudo cp "$REPO_DIR_EXPANDED/main.py" $DEPLOY_DIR/
sudo cp "$REPO_DIR_EXPANDED/system_status.py" $DEPLOY_DIR/
sudo cp "$REPO_DIR_EXPANDED/requirements.txt" $DEPLOY_DIR/
sudo cp "$REPO_DIR_EXPANDED/ezrec-backend.service" $DEPLOY_DIR/

# Copy .env if it exists in repo (otherwise deployment script will create it)
if [[ -f "$REPO_DIR_EXPANDED/.env" ]]; then
    sudo cp "$REPO_DIR_EXPANDED/.env" $DEPLOY_DIR/
    print_success ".env file copied from repo"
fi

print_status "Setting proper ownership and permissions..."
sudo chown -R $SERVICE_USER:$SERVICE_USER $DEPLOY_DIR
sudo chmod -R 755 $DEPLOY_DIR
sudo chmod -R 775 $DEPLOY_DIR/{recordings,uploads,logs,temp}
sudo chmod +x $DEPLOY_DIR/main.py $DEPLOY_DIR/system_status.py

print_success "Code deployment complete"

print_status "Restarting service..."
sudo systemctl daemon-reload
sudo systemctl restart $SERVICE_NAME

# Wait for startup
sleep 3

# Check service status
if sudo systemctl is-active --quiet $SERVICE_NAME; then
    print_success "Service started successfully"
    
    print_status "Recent service logs:"
    sudo journalctl -u $SERVICE_NAME --lines=10 --no-pager
else
    print_error "Service failed to start"
    sudo systemctl status $SERVICE_NAME --no-pager -l
    exit 1
fi

echo ""
echo "🎉 EZREC DEPLOYMENT COMPLETE"
echo "============================"
echo "✅ Service Status: $(sudo systemctl is-active $SERVICE_NAME)"
echo "✅ Monitor logs: sudo journalctl -u $SERVICE_NAME -f"
echo "✅ Stop: sudo systemctl stop $SERVICE_NAME"
echo "✅ Start: sudo systemctl start $SERVICE_NAME"
echo "✅ Restart: sudo systemctl restart $SERVICE_NAME"
echo ""
print_success "🚀 Deployment completed successfully!"
