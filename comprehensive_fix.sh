#!/bin/bash

# EZREC Backend - Comprehensive Fix for httpx and dependency issues
# This script fixes the specific httpx compatibility issue and ensures all dependencies work

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

print_status "Starting comprehensive fix for httpx and dependency issues..."

# Step 1: Stop the service
print_status "Step 1: Stopping service..."
systemctl stop ezrec.service 2>/dev/null || true

# Step 2: Completely clean and recreate virtual environment
print_status "Step 2: Completely recreating virtual environment..."
cd "$APP_DIR"

# Remove existing venv
print_info "Removing existing virtual environment..."
rm -rf venv

# Create new venv
print_info "Creating new virtual environment..."
sudo -u "$SERVICE_USER" python3 -m venv venv
chown -R "$SERVICE_USER:$SERVICE_USER" venv

# Step 3: Install dependencies in the correct order
print_status "Step 3: Installing dependencies in correct order..."

# Upgrade pip first
print_info "Upgrading pip..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install --upgrade pip

# Install httpx and httpcore first (the problematic packages)
print_info "Installing httpx and httpcore first..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install httpx==0.27.2
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install httpcore==0.18.0

# Install gotrue with compatible version
print_info "Installing gotrue with compatible version..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install gotrue==2.8.0

# Install other Supabase packages
print_info "Installing other Supabase packages..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install postgrest==0.13.0
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install storage3==0.7.7
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install realtime==1.0.6
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install supafunc==0.3.3

# Install supabase last
print_info "Installing supabase..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install supabase==2.2.1

# Install other dependencies
print_info "Installing other dependencies..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install python-dotenv==1.0.0
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install opencv-python==4.8.1.78
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install numpy==1.26.4
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install psutil==5.9.4
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install pytz==2023.3
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install ffmpeg-python==0.2.0
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install picamera2==0.3.27

# Step 4: Test the fix
print_status "Step 4: Testing the fix..."
print_info "Testing httpx import..."

# Test httpx import
if sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" -c "import httpx; print('✓ httpx imported successfully')"; then
    print_status "✓ httpx import successful!"
else
    print_error "✗ httpx import failed"
    exit 1
fi

print_info "Testing Supabase client creation..."

# Test if the issue is resolved
if sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" -c "
import os
os.environ['SUPABASE_URL'] = 'https://test.supabase.co'
os.environ['SUPABASE_KEY'] = 'test_key'
from supabase import create_client
try:
    client = create_client('https://test.supabase.co', 'test_key')
    print('✓ Supabase client creation successful')
except Exception as e:
    print(f'✗ Error: {e}')
    exit(1)
"; then
    print_status "✓ Supabase client creation successful!"
else
    print_error "✗ Supabase client creation failed"
    exit 1
fi

# Step 5: Start the service
print_status "Step 5: Starting service..."
systemctl start ezrec.service

# Step 6: Verify it's working
print_status "Step 6: Verifying service status..."
sleep 5

if systemctl is-active --quiet ezrec.service; then
    print_status "✓ Service is running successfully!"
else
    print_error "✗ Service failed to start. Checking logs..."
    journalctl -u ezrec.service -n 10
    exit 1
fi

print_status "Comprehensive fix completed successfully!"

print_info "Next steps:"
echo "1. Check service status: sudo $APP_DIR/manage.sh status"
echo "2. View logs: sudo $APP_DIR/manage.sh logs"
echo "3. Health check: sudo $APP_DIR/manage.sh health"

print_warning "The httpx dependency issues have been resolved!" 