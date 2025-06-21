#!/bin/bash

# EZREC Backend - Final Fix for httpx proxy argument issue
# This script fixes the specific httpx compatibility issue

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

print_status "Starting final fix for httpx proxy argument issue..."

# Step 1: Stop the service
print_status "Step 1: Stopping service..."
systemctl stop ezrec.service 2>/dev/null || true

# Step 2: Fix the httpx version issue
print_status "Step 2: Fixing httpx version compatibility..."
cd "$APP_DIR"

# Remove the problematic httpx version
print_info "Removing problematic httpx version..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" uninstall -y httpx httpcore

# Install the compatible version
print_info "Installing compatible httpx version..."
sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install httpx==0.27.2 httpcore==0.17.3

# Step 3: Test the fix
print_status "Step 3: Testing the fix..."
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
    print_status "✓ httpx compatibility issue resolved!"
else
    print_error "✗ Issue still persists, trying alternative approach..."
    
    # Alternative: Downgrade gotrue to a more compatible version
    print_info "Trying alternative: downgrading gotrue..."
    sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" uninstall -y gotrue
    sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/pip" install gotrue==2.8.0
    
    # Test again
    if sudo -u "$SERVICE_USER" "$APP_DIR/venv/bin/python" -c "
import os
os.environ['SUPABASE_URL'] = 'https://test.supabase.co'
os.environ['SUPABASE_KEY'] = 'test_key'
from supabase import create_client
try:
    client = create_client('https://test.supabase.co', 'test_key')
    print('✓ Supabase client creation successful with downgraded gotrue')
except Exception as e:
    print(f'✗ Error: {e}')
    exit(1)
"; then
        print_status "✓ Alternative fix successful!"
    else
        print_error "✗ All fixes failed. Manual intervention required."
        exit 1
    fi
fi

# Step 4: Start the service
print_status "Step 4: Starting service..."
systemctl start ezrec.service

# Step 5: Verify it's working
print_status "Step 5: Verifying service status..."
sleep 3

if systemctl is-active --quiet ezrec.service; then
    print_status "✓ Service is running successfully!"
else
    print_error "✗ Service failed to start. Checking logs..."
    journalctl -u ezrec.service -n 10
    exit 1
fi

print_status "Final fix completed successfully!"

print_info "Next steps:"
echo "1. Check service status: sudo $APP_DIR/manage.sh status"
echo "2. View logs: sudo $APP_DIR/manage.sh logs"
echo "3. Health check: sudo $APP_DIR/manage.sh health"

print_warning "The httpx proxy argument issue has been resolved!" 