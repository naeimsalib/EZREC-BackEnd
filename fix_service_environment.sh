#!/bin/bash
# 🐍 EZREC Service Environment Fix
# ================================
# Fixes Python environment and dependencies for the service

set -e

echo "🐍 EZREC Service Environment Fix"
echo "================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

SERVICE_DIR="/opt/ezrec-backend"
SERVICE_USER="michomanoly14892"

log_info "Step 1: Creating virtual environment for service..."
cd $SERVICE_DIR

# Remove old venv if exists
if [ -d "venv" ]; then
    rm -rf venv
fi

# Create new virtual environment
python3 -m venv venv
chown -R $SERVICE_USER:$SERVICE_USER venv

log_info "Step 2: Installing Python dependencies in service venv..."
su - $SERVICE_USER -c "cd $SERVICE_DIR && source venv/bin/activate && pip install --upgrade pip"
su - $SERVICE_USER -c "cd $SERVICE_DIR && source venv/bin/activate && pip install supabase picamera2 python-dotenv requests"

log_info "Step 3: Creating environment file..."
cat > $SERVICE_DIR/.env << EOF
# EZREC Service Environment
# Auto-generated $(date)
PYTHONPATH=$SERVICE_DIR
EOF
chown $SERVICE_USER:$SERVICE_USER $SERVICE_DIR/.env

log_info "Step 4: Updating service configuration..."
# Backup current service file
cp /etc/systemd/system/ezrec-backend.service /etc/systemd/system/ezrec-backend.service.backup

# Update service to use virtual environment
cat > /etc/systemd/system/ezrec-backend.service << EOF
[Unit]
Description=EZREC Backend Service - Soccer Recording System
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$SERVICE_DIR
Environment=PYTHONPATH=$SERVICE_DIR
EnvironmentFile=$SERVICE_DIR/.env
ExecStartPre=/bin/bash -c 'echo "🛡️ Protecting camera for EZREC..."'
ExecStartPre=/bin/bash -c 'sudo fuser -k /dev/video0 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'sudo fuser -k /dev/video1 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'sudo fuser -k /dev/video2 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'echo "✅ Camera protection active"'
ExecStart=$SERVICE_DIR/venv/bin/python3 src/orchestrator.py
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
ReadWritePaths=$SERVICE_DIR

[Install]
WantedBy=multi-user.target
EOF

log_info "Step 5: Reloading systemd and restarting service..."
systemctl daemon-reload
systemctl restart ezrec-backend

log_info "Step 6: Checking service status..."
sleep 3
systemctl status ezrec-backend --no-pager -l

log_info "Step 7: Testing Python environment..."
su - $SERVICE_USER -c "cd $SERVICE_DIR && source venv/bin/activate && python3 -c 'import supabase; print(\"✅ Supabase available\")'"
su - $SERVICE_USER -c "cd $SERVICE_DIR && source venv/bin/activate && python3 -c 'from picamera2 import Picamera2; print(\"✅ Picamera2 available\")'"

log_info "Service environment fix complete!" 