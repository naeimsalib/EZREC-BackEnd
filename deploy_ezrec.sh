#!/bin/bash

# 🚀 EZREC Deployment Script - Complete System Setup & Update
# This is the ONLY deployment script needed for EZREC system
# Version: Final - All fixes included
# Last Updated: June 25, 2025

set -e  # Exit on any error

echo "🚀 EZREC Deployment Script - Complete System Setup"
echo "=================================================="
echo "📅 Started at: $(date)"
echo ""

# Configuration
REPO_DIR="~/code/EZREC-BackEnd"
DEPLOY_DIR="/opt/ezrec-backend"
SERVICE_NAME="ezrec-backend"
VENV_PATH="$DEPLOY_DIR/venv"

# Function to print status messages
print_status() {
    echo "📋 $1"
}

print_success() {
    echo "✅ $1"
}

print_error() {
    echo "❌ $1"
}

print_warning() {
    echo "⚠️ $1"
}

# Function to check if running as correct user
check_user() {
    if [[ $EUID -eq 0 ]]; then
        print_error "Do not run this script as root. Run as pi user with sudo when needed."
        exit 1
    fi
    print_success "Running as user: $(whoami)"
}

# Function to update code from GitHub
update_code() {
    print_status "Updating code from GitHub..."
    
    cd $REPO_DIR
    
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

# Function to deploy code
deploy_code() {
    print_status "Deploying code to $DEPLOY_DIR..."
    
    # Create deployment directory if it doesn't exist
    sudo mkdir -p $DEPLOY_DIR
    sudo chown -R ezrec:ezrec $DEPLOY_DIR
    
    # Remove old source files
    sudo rm -rf $DEPLOY_DIR/src/*
    
    # Copy new source files
    sudo cp -r $REPO_DIR/src/* $DEPLOY_DIR/src/
    
    # Copy other essential files
    sudo cp $REPO_DIR/requirements.txt $DEPLOY_DIR/
    sudo cp $REPO_DIR/ezrec-backend.service $DEPLOY_DIR/
    
    # Set proper ownership
    sudo chown -R ezrec:ezrec $DEPLOY_DIR
    
    print_success "Code deployed"
}

# Function to clean Python cache
clean_cache() {
    print_status "Cleaning Python cache..."
    
    # Remove all Python cache files
    sudo find $DEPLOY_DIR -name "*.pyc" -delete
    sudo find $DEPLOY_DIR -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    sudo rm -rf $DEPLOY_DIR/src/__pycache__/
    
    print_success "Python cache cleaned"
}

# Function to verify virtual environment
verify_venv() {
    print_status "Verifying virtual environment..."
    
    if [[ ! -d "$VENV_PATH" ]]; then
        print_status "Creating virtual environment..."
        sudo -u ezrec python3 -m venv $VENV_PATH
    fi
    
    # Activate virtual environment and install/update requirements
    print_status "Installing/updating Python packages..."
    sudo -u ezrec $VENV_PATH/bin/pip install --upgrade pip
    sudo -u ezrec $VENV_PATH/bin/pip install -r $DEPLOY_DIR/requirements.txt
    
    print_success "Virtual environment ready"
}

# Function to verify configuration
verify_config() {
    print_status "Verifying configuration..."
    
    # Check if .env file exists
    if [[ ! -f "$DEPLOY_DIR/.env" ]]; then
        print_warning ".env file not found in $DEPLOY_DIR"
        print_status "You may need to create it manually with your Supabase credentials"
    else
        print_success ".env file found"
    fi
    
    # Verify service file
    if [[ ! -f "/etc/systemd/system/$SERVICE_NAME.service" ]]; then
        print_status "Installing systemd service..."
        sudo cp $DEPLOY_DIR/ezrec-backend.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable $SERVICE_NAME
        print_success "Service installed and enabled"
    else
        print_success "Service file exists"
    fi
}

# Function to start service
start_service() {
    print_status "Starting $SERVICE_NAME service..."
    
    # Reload systemd and start service
    sudo systemctl daemon-reload
    sudo systemctl start $SERVICE_NAME
    
    # Wait a moment for service to start
    sleep 3
    
    # Check service status
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Service started successfully"
    else
        print_error "Service failed to start"
        print_status "Checking service status..."
        sudo systemctl status $SERVICE_NAME --no-pager -l
        return 1
    fi
}

# Function to show service logs
show_logs() {
    print_status "Recent service logs:"
    echo "===================="
    sudo journalctl -u $SERVICE_NAME --lines=20 --no-pager
    echo ""
    print_status "To monitor live logs, run:"
    echo "sudo journalctl -u $SERVICE_NAME -f --no-pager"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check if enhanced query processing is working
    sleep 5
    
    RECENT_LOGS=$(sudo journalctl -u $SERVICE_NAME --since="1 minute ago" --no-pager)
    
    if echo "$RECENT_LOGS" | grep -q "📋 Processing bookings table query"; then
        print_success "Enhanced query processing detected - deployment successful!"
    elif echo "$RECENT_LOGS" | grep -q "✅ Confirmed SELECT query detected"; then
        print_success "Query processing working - deployment successful!"
    else
        print_warning "Enhanced logging not detected yet - check logs manually"
    fi
    
    # Show system status
    print_status "Service status:"
    sudo systemctl status $SERVICE_NAME --no-pager -l | head -10
}

# Function to display summary
show_summary() {
    echo ""
    echo "🎯 DEPLOYMENT SUMMARY"
    echo "===================="
    echo "📁 Source Directory: $REPO_DIR"
    echo "📁 Deploy Directory: $DEPLOY_DIR"
    echo "🔧 Service Name: $SERVICE_NAME"
    echo "🐍 Virtual Environment: $VENV_PATH"
    echo ""
    echo "🔍 Key Features Deployed:"
    echo "  ✅ Enhanced query parsing with dynamic date/user_id filtering"
    echo "  ✅ Comprehensive debug logging"
    echo "  ✅ Picamera2 recording system"
    echo "  ✅ Supabase integration with proper error handling"
    echo "  ✅ Automatic booking lifecycle management"
    echo "  ✅ System status monitoring every 3 seconds"
    echo ""
    echo "📋 Useful Commands:"
    echo "  Monitor logs: sudo journalctl -u $SERVICE_NAME -f --no-pager"
    echo "  Service status: sudo systemctl status $SERVICE_NAME"
    echo "  Restart service: sudo systemctl restart $SERVICE_NAME"
    echo "  Stop service: sudo systemctl stop $SERVICE_NAME"
    echo ""
    echo "🎬 System is ready for booking appointments!"
    echo "📅 Completed at: $(date)"
}

# Main deployment process
main() {
    echo "Starting EZREC deployment process..."
    echo ""
    
    # Pre-flight checks
    check_user
    
    # Deployment steps
    update_code
    stop_service
    deploy_code
    clean_cache
    verify_venv
    verify_config
    start_service
    
    # Post-deployment verification
    verify_deployment
    show_logs
    show_summary
    
    print_success "🎉 EZREC deployment completed successfully!"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "logs")
        print_status "Showing live logs for $SERVICE_NAME..."
        sudo journalctl -u $SERVICE_NAME -f --no-pager
        ;;
    "status")
        print_status "Service status:"
        sudo systemctl status $SERVICE_NAME --no-pager -l
        ;;
    "restart")
        print_status "Restarting $SERVICE_NAME..."
        sudo systemctl restart $SERVICE_NAME
        print_success "Service restarted"
        ;;
    "stop")
        stop_service
        ;;
    "start")
        start_service
        ;;
    "clean")
        print_status "Cleaning deployment..."
        stop_service
        clean_cache
        start_service
        ;;
    "help"|"-h"|"--help")
        echo "EZREC Deployment Script Usage:"
        echo ""
        echo "  ./deploy_ezrec.sh [command]"
        echo ""
        echo "Commands:"
        echo "  deploy    - Full deployment (default)"
        echo "  logs      - Show live logs"
        echo "  status    - Show service status"
        echo "  restart   - Restart service"
        echo "  stop      - Stop service"
        echo "  start     - Start service"
        echo "  clean     - Clean cache and restart"
        echo "  help      - Show this help"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use './deploy_ezrec.sh help' for usage information"
        exit 1
        ;;
esac 