#!/usr/bin/env python3
"""
EZREC Raspberry Pi Setup Verification
Quick test to verify API keys and database connectivity are working
"""
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

def test_environment():
    """Test environment configuration"""
    print("🔧 Testing Environment Configuration...")
    
    try:
        from dotenv import load_dotenv
        load_dotenv()
        
        # Check key environment variables
        supabase_url = os.getenv('SUPABASE_URL')
        service_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
        anon_key = os.getenv('SUPABASE_ANON_KEY')
        user_id = os.getenv('USER_ID')
        camera_id = os.getenv('CAMERA_ID')
        
        print(f"   SUPABASE_URL: {'✅' if supabase_url else '❌'}")
        print(f"   SERVICE_ROLE_KEY: {'✅' if service_key else '❌'}")
        print(f"   ANON_KEY: {'✅' if anon_key else '❌'}")
        print(f"   USER_ID: {'✅' if user_id else '❌'}")
        print(f"   CAMERA_ID: {'✅' if camera_id else '❌'}")
        
        if all([supabase_url, service_key, user_id, camera_id]):
            print("✅ Environment configuration complete")
            return True
        else:
            print("❌ Environment configuration incomplete")
            return False
            
    except Exception as e:
        print(f"❌ Environment test failed: {e}")
        return False

def test_config_import():
    """Test config module import"""
    print("\n⚙️ Testing Config Module Import...")
    
    try:
        from config import USER_ID, CAMERA_ID, SUPABASE_URL, SUPABASE_KEY
        print("✅ Config module imported successfully")
        print(f"   User ID: {USER_ID}")
        print(f"   Camera ID: {CAMERA_ID}")
        print(f"   Supabase URL: {SUPABASE_URL}")
        return True
        
    except Exception as e:
        print(f"❌ Config import failed: {e}")
        return False

def test_supabase_connection():
    """Test Supabase database connection"""
    print("\n🌐 Testing Supabase Connection...")
    
    try:
        from utils import supabase
        
        if not supabase:
            print("❌ Supabase client not initialized")
            return False
        
        print("✅ Supabase client initialized")
        
        # Test simple query
        response = supabase.table('bookings').select('id').limit(1).execute()
        print("✅ Database query successful")
        
        # Test user-specific query
        from config import USER_ID
        response = supabase.table('system_status').select('user_id').eq('user_id', USER_ID).limit(1).execute()
        print("✅ User-specific query successful")
        
        return True
        
    except Exception as e:
        print(f"❌ Supabase connection failed: {e}")
        return False

def test_booking_detection():
    """Test booking detection functionality"""
    print("\n📋 Testing Booking Detection...")
    
    try:
        from utils import get_next_booking
        
        booking = get_next_booking()
        if booking:
            print(f"✅ Found booking: {booking['id']}")
            print(f"   Date: {booking['date']}")
            print(f"   Time: {booking['start_time']} - {booking['end_time']}")
        else:
            print("ℹ️  No active bookings found (this is normal)")
        
        return True
        
    except Exception as e:
        print(f"❌ Booking detection failed: {e}")
        return False

def test_camera_interface():
    """Test camera interface"""
    print("\n📹 Testing Camera Interface...")
    
    try:
        from camera_interface import CameraInterface
        
        camera = CameraInterface()
        if camera.camera_type:
            print(f"✅ Camera available: {camera.camera_type}")
            print(f"   Resolution: {camera.width}x{camera.height}@{camera.fps}fps")
            
            # Test frame capture
            frame = camera.capture_frame()
            if frame is not None:
                print("✅ Camera can capture frames")
            else:
                print("⚠️  Camera initialized but cannot capture frames")
            
            camera.release()
        else:
            print("❌ No camera available")
            return False
        
        return True
        
    except Exception as e:
        print(f"❌ Camera test failed: {e}")
        return False

def main():
    """Run all verification tests"""
    print("🎬 EZREC Raspberry Pi Setup Verification")
    print("=" * 50)
    
    tests = [
        ("Environment", test_environment),
        ("Config Import", test_config_import), 
        ("Supabase Connection", test_supabase_connection),
        ("Booking Detection", test_booking_detection),
        ("Camera Interface", test_camera_interface)
    ]
    
    results = {}
    
    for test_name, test_func in tests:
        try:
            results[test_name] = test_func()
        except Exception as e:
            print(f"❌ {test_name} test crashed: {e}")
            results[test_name] = False
    
    print("\n" + "=" * 50)
    print("📊 VERIFICATION RESULTS")
    print("=" * 50)
    
    all_passed = True
    for test_name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{test_name:<20} {status}")
        if not passed:
            all_passed = False
    
    print("=" * 50)
    
    if all_passed:
        print("🎉 All tests passed! Your EZREC system is ready.")
        print("\n🚀 Next steps:")
        print("   1. Monitor service: sudo journalctl -u ezrec-backend -f")
        print("   2. Create test booking: sudo -u ezrec python3 create_simple_test_booking.py")
        return 0
    else:
        print("⚠️  Some tests failed. Check the errors above.")
        print("\n🔧 Try running the environment fix:")
        print("   sudo bash fix_pi_env_setup.sh")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 