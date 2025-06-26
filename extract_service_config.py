#!/usr/bin/env python3
"""
🔧 Extract EZREC Service Configuration
=====================================
This script extracts the working configuration from the running EZREC service
by analyzing service logs and creating a .env file for testing.
"""

import subprocess
import re
import os
from pathlib import Path

def extract_from_logs():
    """Extract configuration from service logs"""
    print("🔍 Extracting configuration from service logs...")
    
    try:
        # Get recent service logs
        result = subprocess.run(
            ["sudo", "journalctl", "-u", "ezrec-backend", "--since", "1 hour ago", "--no-pager"],
            capture_output=True, text=True, timeout=30
        )
        
        if result.returncode == 0:
            logs = result.stdout
            
            # Extract Supabase URL from HTTP requests
            supabase_url_match = re.search(r'HTTP Request: GET (https://\w+\.supabase\.co)', logs)
            supabase_url = supabase_url_match.group(1) if supabase_url_match else None
            
            # Extract user ID from logs
            user_id_match = re.search(r'user_id=eq\.([a-f0-9-]+)', logs)
            user_id = user_id_match.group(1) if user_id_match else None
            
            # We can use a known working anon key pattern or ask user to provide
            config = {}
            
            if supabase_url:
                config['SUPABASE_URL'] = supabase_url
                print(f"  ✅ Found Supabase URL: {supabase_url}")
            
            if user_id:
                config['USER_ID'] = user_id
                print(f"  ✅ Found User ID: {user_id}")
                
            # Set default camera ID
            config['CAMERA_ID'] = 'raspberry_pi_camera'
            print(f"  ✅ Set Camera ID: raspberry_pi_camera")
            
            return config
            
    except Exception as e:
        print(f"❌ Error extracting from logs: {e}")
    
    return {}

def get_anon_key_from_user():
    """Get the anonymous key from user input"""
    print("\n🔑 We need your Supabase anonymous key to complete the setup.")
    print("You can find this in your Supabase project settings > API")
    print("It usually starts with 'eyJ...'")
    print("")
    
    anon_key = input("Enter your Supabase ANON key: ").strip()
    
    if anon_key and anon_key.startswith('eyJ'):
        return anon_key
    else:
        print("⚠️ That doesn't look like a valid Supabase key")
        return None

def create_env_file(config):
    """Create .env file with extracted config"""
    print("\n📝 Creating .env file...")
    
    env_content = "# EZREC Environment Variables (extracted from running service)\n\n"
    
    for key, value in config.items():
        env_content += f"{key}={value}\n"
    
    # Add optional directories
    env_content += "\n# Optional directories\n"
    env_content += "LOGS_DIR=/opt/ezrec-backend/logs\n"
    env_content += "RECORDINGS_DIR=/opt/ezrec-backend/recordings\n"
    
    with open('.env', 'w') as f:
        f.write(env_content)
    
    print("✅ Created .env file successfully!")
    return True

def main():
    """Main extraction process"""
    print("🔧 EZREC Service Configuration Extractor")
    print("=" * 45)
    print()
    
    # Check if .env already exists
    if Path('.env').exists():
        print("✅ .env file already exists")
        response = input("Overwrite existing .env file? (y/N): ").lower()
        if response != 'y':
            print("Keeping existing .env file")
            return
    
    # Extract configuration from logs
    config = extract_from_logs()
    
    if not config.get('SUPABASE_URL'):
        print("❌ Could not extract Supabase URL from logs")
        print("The service may not have made recent API calls")
        
        # Manual input as fallback
        url = input("Enter your Supabase URL (https://xxx.supabase.co): ").strip()
        if url:
            config['SUPABASE_URL'] = url
    
    if not config.get('USER_ID'):
        print("❌ Could not extract User ID from logs")
        user_id = input("Enter your User ID: ").strip()
        if user_id:
            config['USER_ID'] = user_id
    
    # Get anonymous key
    anon_key = get_anon_key_from_user()
    if anon_key:
        config['SUPABASE_ANON_KEY'] = anon_key
    else:
        print("❌ Anonymous key is required for testing")
        return False
    
    # Create .env file
    if len(config) >= 3:  # URL, USER_ID, ANON_KEY minimum
        create_env_file(config)
        
        print("\n🎉 Setup complete! You can now run:")
        print("   python3 quick_functionality_test.py")
        print("   python3 test_complete_workflow.py")
        
        return True
    else:
        print("❌ Insufficient configuration extracted")
        return False

if __name__ == "__main__":
    main() 