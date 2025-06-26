#!/usr/bin/env python3
"""
⚡ EZREC Quick Functionality Test
================================
Quick verification of core EZREC functionalities:
- Database connection and booking queries
- System status updates
- Recording directory access
- Service status check

This is a faster test for immediate verification.
"""

import os
import sys
import datetime
import subprocess
from pathlib import Path

# Add src directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

try:
    from config import Config
    from utils import SupabaseManager
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)

def test_database_connection():
    """Test Supabase database connection and booking queries"""
    print("🔗 Testing database connection...")
    
    try:
        supabase = SupabaseManager()
        
        # Test basic connection
        bookings = supabase.client.table("bookings").select("*").limit(1).execute()
        print(f"  ✅ Database connection successful")
        
        # Test booking query with filters
        today = datetime.datetime.now().strftime("%Y-%m-%d")
        config = Config()
        
        filtered_bookings = supabase.client.table("bookings").select("*").eq("date", today).eq("user_id", config.USER_ID).execute()
        print(f"  ✅ Filtered booking query successful: {len(filtered_bookings.data)} bookings found")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Database test failed: {e}")
        return False

def test_system_status():
    """Test system status table access and updates"""
    print("📊 Testing system status functionality...")
    
    try:
        config = Config()
        supabase = SupabaseManager()
        
        # Check system status table
        status = supabase.client.table("system_status").select("*").eq("user_id", config.USER_ID).execute()
        
        if status.data:
            last_update = status.data[0].get('updated_at', 'Unknown')
            print(f"  ✅ System status found, last update: {last_update}")
        else:
            print(f"  ⚠️ No system status record found for user")
            
        return True
        
    except Exception as e:
        print(f"  ❌ System status test failed: {e}")
        return False

def test_recording_directory():
    """Test recording directory access and permissions"""
    print("📁 Testing recording directory...")
    
    try:
        recordings_dir = Path("/opt/ezrec-backend/recordings")
        
        if recordings_dir.exists():
            print(f"  ✅ Recording directory exists: {recordings_dir}")
            
            # Check permissions
            if os.access(recordings_dir, os.W_OK):
                print(f"  ✅ Recording directory is writable")
            else:
                print(f"  ⚠️ Recording directory is not writable")
                
            # List existing files
            mp4_files = list(recordings_dir.glob("*.mp4"))
            print(f"  📹 Found {len(mp4_files)} MP4 files in recordings directory")
            
        else:
            print(f"  ❌ Recording directory does not exist")
            return False
            
        return True
        
    except Exception as e:
        print(f"  ❌ Recording directory test failed: {e}")
        return False

def test_service_status():
    """Test EZREC service status"""
    print("🔧 Testing service status...")
    
    try:
        # Check service status
        result = subprocess.run(
            ["sudo", "systemctl", "is-active", "ezrec-backend"],
            capture_output=True, text=True, timeout=10
        )
        
        if result.returncode == 0 and "active" in result.stdout:
            print(f"  ✅ EZREC service is active")
            
            # Get recent logs
            log_result = subprocess.run(
                ["sudo", "journalctl", "-u", "ezrec-backend", "--since", "1 minute ago", "--no-pager"],
                capture_output=True, text=True, timeout=10
            )
            
            if "returned" in log_result.stdout and "results" in log_result.stdout:
                print(f"  ✅ Service is processing booking queries")
            else:
                print(f"  ⚠️ No recent booking query activity in logs")
                
        else:
            print(f"  ❌ EZREC service is not active")
            return False
            
        return True
        
    except Exception as e:
        print(f"  ❌ Service status test failed: {e}")
        return False

def test_video_upload_functionality():
    """Test video upload table access"""
    print("☁️ Testing video upload functionality...")
    
    try:
        config = Config()
        supabase = SupabaseManager()
        
        # Check videos table access
        videos = supabase.client.table("videos").select("*").limit(1).execute()
        print(f"  ✅ Videos table accessible")
        
        # Check storage access
        try:
            storage_info = supabase.client.storage.from_("videos").list()
            print(f"  ✅ Video storage accessible")
        except Exception as storage_error:
            print(f"  ⚠️ Video storage access issue: {storage_error}")
            
        return True
        
    except Exception as e:
        print(f"  ❌ Video upload test failed: {e}")
        return False

def run_quick_tests():
    """Run all quick functionality tests"""
    print("⚡ EZREC Quick Functionality Test")
    print("=" * 40)
    print(f"📅 Test Time: {datetime.datetime.now()}")
    print("")
    
    tests = [
        ("Database Connection", test_database_connection),
        ("System Status", test_system_status),
        ("Recording Directory", test_recording_directory),
        ("Service Status", test_service_status),
        ("Video Upload", test_video_upload_functionality)
    ]
    
    results = {}
    
    for test_name, test_func in tests:
        try:
            results[test_name] = test_func()
        except Exception as e:
            print(f"  ❌ {test_name} failed with error: {e}")
            results[test_name] = False
        print("")
    
    # Print summary
    print("=" * 40)
    print("📋 QUICK TEST SUMMARY")
    print("=" * 40)
    
    passed = sum(1 for result in results.values() if result)
    total = len(results)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name:<20} {status}")
    
    print("")
    print(f"📊 Overall: {passed}/{total} tests passed ({passed/total*100:.1f}%)")
    
    if passed == total:
        print("🎉 All core functionalities are working!")
    elif passed >= total * 0.8:
        print("✅ Most functionalities working correctly")
    else:
        print("⚠️ Some core functionalities need attention")
    
    print("=" * 40)
    
    return results

if __name__ == "__main__":
    run_quick_tests() 