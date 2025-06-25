#!/usr/bin/env python3
"""
Create a simple test booking for EZREC with timezone awareness
Compatible with existing database schema
"""
import sys
import os
import uuid
from datetime import datetime, timedelta

# Add the src directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

try:
    from utils import supabase, logger
    from config import CAMERA_ID, USER_ID
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Make sure you're running this from the EZREC directory")
    sys.exit(1)

def create_simple_test_booking():
    """Create a test booking with proper local time handling"""
    
    if not supabase:
        print("❌ Supabase connection not available")
        return False
    
    try:
        # Use datetime.now() for local time
        now_local = datetime.now()
        start_time = now_local + timedelta(minutes=2)
        end_time = start_time + timedelta(minutes=1)  # 1 minute recording
        
        # Generate unique booking ID
        booking_id = str(uuid.uuid4())
        
        # Create booking data (compatible with existing schema)
        booking_data = {
            "id": booking_id,
            "user_id": USER_ID,
            "camera_id": CAMERA_ID,
            "date": start_time.strftime("%Y-%m-%d"),
            "start_time": start_time.strftime("%H:%M"),
            "end_time": end_time.strftime("%H:%M"),
            "status": "confirmed",
            "title": f"Test Recording - {start_time.strftime('%H:%M')}",
            "description": "Automated test booking for new filename format verification"
        }
        
        print("🎬 Creating test booking with new filename format...")
        print(f"📅 Date: {booking_data['date']}")
        print(f"⏰ Time: {booking_data['start_time']} - {booking_data['end_time']} (Local)")
        print(f"📹 Camera: {CAMERA_ID}")
        print(f"🆔 Booking ID: {booking_id}")
        print(f"🕐 Current local time: {now_local.strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Insert booking
        response = supabase.table("bookings").insert(booking_data).execute()
        
        if response.data:
            print("✅ Test booking created successfully!")
            print(f"⏳ Recording will start in 2 minutes at {start_time.strftime('%H:%M:%S')}")
            print(f"📽️  Expected filename: recording_{start_time.strftime('%Y%m%d_%H%M%S')}_{booking_id}.mp4")
            print("\n📊 Monitor the recording:")
            print("sudo journalctl -u ezrec-backend -f")
            print("\n📂 Check recordings after completion:")
            print("ls -la /opt/ezrec-backend/temp/")
            print("ls -la /opt/ezrec-backend/recordings/")
            
            return True
        else:
            print("❌ Failed to create booking - no data returned")
            return False
            
    except Exception as e:
        print(f"❌ Error creating booking: {e}")
        if logger:
            logger.error(f"Booking creation failed: {e}")
        return False

def main():
    """Main function"""
    print("🎯 EZREC Test Booking Creator (New Filename Format)")
    print("=" * 60)
    
    # Show current system time info
    now_local = datetime.now()
    
    print(f"🕐 Current local time: {now_local.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"📍 This will create a booking for {(now_local + timedelta(minutes=2)).strftime('%H:%M')}")
    print()
    
    # Create the booking
    success = create_simple_test_booking()
    
    if success:
        print("\n🎉 Success! Your EZREC system will start recording in 2 minutes.")
        print("🎬 Watch the logs to see the NEW filename format:")
        print("   recording_YYYYMMDD_HHMMSS_booking-id.mp4")
        print("\n💡 This test will verify:")
        print("   ✓ Timezone handling is working correctly")
        print("   ✓ New filename format is being used")
        print("   ✓ Camera service detects and processes bookings")
    else:
        print("\n💥 Failed to create test booking. Check the error messages above.")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main()) 