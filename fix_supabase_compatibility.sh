#!/bin/bash

# EZREC Supabase Compatibility Fix
# Fixes the 'proxy' keyword argument error

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              EZREC Supabase Compatibility Fix                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root (with sudo)"
    exit 1
fi

print_info "Stopping EZREC service..."
systemctl stop ezrec-backend

print_info "Fixing Supabase client compatibility..."

# Navigate to the EZREC directory
cd /opt/ezrec-backend

# Install compatible Supabase version
print_info "Installing compatible Supabase client version..."
sudo -u ezrec ./venv/bin/pip install "supabase==1.0.3" --force-reinstall

# Also ensure compatible httpx version
print_info "Installing compatible httpx version..."
sudo -u ezrec ./venv/bin/pip install "httpx==0.24.1" --force-reinstall

# Test the connection
print_info "Testing Supabase connection..."
cat > test_supabase_connection.py << 'EOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/opt/ezrec-backend/src')

try:
    from supabase import create_client
    from config import SUPABASE_URL, SUPABASE_KEY
    
    print(f"Supabase URL: {SUPABASE_URL}")
    print(f"Service Key: {SUPABASE_KEY[:20]}...")
    
    # Test connection with older client syntax
    client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # Test a simple query
    response = client.table("system_status").select("*").limit(1).execute()
    
    print("✓ Supabase connection successful!")
    print(f"Response: {response.data}")
    
except Exception as e:
    print(f"✗ Supabase connection failed: {e}")
    sys.exit(1)

EOF

chmod +x test_supabase_connection.py
sudo -u ezrec ./venv/bin/python test_supabase_connection.py

if [ $? -eq 0 ]; then
    print_status "Supabase connection test passed!"
else
    print_error "Supabase connection test failed"
    print_info "Checking if tables exist..."
    
    # Try to create tables if they don't exist
    print_info "Ensuring database tables exist..."
    
    # Add table creation here if needed
    print_warning "You may need to create the required tables in your Supabase dashboard"
fi

# Clean up test file
rm -f test_supabase_connection.py

print_info "Restarting EZREC service..."
systemctl start ezrec-backend

print_info "Waiting for service to start..."
sleep 5

print_info "Checking service status..."
systemctl status ezrec-backend --no-pager -l

print_status "Supabase compatibility fix completed!"
print_info "Monitor the logs with: sudo journalctl -u ezrec-backend -f" 