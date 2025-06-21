#!/bin/bash

# EZREC Backend - Current Services Check Script
# This script checks what systemd services are currently running and working

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

echo "EZREC Backend - Current System Analysis"
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_warning "Some commands may require sudo privileges"
fi

# 1. Check for existing EZREC/SmartCam services
print_status "Checking for existing EZREC/SmartCam systemd services..."

EZREC_SERVICES=(
    "smartcam"
    "ezrec"
    "camera"
    "recording"
    "scheduler"
    "orchestrator"
    "status"
)

EXISTING_SERVICES=()

for service in "${EZREC_SERVICES[@]}"; do
    # Check for services containing the pattern
    SERVICES=$(systemctl list-units --type=service --all | grep -i "$service" | awk '{print $1}' | sed 's/\.service$//')
    
    if [ ! -z "$SERVICES" ]; then
        for s in $SERVICES; do
            EXISTING_SERVICES+=("$s")
            STATUS=$(systemctl is-active "$s.service" 2>/dev/null || echo "unknown")
            ENABLED=$(systemctl is-enabled "$s.service" 2>/dev/null || echo "unknown")
            print_info "Found service: $s.service (Status: $STATUS, Enabled: $ENABLED)"
        done
    fi
done

if [ ${#EXISTING_SERVICES[@]} -eq 0 ]; then
    print_warning "No existing EZREC/SmartCam services found"
else
    print_status "Found ${#EXISTING_SERVICES[@]} existing service(s)"
fi

echo ""

# 2. Check for application directories
print_status "Checking for existing application installations..."

APP_DIRS=(
    "/opt/ezrec-backend"
    "/opt/smartcam"
    "/home/michomanoly14892/code/SmartCam-Soccer"
    "/home/pi/code/EZREC-BackEnd"
    "/home/pi/SmartCam-Soccer"
)

EXISTING_DIRS=()

for dir in "${APP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        EXISTING_DIRS+=("$dir")
        print_info "Found application directory: $dir"
        
        # Check if it's a git repository
        if [ -d "$dir/.git" ]; then
            print_info "  - Git repository detected"
        fi
        
        # Check for Python files
        PYTHON_FILES=$(find "$dir" -name "*.py" | wc -l)
        print_info "  - Contains $PYTHON_FILES Python files"
        
        # Check for .env file
        if [ -f "$dir/.env" ]; then
            print_info "  - Has .env configuration file"
        fi
        
        # Check for virtual environment
        if [ -d "$dir/venv" ]; then
            print_info "  - Has virtual environment"
        fi
    fi
done

if [ ${#EXISTING_DIRS[@]} -eq 0 ]; then
    print_warning "No existing application directories found"
else
    print_status "Found ${#EXISTING_DIRS[@]} existing installation(s)"
fi

echo ""

# 3. Check for running Python processes
print_status "Checking for running EZREC/SmartCam Python processes..."

PYTHON_PROCESSES=$(ps aux | grep -E "(python|ezrec|smartcam|camera|orchestrator)" | grep -v grep || true)

if [ ! -z "$PYTHON_PROCESSES" ]; then
    echo "$PYTHON_PROCESSES" | while read line; do
        print_info "Running process: $line"
    done
else
    print_warning "No EZREC/SmartCam Python processes found"
fi

echo ""

# 4. Check for camera devices
print_status "Checking camera devices..."

if command -v v4l2-ctl >/dev/null 2>&1; then
    CAMERAS=$(v4l2-ctl --list-devices 2>/dev/null | grep -A1 "video" | grep "video" | wc -l || echo "0")
    print_info "Found $CAMERAS camera device(s)"
    
    if [ "$CAMERAS" -gt 0 ]; then
        v4l2-ctl --list-devices 2>/dev/null | grep -A1 "video" | grep "video" | while read device; do
            print_info "  - $device"
        done
    fi
else
    print_warning "v4l2-ctl not installed"
fi

echo ""

# 5. Check for environment variables
print_status "Checking environment variables..."

ENV_VARS=(
    "SUPABASE_URL"
    "SUPABASE_KEY"
    "USER_ID"
    "CAMERA_DEVICE"
    "RECORDING_DIR"
)

for var in "${ENV_VARS[@]}"; do
    if [ ! -z "${!var}" ]; then
        print_info "Environment variable $var is set"
    else
        print_warning "Environment variable $var is not set"
    fi
done

echo ""

# 6. Check for .env files
print_status "Checking for .env files..."

ENV_FILES=$(find / -name ".env" -type f 2>/dev/null | grep -E "(ezrec|smartcam|camera)" | head -10 || true)

if [ ! -z "$ENV_FILES" ]; then
    echo "$ENV_FILES" | while read file; do
        print_info "Found .env file: $file"
    done
else
    print_warning "No relevant .env files found"
fi

echo ""

# 7. Check system resources
print_status "Checking system resources..."

# CPU info
CPU_MODEL=$(cat /proc/cpuinfo | grep "Model name" | head -1 | cut -d: -f2 | xargs)
print_info "CPU: $CPU_MODEL"

# Memory
MEMORY=$(free -h | grep "Mem:" | awk '{print $2}')
print_info "Memory: $MEMORY"

# Disk space
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
print_info "Disk usage: $DISK_USAGE"

# Network
IP_ADDRESS=$(hostname -I | awk '{print $1}')
print_info "IP Address: $IP_ADDRESS"

echo ""

# 8. Generate recommendations
print_status "Generating recommendations..."

if [ ${#EXISTING_SERVICES[@]} -gt 0 ]; then
    print_info "Existing services found. Recommendations:"
    echo "  1. Stop existing services:"
    for service in "${EXISTING_SERVICES[@]}"; do
        echo "     sudo systemctl stop $service.service"
    done
    echo "  2. Disable existing services:"
    for service in "${EXISTING_SERVICES[@]}"; do
        echo "     sudo systemctl disable $service.service"
    done
    echo "  3. Remove old service files:"
    for service in "${EXISTING_SERVICES[@]}"; do
        echo "     sudo rm /etc/systemd/system/$service.service"
    done
    echo "  4. Reload systemd: sudo systemctl daemon-reload"
fi

if [ ${#EXISTING_DIRS[@]} -gt 0 ]; then
    print_info "Existing installations found. Recommendations:"
    echo "  1. Backup existing configuration:"
    for dir in "${EXISTING_DIRS[@]}"; do
        if [ -f "$dir/.env" ]; then
            echo "     cp $dir/.env $dir/.env.backup"
        fi
    done
    echo "  2. Choose one installation directory to update"
    echo "  3. Remove or archive other installations"
fi

echo ""
print_status "Analysis complete!"
echo ""
print_info "Next steps:"
echo "1. Review the findings above"
echo "2. Stop and disable existing services if found"
echo "3. Choose your preferred installation directory"
echo "4. Run the cleanup script: ./cleanup_redundant_files.sh"
echo "5. Run the Raspberry Pi setup: sudo ./raspberry_pi_setup.sh" 