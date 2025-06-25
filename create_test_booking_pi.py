#!/usr/bin/env python3
"""
Create Test Booking for EZREC on Raspberry Pi
Works from the proper EZREC installation directory
"""
import sys
import os
import uuid
from datetime import datetime, timedelta

# Ensure we're using the proper EZREC paths
sys.path.insert(0, '/opt/ezrec-backend/src')
os.chdir('/opt/ezrec-backend')

try:
    from utils import supabase, logger
    from config import CAMERA_ID, USER_ID
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Make sure EZREC is properly installed at /opt/ezrec-backend")
    sys.exit(1)

def create_test_booking():
    """Create a test booking that starts in 2 minutes"""
    
    if not supabase:
        print("❌ Supabase connection not available")
        print("Check your .env file at /opt/ezrec-backend/.env")
        return False
    
    try:
        # Calculate times (start in 2 minutes, record for 1 minute)
        now_local = datetime.now()
        start_time = now_local + timedelta(minutes=2)
        end_time = start_time + timedelta(minutes=1)
        
        # Generate unique booking ID
        booking_id = str(uuid.uuid4())
        
        # Create booking data
        booking_data = {
            "id": booking_id,
            "user_id": USER_ID,
            "camera_id": CAMERA_ID,
            "date": start_time.strftime("%Y-%m-%d"),
            "start_time": start_time.strftime("%H:%M"),
            "end_time": end_time.strftime("%H:%M"),
            "status": "confirmed",
            "title": f"Pi Test Recording - {start_time.strftime('%H:%M')}",
            "description": "Camera fix verification test booking"
        }
        
        print("🎬 Creating test booking on Raspberry Pi...")
        print(f"📅 Date: {booking_data['date']}")
        print(f"⏰ Time: {booking_data['start_time']} - {booking_data['end_time']} (Local)")
        print(f"📹 Camera: {CAMERA_ID}")
        print(f"🆔 Booking ID: {booking_id}")
        print(f"🕐 Current time: {now_local.strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Insert booking
        response = supabase.table("bookings").insert(booking_data).execute()
        
        if response.data:
            print("✅ Test booking created successfully!")
            print(f"⏳ Recording will start in 2 minutes at {start_time.strftime('%H:%M:%S')}")
            print(f"📽️ Expected filename: rec_{booking_id}_{start_time.strftime('%Y%m%d_%H%M%S')}.mp4")
            print()
            print("📊 Monitor the recording:")
            print("sudo journalctl -u ezrec-backend -f")
            print()
            print("📂 Check files after completion:")
            print("ls -la /opt/ezrec-backend/temp/")
            print("ls -la /opt/ezrec-backend/recordings/")
            
            return True
        else:
            print("❌ Failed to create booking - no data returned")
            return False
            
    except Exception as e:
        print(f"❌ Error creating booking: {e}")
        if logger:
            logger.error(f"Pi booking creation failed: {e}")
        return False

def check_system_status():
    """Check Pi system status before creating booking"""
    print("🔍 Pre-flight System Check")
    print("=" * 30)
    
    # Check service status
    service_status = os.system("systemctl is-active --quiet ezrec-backend")
    if service_status == 0:
        print("✅ EZREC service: Running")
    else:
        print("❌ EZREC service: Not running")
        print("   Start with: sudo systemctl start ezrec-backend")
        return False
    
    # Check environment
    env_file = "/opt/ezrec-backend/.env"
    if os.path.exists(env_file):
        print("✅ Environment file: Found")
    else:
        print("❌ Environment file: Missing")
        print(f"   Create {env_file} with your Supabase credentials")
        return False
    
    # Check Supabase connection
    if supabase:
        try:
            # Test connection with a simple query
            response = supabase.table("bookings").select("id").limit(1).execute()
            print("✅ Supabase connection: Working")
        except Exception as e:
            print(f"❌ Supabase connection: Failed ({e})")
            return False
    else:
        print("❌ Supabase connection: Not initialized")
        return False
    
    return True

def main():
    """Main function"""
    print("🎯 EZREC Pi Test Booking Creator")
    print("=" * 40)
    
    # System check first
    if not check_system_status():
        print("\n💥 System check failed. Fix issues above before creating booking.")
        return 1
    
    print()
    
    # Show timing info
    now_local = datetime.now()
    print(f"🕐 Current time: {now_local.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"📍 Booking will be created for: {(now_local + timedelta(minutes=2)).strftime('%H:%M')}")
    print()
    
    # Create the booking
    success = create_test_booking()
    
    if success:
        print("\n🎉 Success! Your EZREC system will start recording in 2 minutes.")
        print("🎬 This will verify:")
        print("   ✓ Camera resource conflict is resolved")
        print("   ✓ Pi Camera can record successfully") 
        print("   ✓ Video is saved and uploaded properly")
        print()
        print("💡 Watch the magic happen:")
        print("sudo journalctl -u ezrec-backend -f")
    else:
        print("\n💥 Failed to create test booking. Check the error messages above.")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main()) 