#!/bin/bash

# EZREC Backend - Cleanup Redundant Files Script
# This script removes duplicate and redundant files from the codebase

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

print_status "Starting cleanup of redundant files..."

# Create backup directory
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

print_info "Creating backup in $BACKUP_DIR"

# List of redundant files to remove
REDUNDANT_FILES=(
    # Duplicate camera test files
    "test_main_camera.py"
    "test_working_camera.py"
    "test_camera_direct.py"
    "debug_camera.py"
    "quick_camera_test.py"
    "test_camera_advanced.py"
    "test_camera_simple_fix.py"
    
    # Redundant setup scripts
    "setup.sh"
    "install_and_test.sh"
    
    # Redundant service files
    "smartcam.service"
    
    # Redundant management files
    "manage_cameras.py"
    "update_system_status.py"
    
    # Large log files
    "logs.txt"
    "logs_last_10min.txt"
    
    # Temporary files
    "part_aa"
    
    # Redundant test files
    "test_booking_logic.py"
    "test_new_features.py"
    "test.sh"
    
    # Redundant shell scripts
    "kill_camera_processes.sh"
    "check_camera_usage.py"
    "fix_camera.sh"
    "enable_camera.sh"
    "test_camera.sh"
    "fix_supabase.sh"
    "push_updates.sh"
    "deploy-frontend.sh"
    "setup_and_run.sh"
    "setup_new_features.py"
    "post_boot_check.py"
    "check_videos.py"
    "deploy.sh"
    "install_dependencies.sh"
    "run_services.sh"
)

# List of redundant directories
REDUNDANT_DIRS=(
    "SmartCam-Soccer"
    "temp"
)

print_status "Moving redundant files to backup..."

# Move redundant files to backup
for file in "${REDUNDANT_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_info "Moving $file to backup"
        mv "$file" "$BACKUP_DIR/"
    else
        print_warning "File $file not found, skipping"
    fi
done

# Move redundant directories to backup
for dir in "${REDUNDANT_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        print_info "Moving directory $dir to backup"
        mv "$dir" "$BACKUP_DIR/"
    else
        print_warning "Directory $dir not found, skipping"
    fi
done

# Clean up empty directories
print_status "Cleaning up empty directories..."
find . -type d -empty -delete 2>/dev/null || true

# Remove redundant functions from main.py
print_status "Cleaning up main.py..."

# Create a backup of main.py
cp main.py "$BACKUP_DIR/main.py.backup"

# Remove redundant functions from main.py (keeping only essential ones)
print_info "Note: main.py contains some redundant functions that should be refactored:"
print_info "- get_ip_address() (duplicate of utils.get_ip())"
print_info "- update_camera_status() (duplicate of utils.update_system_status())"
print_info "- start_recording() and stop_recording() (duplicate of camera service)"

# Create a simplified main.py that uses the clean orchestrator
cat > main.py << 'EOL'
#!/usr/bin/env python3
"""
EZREC Backend - Main Entry Point
This is the main entry point for the EZREC backend system.
It uses the clean orchestrator to manage all services.
"""

import sys
import os

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from orchestrator_clean import main

if __name__ == "__main__":
    main()
EOL

print_status "Updated main.py to use clean orchestrator"

# Update requirements.txt to remove unnecessary dependencies
print_status "Cleaning up requirements.txt..."

# Create backup
cp requirements.txt "$BACKUP_DIR/requirements.txt.backup"

# Create a minimal requirements.txt with only necessary packages
cat > requirements.txt << 'EOL'
# Core dependencies
python-dotenv==1.0.0
supabase==2.3.5
opencv-python==4.8.1.78
psutil==5.9.4
pytz==2023.3

# Camera dependencies
picamera2==0.3.27

# Video processing
ffmpeg-python==0.2.0

# Development dependencies (optional)
pytest==7.4.0
pytest-cov==4.1.0
EOL

print_status "Updated requirements.txt with minimal dependencies"

# Create a README for the cleaned version
cat > README_CLEAN.md << 'EOL'
# EZREC Backend - Cleaned Version

This is the cleaned version of the EZREC Backend with redundant code removed.

## Changes Made

### Removed Redundant Files
- Multiple camera test files (consolidated into one)
- Duplicate setup scripts
- Redundant service files
- Duplicate management scripts
- Large log files
- Temporary files

### Consolidated Functions
- IP address functions (now only in utils.py)
- System status functions (now only in utils.py)
- Recording functions (now in camera service)
- Orchestrator functions (consolidated into orchestrator_clean.py)

### Simplified Structure
```
src/
├── config.py              # Configuration
├── utils.py               # Utility functions
├── camera.py              # Camera service
├── camera_interface.py    # Camera interface
├── orchestrator.py        # Original orchestrator
├── orchestrator_clean.py  # Clean orchestrator (recommended)
└── scheduler.py           # Scheduler service

systemd/                   # systemd service files
raspberry_pi_setup.sh      # Raspberry Pi installation script
main.py                    # Main entry point (simplified)
requirements.txt           # Minimal dependencies
```

## Usage

### Development
```bash
python main.py
```

### Production (Raspberry Pi)
```bash
sudo ./raspberry_pi_setup.sh
sudo /opt/ezrec-backend/manage.sh start
```

## Backup

All removed files are backed up in: `backup_YYYYMMDD_HHMMSS/`

## Next Steps

1. Test the cleaned version thoroughly
2. Update any references to removed files
3. Consider using orchestrator_clean.py instead of orchestrator.py
4. Configure your .env file with Supabase credentials
EOL

print_status "Created README_CLEAN.md with documentation"

# Create a test script for the cleaned version
cat > test_clean.py << 'EOL'
#!/usr/bin/env python3
"""
Test script for the cleaned EZREC Backend
"""

import sys
import os
import importlib.util

def test_imports():
    """Test that all modules can be imported."""
    modules = [
        'src.config',
        'src.utils',
        'src.camera',
        'src.camera_interface',
        'src.orchestrator',
        'src.orchestrator_clean',
        'src.scheduler'
    ]
    
    print("Testing module imports...")
    for module_name in modules:
        try:
            spec = importlib.util.spec_from_file_location(module_name, f"{module_name.replace('.', '/')}.py")
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            print(f"✓ {module_name}")
        except Exception as e:
            print(f"✗ {module_name}: {e}")
            return False
    return True

def test_config():
    """Test configuration loading."""
    try:
        from src.config import SUPABASE_URL, USER_ID
        print("✓ Configuration loaded")
        return True
    except Exception as e:
        print(f"✗ Configuration error: {e}")
        return False

def test_camera_interface():
    """Test camera interface initialization."""
    try:
        from src.camera_interface import CameraInterface
        print("✓ Camera interface imported")
        return True
    except Exception as e:
        print(f"✗ Camera interface error: {e}")
        return False

def main():
    """Run all tests."""
    print("EZREC Backend - Clean Version Tests")
    print("===================================")
    
    tests = [
        test_imports,
        test_config,
        test_camera_interface
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print(f"Tests passed: {passed}/{total}")
    
    if passed == total:
        print("✓ All tests passed!")
        return 0
    else:
        print("✗ Some tests failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
EOL

chmod +x test_clean.py

print_status "Created test_clean.py for testing the cleaned version"

print_status "Cleanup completed successfully!"
echo ""
print_info "Summary:"
echo "- Moved redundant files to: $BACKUP_DIR"
echo "- Simplified main.py to use clean orchestrator"
echo "- Updated requirements.txt with minimal dependencies"
echo "- Created README_CLEAN.md with documentation"
echo "- Created test_clean.py for testing"
echo ""
print_warning "Please test the cleaned version before deploying:"
echo "python test_clean.py"
echo ""
print_info "To restore files if needed:"
echo "cp -r $BACKUP_DIR/* ." 