#!/usr/bin/env python3

"""
🔍 EZREC System Diagnostics & Verification Tool
This script provides comprehensive system diagnostics for EZREC
"""

import os
import sys
import json
import subprocess
from datetime import datetime, timedelta
from pathlib import Path

# Add the src directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

def print_header(title):
    """Print a formatted header."""
    print(f"\n{'='*60}")
    print(f"🔍 {title}")
    print(f"{'='*60}")

def print_section(title):
    """Print a formatted section."""
    print(f"\n📋 {title}")
    print("-" * 40)

def print_success(message):
    """Print success message."""
    print(f"✅ {message}")

def print_error(message):
    """Print error message."""
    print(f"❌ {message}")

def print_warning(message):
    """Print warning message."""
    print(f"⚠️ {message}")

def print_info(message):
    """Print info message."""
    print(f"ℹ️ {message}")

def run_command(command, capture_output=True):
    """Run a shell command and return the result."""
    try:
        result = subprocess.run(
            command, 
            shell=True, 
            capture_output=capture_output, 
            text=True,
            timeout=30
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e)

def check_system_basics():
    """Check basic system information."""
    print_header("SYSTEM BASICS")
    
    # Current time
    print_info(f"Current Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # User
    success, stdout, _ = run_command("whoami")
    if success:
        print_info(f"Current User: {stdout.strip()}")
    
    # System info
    success, stdout, _ = run_command("uname -a")
    if success:
        print_info(f"System: {stdout.strip()}")
    
    # Python version
    print_info(f"Python Version: {sys.version}")

def check_directories():
    """Check directory structure."""
    print_header("DIRECTORY STRUCTURE")
    
    directories = [
        "~/code/EZREC-BackEnd",
        "/opt/ezrec-backend",
        "/opt/ezrec-backend/src",
        "/opt/ezrec-backend/venv"
    ]
    
    for directory in directories:
        expanded_dir = os.path.expanduser(directory)
        if os.path.exists(expanded_dir):
            print_success(f"{directory} exists")
            # Show file count
            try:
                file_count = len(os.listdir(expanded_dir))
                print_info(f"  └─ Contains {file_count} items")
            except:
                pass
        else:
            print_error(f"{directory} does not exist")

def check_service_status():
    """Check systemd service status."""
    print_header("SERVICE STATUS")
    
    service_name = "ezrec-backend"
    
    # Check if service exists
    success, stdout, _ = run_command(f"systemctl list-unit-files | grep {service_name}")
    if success and service_name in stdout:
        print_success(f"{service_name} service is installed")
    else:
        print_error(f"{service_name} service is not installed")
        return
    
    # Check service status
    success, stdout, stderr = run_command(f"systemctl is-active {service_name}")
    if success and "active" in stdout:
        print_success(f"{service_name} is active")
    else:
        print_error(f"{service_name} is not active: {stdout.strip()}")
    
    # Check service enabled status
    success, stdout, _ = run_command(f"systemctl is-enabled {service_name}")
    if success and "enabled" in stdout:
        print_success(f"{service_name} is enabled")
    else:
        print_warning(f"{service_name} is not enabled: {stdout.strip()}")
    
    # Show recent logs
    print_section("Recent Service Logs (last 10 lines)")
    success, stdout, _ = run_command(f"journalctl -u {service_name} --lines=10 --no-pager")
    if success:
        print(stdout)
    else:
        print_error("Could not retrieve service logs")

def check_python_environment():
    """Check Python environment and dependencies."""
    print_header("PYTHON ENVIRONMENT")
    
    venv_path = "/opt/ezrec-backend/venv"
    
    # Check virtual environment
    if os.path.exists(venv_path):
        print_success("Virtual environment exists")
        
        # Check Python in venv
        python_path = f"{venv_path}/bin/python"
        if os.path.exists(python_path):
            print_success("Python executable found in venv")
            
            # Check installed packages
            success, stdout, _ = run_command(f"{python_path} -m pip list")
            if success:
                print_section("Installed Python Packages")
                lines = stdout.strip().split('\n')
                for line in lines[2:]:  # Skip header lines
                    if line.strip():
                        print(f"  {line}")
        else:
            print_error("Python executable not found in venv")
    else:
        print_error("Virtual environment does not exist")

def check_configuration():
    """Check configuration files."""
    print_header("CONFIGURATION")
    
    config_files = [
        "/opt/ezrec-backend/.env",
        "/opt/ezrec-backend/src/config.py",
        "/etc/systemd/system/ezrec-backend.service"
    ]
    
    for config_file in config_files:
        if os.path.exists(config_file):
            print_success(f"{config_file} exists")
            
            # Show file size and modification time
            stat = os.stat(config_file)
            size = stat.st_size
            mtime = datetime.fromtimestamp(stat.st_mtime)
            print_info(f"  └─ Size: {size} bytes, Modified: {mtime}")
            
            # For .env file, check if it has required variables
            if config_file.endswith('.env'):
                try:
                    with open(config_file, 'r') as f:
                        content = f.read()
                        required_vars = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'USER_ID']
                        for var in required_vars:
                            if var in content:
                                print_success(f"  └─ {var} found in .env")
                            else:
                                print_error(f"  └─ {var} missing from .env")
                except Exception as e:
                    print_error(f"  └─ Could not read .env file: {e}")
        else:
            print_error(f"{config_file} does not exist")

def test_supabase_connection():
    """Test Supabase connection."""
    print_header("SUPABASE CONNECTION TEST")
    
    try:
        # Import config
        from config import SUPABASE_URL, SUPABASE_ANON_KEY, USER_ID
        print_success("Configuration imported successfully")
        print_info(f"Supabase URL: {SUPABASE_URL}")
        print_info(f"User ID: {USER_ID}")
        
        # Test Supabase client
        from supabase import create_client
        supabase = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
        print_success("Supabase client created successfully")
        
        # Test basic query
        result = supabase.table("system_status").select("*").limit(1).execute()
        print_success(f"Test query successful - returned {len(result.data)} records")
        
        # Test bookings query
        today = datetime.now().date().isoformat()
        result = supabase.table("bookings").select("*").eq("date", today).eq("user_id", USER_ID).execute()
        print_success(f"Bookings query successful - found {len(result.data)} bookings for today")
        
        if result.data:
            print_section("Today's Bookings")
            for booking in result.data:
                start_time = booking.get('start_time', 'N/A')
                end_time = booking.get('end_time', 'N/A')
                status = booking.get('status', 'N/A')
                print(f"  📅 {start_time} - {end_time} (Status: {status})")
        
    except ImportError as e:
        print_error(f"Could not import required modules: {e}")
    except Exception as e:
        print_error(f"Supabase connection test failed: {e}")

def check_camera_access():
    """Check camera access."""
    print_header("CAMERA ACCESS TEST")
    
    try:
        from picamera2 import Picamera2
        print_success("Picamera2 imported successfully")
        
        # Try to list cameras
        cameras = Picamera2.global_camera_info()
        if cameras:
            print_success(f"Found {len(cameras)} camera(s)")
            for i, camera in enumerate(cameras):
                print_info(f"  Camera {i}: {camera}")
        else:
            print_warning("No cameras detected")
        
        # Try to create camera instance (but don't start it)
        try:
            picam2 = Picamera2()
            print_success("Camera instance created successfully")
            picam2.close()
        except Exception as e:
            print_error(f"Could not create camera instance: {e}")
            
    except ImportError:
        print_error("Picamera2 not available - check installation")
    except Exception as e:
        print_error(f"Camera test failed: {e}")

def check_disk_space():
    """Check disk space."""
    print_header("DISK SPACE")
    
    # Check overall disk space
    success, stdout, _ = run_command("df -h /")
    if success:
        print_section("Root filesystem")
        print(stdout)
    
    # Check specific directories
    directories = ["/opt/ezrec-backend", "~/code/EZREC-BackEnd"]
    for directory in directories:
        expanded_dir = os.path.expanduser(directory)
        if os.path.exists(expanded_dir):
            success, stdout, _ = run_command(f"du -sh {expanded_dir}")
            if success:
                print_info(f"{directory}: {stdout.strip()}")

def generate_summary():
    """Generate diagnostic summary."""
    print_header("DIAGNOSTIC SUMMARY")
    
    print_section("Quick Health Check Commands")
    print("📋 Service Status:")
    print("   sudo systemctl status ezrec-backend")
    print("")
    print("📋 Live Logs:")
    print("   sudo journalctl -u ezrec-backend -f --no-pager")
    print("")
    print("📋 Recent Logs:")
    print("   sudo journalctl -u ezrec-backend --lines=50 --no-pager")
    print("")
    print("📋 Restart Service:")
    print("   sudo systemctl restart ezrec-backend")
    print("")
    print("📋 Deploy Updates:")
    print("   ./deploy_ezrec.sh")
    print("")
    print("📋 View Diagnostics:")
    print("   python3 ezrec_diagnostics.py")

def main():
    """Main diagnostic function."""
    print_header("EZREC SYSTEM DIAGNOSTICS")
    print_info(f"Diagnostic started at: {datetime.now()}")
    
    # Run all diagnostic checks
    check_system_basics()
    check_directories()
    check_service_status()
    check_python_environment()
    check_configuration()
    test_supabase_connection()
    check_camera_access()
    check_disk_space()
    generate_summary()
    
    print_header("DIAGNOSTICS COMPLETE")
    print_success(f"Diagnostic completed at: {datetime.now()}")

if __name__ == "__main__":
    main() 