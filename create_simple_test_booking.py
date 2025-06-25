#!/usr/bin/env python3
"""
Create a simple test booking for EZREC with timezone awareness
"""
import sys
import os
import uuid
from datetime import datetime, timedelta
import pytz

# Add the src directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

try:
    from utils import supabase, logger
    from config import CAMERA_ID, USER_ID
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Make sure you're running this from the EZREC directory")
    sys.exit(1)

def get_local_timezone():
    """Get the system's local timezone"""
    try:
        # Try to get timezone from system
        with open('/etc/timezone', 'r') as f:
            tz_name = f.read().strip()
        return pytz.timezone(tz_name)
    except:
        # Fallback to UTC if can't determine
        return pytz.UTC

def create_timezone_aware_booking():
    """Create a test booking with proper timezone handling"""
    
    if not supabase:
        print("❌ Supabase connection not available")
        return False
    
    try:
        # Get local timezone
        local_tz = get_local_timezone()
        
        # Create booking for 2 minutes from now
        now_local = datetime.now(local_tz)
        start_time = now_local + timedelta(minutes=2)
        end_time = start_time + timedelta(minutes=1)  # 1 minute recording
        
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
            "title": f"Test Recording - {start_time.strftime('%H:%M')}",
            "description": "Automated test booking for EZREC system verification",
            "timezone": str(local_tz),
            "created_at": now_local.isoformat()
        }
        
        print("🎬 Creating timezone-aware test booking...")
        print(f"📅 Date: {booking_data['date']}")
        print(f"⏰ Time: {booking_data['start_time']} - {booking_data['end_time']} ({local_tz})")
        print(f"📹 Camera: {CAMERA_ID}")
        print(f"🆔 Booking ID: {booking_id}")
        
        # Insert booking
        response = supabase.table("bookings").insert(booking_data).execute()
        
        if response.data:
            print("✅ Test booking created successfully!")
            print(f"⏳ Recording will start in 2 minutes at {start_time.strftime('%H:%M:%S')}")
            print("\n📊 Monitor the recording:")
            print("sudo journalctl -u ezrec-backend -f")
            print("\n📂 Check recordings after completion:")
            print("ls -la /opt/ezrec-backend/temp/")
            
            return True
        else:
            print("❌ Failed to create booking - no data returned")
            return False
            
    except Exception as e:
        print(f"❌ Error creating booking: {e}")
        logger.error(f"Booking creation failed: {e}")
        return False

def main():
    """Main function"""
    print("🎯 EZREC Timezone-Aware Test Booking Creator")
    print("=" * 50)
    
    # Show current system time info
    local_tz = get_local_timezone()
    now_local = datetime.now(local_tz)
    now_utc = datetime.now(pytz.UTC)
    
    print(f"🕐 Current local time: {now_local.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    print(f"🌍 Current UTC time: {now_utc.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    print(f"🗺️  System timezone: {local_tz}")
    print()
    
    # Create the booking
    success = create_timezone_aware_booking()
    
    if success:
        print("\n🎉 Success! Your EZREC system will start recording in 2 minutes.")
        print("Watch the logs to see the new filename format in action!")
    else:
        print("\n💥 Failed to create test booking. Check the error messages above.")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main()) 