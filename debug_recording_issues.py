#!/usr/bin/env python3
"""
🔍 EZREC Recording Issues Diagnostic Script
===============================================
This script helps diagnose the remaining issues with:
1. Recording file creation
2. Status updates during recording

Run this on the Raspberry Pi to identify specific problems.
"""

import os
import sys
import subprocess
import time
from pathlib import Path
import json

def check_directories():
    """Check recording directories and permissions"""
    print("📁 DIRECTORY PERMISSIONS CHECK")
    print("=" * 50)
    
    directories = [
        "/opt/ezrec-backend/recordings",
        "/opt/ezrec-backend/temp", 
        "/opt/ezrec-backend/logs"
    ]
    
    for dir_path in directories:
        print(f"\n📂 {dir_path}:")
        path = Path(dir_path)
        
        if path.exists():
            stat = path.stat()
            permissions = oct(stat.st_mode)[-3:]
            
            print(f"  ✅ Exists: Yes")
            print(f"  🔐 Permissions: {permissions}")
            print(f"  👤 Owner: {stat.st_uid}")
            print(f"  👥 Group: {stat.st_gid}")
            print(f"  ✍️  Writable: {os.access(dir_path, os.W_OK)}")
            
            # List files
            files = list(path.glob("*"))
            print(f"  📄 Files: {len(files)}")
            if files:
                for f in files[-3:]:  # Show last 3 files
                    size = f.stat().st_size if f.is_file() else 0
                    print(f"    - {f.name} ({size} bytes)")
        else:
            print(f"  ❌ Exists: No")

def check_service_user():
    """Check which user the service runs as"""
    print("\n👤 SERVICE USER CHECK")
    print("=" * 50)
    
    try:
        result = subprocess.run(
            ["sudo", "systemctl", "show", "ezrec-backend", "-p", "User"],
            capture_output=True, text=True
        )
        user_line = result.stdout.strip()
        if "User=" in user_line:
            service_user = user_line.split("=")[1]
            print(f"  🏃 Service runs as: {service_user}")
            
            # Check if service user can write to recordings dir
            test_file = "/opt/ezrec-backend/recordings/test_write.txt"
            try:
                result = subprocess.run(
                    ["sudo", "-u", service_user, "touch", test_file],
                    capture_output=True, text=True
                )
                if result.returncode == 0:
                    print(f"  ✅ {service_user} can write to recordings directory")
                    # Clean up test file
                    subprocess.run(["sudo", "rm", "-f", test_file])
                else:
                    print(f"  ❌ {service_user} cannot write to recordings directory")
                    print(f"     Error: {result.stderr}")
            except Exception as e:
                print(f"  ⚠️ Could not test write permissions: {e}")
        else:
            print(f"  ❓ Could not determine service user")
            
    except Exception as e:
        print(f"  ❌ Error checking service user: {e}")

def check_picamera2_availability():
    """Check if Picamera2 is available in service context"""
    print("\n📹 PICAMERA2 AVAILABILITY CHECK")
    print("=" * 50)
    
    # Test script
    test_script = """
import sys
try:
    from picamera2 import Picamera2
    from picamera2.encoders import H264Encoder
    from picamera2.outputs import FileOutput
    print("✅ Picamera2 import successful")
    
    # Try to initialize (without starting)
    picam2 = Picamera2()
    print("✅ Picamera2 initialization successful")
    picam2.close()
    
except ImportError as e:
    print(f"❌ Picamera2 import failed: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Picamera2 initialization failed: {e}")
    sys.exit(1)
"""
    
    # Write test script
    test_file = "/tmp/test_picamera2.py"
    with open(test_file, 'w') as f:
        f.write(test_script)
    
    # Run as service user
    try:
        result = subprocess.run(
            ["sudo", "systemctl", "show", "ezrec-backend", "-p", "User"],
            capture_output=True, text=True
        )
        service_user = result.stdout.strip().split("=")[1] if "User=" in result.stdout else "root"
        
        print(f"  🧪 Testing Picamera2 as service user: {service_user}")
        
        result = subprocess.run(
            ["sudo", "-u", service_user, "python3", test_file],
            capture_output=True, text=True, timeout=10
        )
        
        print(f"  📤 Output: {result.stdout.strip()}")
        if result.stderr:
            print(f"  ⚠️ Errors: {result.stderr.strip()}")
            
        if result.returncode == 0:
            print("  ✅ Picamera2 is available to service")
        else:
            print("  ❌ Picamera2 not available to service")
            
    except Exception as e:
        print(f"  ❌ Error testing Picamera2: {e}")
    finally:
        os.unlink(test_file)

def check_recent_recordings():
    """Check for recent recording attempts in service logs"""
    print("\n🎬 RECENT RECORDING ATTEMPTS")
    print("=" * 50)
    
    try:
        # Get recent service logs
        result = subprocess.run(
            ["sudo", "journalctl", "-u", "ezrec-backend", "--since", "5 minutes ago", "--no-pager"],
            capture_output=True, text=True
        )
        
        logs = result.stdout
        recording_keywords = [
            "Recording started", "Recording stopped", "Picamera2 recording",
            "start_recording", "stop_recording", "recording_", ".mp4"
        ]
        
        relevant_logs = []
        for line in logs.split('\n'):
            if any(keyword in line for keyword in recording_keywords):
                relevant_logs.append(line)
        
        if relevant_logs:
            print(f"  📋 Found {len(relevant_logs)} recording-related log entries:")
            for log in relevant_logs[-10:]:  # Show last 10
                print(f"    {log}")
        else:
            print("  ❌ No recording-related logs found in last 5 minutes")
            
        # Check for errors
        error_keywords = ["error", "failed", "exception", "❌"]
        error_logs = []
        for line in logs.split('\n'):
            if any(keyword.lower() in line.lower() for keyword in error_keywords):
                error_logs.append(line)
        
        if error_logs:
            print(f"\n  ⚠️ Found {len(error_logs)} error entries:")
            for log in error_logs[-5:]:  # Show last 5 errors
                print(f"    {log}")
                
    except Exception as e:
        print(f"  ❌ Error checking logs: {e}")

def check_database_connectivity():
    """Test database connection and status table access"""
    print("\n🗄️ DATABASE CONNECTIVITY CHECK")
    print("=" * 50)
    
    # This should be run in the service environment with proper env vars
    try:
        # Extract service config
        result = subprocess.run(
            ["sudo", "-u", "michomanoly14892", "python3", "/opt/ezrec-backend/extract_service_config.py"],
            capture_output=True, text=True, cwd="/opt/ezrec-backend"
        )
        
        if result.returncode == 0:
            print("  ✅ Service config extraction successful")
            if "SUPABASE_URL" in result.stdout:
                print("  ✅ Supabase configuration found")
            else:
                print("  ⚠️ Supabase configuration may be incomplete")
        else:
            print(f"  ❌ Service config extraction failed: {result.stderr}")
            
    except Exception as e:
        print(f"  ❌ Error testing database connectivity: {e}")

def main():
    """Run all diagnostic checks"""
    print("🔍 EZREC RECORDING ISSUES DIAGNOSTIC")
    print("=" * 60)
    print("This script will help identify why recording file creation")
    print("and status updates are failing.")
    print("=" * 60)
    
    check_directories()
    check_service_user() 
    check_picamera2_availability()
    check_recent_recordings()
    check_database_connectivity()
    
    print("\n" + "=" * 60)
    print("🎯 DIAGNOSTIC COMPLETE")
    print("=" * 60)
    print("Please share this output to help resolve the remaining issues.")

if __name__ == "__main__":
    main() 