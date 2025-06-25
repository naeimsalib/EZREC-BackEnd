#!/usr/bin/env python3
"""
EZREC Supabase Connection Diagnostic Tool
Helps identify and resolve Supabase connection issues
"""
import sys
import os
from pathlib import Path

print("🔍 EZREC Supabase Connection Diagnostic")
print("=" * 50)

# Check current working directory
print(f"📁 Current directory: {os.getcwd()}")

# Check if we're in the right location
expected_dirs = [
    "/opt/ezrec-backend",
    "/home/michomanoly14892/code/EZREC-BackEnd",
    "~/code/EZREC-BackEnd"
]

print(f"📍 Expected directories:")
for dir_path in expected_dirs:
    expanded_path = os.path.expanduser(dir_path)
    exists = "✅" if os.path.exists(expanded_path) else "❌"
    print(f"   {exists} {expanded_path}")

print()

# Check environment files
env_files = [
    "/opt/ezrec-backend/.env",
    os.path.expanduser("~/code/EZREC-BackEnd/.env"),
    ".env"
]

print("🔧 Environment file check:")
for env_file in env_files:
    if os.path.exists(env_file):
        print(f"   ✅ Found: {env_file}")
        try:
            with open(env_file, 'r') as f:
                content = f.read()
                has_url = "SUPABASE_URL" in content
                has_service_key = "SUPABASE_SERVICE_ROLE_KEY" in content
                has_anon_key = "SUPABASE_ANON_KEY" in content
                has_user_id = "USER_ID" in content
                
                print(f"      - SUPABASE_URL: {'✅' if has_url else '❌'}")
                print(f"      - SUPABASE_SERVICE_ROLE_KEY: {'✅' if has_service_key else '❌'}")
                print(f"      - SUPABASE_ANON_KEY: {'✅' if has_anon_key else '❌'}")
                print(f"      - USER_ID: {'✅' if has_user_id else '❌'}")
        except Exception as e:
            print(f"      ❌ Error reading file: {e}")
    else:
        print(f"   ❌ Missing: {env_file}")

print()

# Check if we can import dependencies
print("📦 Dependency check:")

try:
    from dotenv import load_dotenv
    print("   ✅ python-dotenv available")
except ImportError:
    print("   ❌ python-dotenv missing")

try:
    from supabase import create_client
    print("   ✅ supabase-py available")
except ImportError as e:
    print(f"   ❌ supabase-py missing: {e}")

try:
    import storage3
    print("   ✅ storage3 available")
except ImportError:
    print("   ❌ storage3 missing")

print()

# Try to add src directory to path and test imports
print("🔧 EZREC module import test:")

# Try different src paths
src_paths = [
    "src",
    "./src",
    "/opt/ezrec-backend/src",
    os.path.expanduser("~/code/EZREC-BackEnd/src")
]

src_found = False
for src_path in src_paths:
    if os.path.exists(src_path) and os.path.isdir(src_path):
        print(f"   ✅ Found src directory: {src_path}")
        sys.path.insert(0, src_path)
        src_found = True
        break

if not src_found:
    print("   ❌ No src directory found")
    print("\n🔧 SOLUTION:")
    print("Make sure you're running this from the EZREC-BackEnd directory")
    print("Or run from: ~/code/EZREC-BackEnd")
    sys.exit(1)

# Try to import config
try:
    import config
    print("   ✅ config.py imported successfully")
    print(f"      - USER_ID: {getattr(config, 'USER_ID', 'NOT SET')}")
    print(f"      - CAMERA_ID: {getattr(config, 'CAMERA_ID', 'NOT SET')}")
    print(f"      - SUPABASE_URL: {'SET' if getattr(config, 'SUPABASE_URL', None) else 'NOT SET'}")
except ImportError as e:
    print(f"   ❌ config.py import failed: {e}")

# Try to import utils
try:
    import utils
    print("   ✅ utils.py imported successfully")
    
    # Check if supabase client is available
    if hasattr(utils, 'supabase') and utils.supabase:
        print("   ✅ Supabase client initialized in utils")
        
        # Test a simple query
        try:
            response = utils.supabase.table("bookings").select("id").limit(1).execute()
            print("   ✅ Database query successful")
        except Exception as e:
            print(f"   ❌ Database query failed: {e}")
    else:
        print("   ❌ Supabase client not available in utils")
        
except ImportError as e:
    print(f"   ❌ utils.py import failed: {e}")

print()
print("🎯 DIAGNOSTIC SUMMARY:")
print("=" * 30)

# Check if the service environment works
print("🔧 Service environment test:")
service_env_path = "/opt/ezrec-backend/.env"
if os.path.exists(service_env_path):
    print(f"   ✅ Service .env exists: {service_env_path}")
    
    # Load service environment
    try:
        from dotenv import load_dotenv
        load_dotenv(service_env_path)
        
        print("   🔍 Service environment variables:")
        print(f"      SUPABASE_URL: {'SET' if os.getenv('SUPABASE_URL') else 'NOT SET'}")
        print(f"      SUPABASE_SERVICE_ROLE_KEY: {'SET' if os.getenv('SUPABASE_SERVICE_ROLE_KEY') else 'NOT SET'}")
        print(f"      SUPABASE_ANON_KEY: {'SET' if os.getenv('SUPABASE_ANON_KEY') else 'NOT SET'}")
        print(f"      USER_ID: {os.getenv('USER_ID', 'NOT SET')}")
        
    except Exception as e:
        print(f"   ❌ Error loading service environment: {e}")
else:
    print(f"   ❌ Service .env missing: {service_env_path}")
    print("\n🔧 SOLUTION:")
    print("Run the environment setup script:")
    print("cd ~/code/EZREC-BackEnd")
    print("chmod +x fix_supabase_env_pi.sh")
    print("./fix_supabase_env_pi.sh")

print()
print("✅ Diagnostic complete!") 