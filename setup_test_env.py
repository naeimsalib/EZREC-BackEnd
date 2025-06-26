#!/usr/bin/env python3
"""
🔧 EZREC Test Environment Setup
==============================
This script sets up the environment for running EZREC tests by:
1. Checking for existing .env file in deployment directory
2. Extracting environment variables from running service
3. Creating a local .env file for testing
"""

import os
import subprocess
import sys
from pathlib import Path

def check_deployment_env():
    """Check if .env exists in deployment directory"""
    deployment_env = Path("/opt/ezrec-backend/.env")
    if deployment_env.exists():
        print(f"✅ Found .env in deployment directory: {deployment_env}")
        return deployment_env
    else:
        print("❌ No .env file found in deployment directory")
        return None

def extract_service_env():
    """Extract environment variables from running service"""
    print("🔍 Attempting to extract environment from running service...")
    
    try:
        # Get the PID of the running service
        result = subprocess.run(
            ["sudo", "systemctl", "show", "ezrec-backend", "--property=MainPID"],
            capture_output=True, text=True, timeout=10
        )
        
        if result.returncode == 0:
            pid_line = result.stdout.strip()
            if "MainPID=" in pid_line:
                pid = pid_line.split("=")[1]
                if pid != "0":
                    print(f"📋 Found service PID: {pid}")
                    
                    # Try to read environment from /proc/PID/environ
                    environ_file = f"/proc/{pid}/environ"
                    try:
                        with open(environ_file, 'rb') as f:
                            environ_data = f.read().decode('utf-8', errors='ignore')
                            env_vars = {}
                            
                            for item in environ_data.split('\0'):
                                if '=' in item and item.startswith(('SUPABASE_', 'USER_ID', 'CAMERA_ID')):
                                    key, value = item.split('=', 1)
                                    env_vars[key] = value
                            
                            if env_vars:
                                print(f"✅ Extracted {len(env_vars)} environment variables")
                                return env_vars
                            else:
                                print("⚠️ No relevant environment variables found in service")
                                
                    except PermissionError:
                        print("❌ Permission denied accessing service environment")
                    except Exception as e:
                        print(f"❌ Error reading service environment: {e}")
        
    except Exception as e:
        print(f"❌ Error extracting service environment: {e}")
    
    return {}

def create_local_env(env_vars=None):
    """Create local .env file for testing"""
    print("📝 Creating local .env file for testing...")
    
    env_file = Path(".env")
    
    if env_vars:
        # Use extracted variables
        with open(env_file, 'w') as f:
            f.write("# EZREC Environment Variables (extracted from service)\n")
            f.write("# Generated for testing purposes\n\n")
            for key, value in env_vars.items():
                f.write(f"{key}={value}\n")
        print(f"✅ Created .env file with {len(env_vars)} variables")
        return True
    else:
        # Create template
        template_content = """# EZREC Environment Variables
# Please fill in your Supabase credentials

SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
USER_ID=65aa2e2a-e463-424d-b88f-0724bb0bea3a
CAMERA_ID=raspberry_pi_camera

# Optional variables
LOGS_DIR=/opt/ezrec-backend/logs
RECORDINGS_DIR=/opt/ezrec-backend/recordings
"""
        
        with open(env_file, 'w') as f:
            f.write(template_content)
        
        print("📝 Created .env template file")
        print("⚠️ Please edit .env and add your Supabase credentials:")
        print("   - SUPABASE_URL")
        print("   - SUPABASE_ANON_KEY")
        return False

def copy_deployment_env(deployment_env_path):
    """Copy .env from deployment directory"""
    print("📋 Copying .env from deployment directory...")
    
    try:
        import shutil
        shutil.copy2(deployment_env_path, ".env")
        print("✅ Successfully copied .env file")
        return True
    except Exception as e:
        print(f"❌ Error copying .env file: {e}")
        return False

def verify_env():
    """Verify the environment setup"""
    print("\n🔍 Verifying environment setup...")
    
    if not Path(".env").exists():
        print("❌ No .env file found")
        return False
    
    # Try to load and check key variables
    try:
        with open(".env", 'r') as f:
            content = f.read()
        
        required_vars = ["SUPABASE_URL", "USER_ID", "CAMERA_ID"]
        found_vars = []
        
        for var in required_vars:
            if f"{var}=" in content and not content.split(f"{var}=")[1].split('\n')[0].strip().startswith('your_'):
                found_vars.append(var)
        
        print(f"✅ Found {len(found_vars)}/{len(required_vars)} required variables")
        
        if len(found_vars) == len(required_vars):
            print("🎉 Environment setup complete! You can now run tests.")
            return True
        else:
            missing = [var for var in required_vars if var not in found_vars]
            print(f"⚠️ Missing or incomplete variables: {missing}")
            return False
            
    except Exception as e:
        print(f"❌ Error verifying environment: {e}")
        return False

def main():
    """Main setup process"""
    print("🔧 EZREC Test Environment Setup")
    print("=" * 40)
    print()
    
    # Check if .env already exists locally
    if Path(".env").exists():
        print("✅ Local .env file already exists")
        if verify_env():
            return
        else:
            print("⚠️ Existing .env file needs completion")
    
    # Try to find deployment .env
    deployment_env = check_deployment_env()
    
    if deployment_env:
        # Copy from deployment
        if copy_deployment_env(deployment_env):
            verify_env()
            return
    
    # Try to extract from service
    env_vars = extract_service_env()
    
    # Create local .env
    success = create_local_env(env_vars)
    
    if success:
        verify_env()
    else:
        print("\n📝 Manual setup required:")
        print("1. Edit the .env file with your Supabase credentials")
        print("2. Run this script again to verify")
        print("3. Then run: python3 quick_functionality_test.py")

if __name__ == "__main__":
    main() 