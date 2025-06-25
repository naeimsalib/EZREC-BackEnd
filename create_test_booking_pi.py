#!/usr/bin/env python3
"""
Create Test Booking for EZREC on Raspberry Pi
Creates a test booking that follows the exact EZREC workflow:
1. Creates booking with proper start_time/end_time
2. EZREC detects booking
3. Records video during booking time
4. Uploads to videos table + storage
5. Removes booking and local file
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

def create_test_booking(minutes_from_now=2, duration_minutes=1):
    """
    Create a test booking that starts in X minutes
    
    Args:
        minutes_from_now: How many minutes from now to start recording
        duration_minutes: How long to record (in minutes)
    """
    
    if not supabase:
        print("❌ Supabase connection not available")
        print("Check your .env file at /opt/ezrec-backend/.env")
        return False

    # Calculate booking times
    now = datetime.now()
    start_time = now + timedelta(minutes=minutes_from_now)
    end_time = start_time + timedelta(minutes=duration_minutes)
    
    # Create booking data following EZREC schema
    booking_data = {
        "id": str(uuid.uuid4()),
        "user_id": USER_ID,
        "camera_id": CAMERA_ID,
        "start_time": start_time.isoformat(),
        "end_time": end_time.isoformat(),
        "status": "confirmed",
        "created_at": now.isoformat(),
        "title": f"Test Recording {start_time.strftime('%H:%M')}",
        "description": "Automated test booking created by create_test_booking_pi.py"
    }
    
    try:
        # Insert booking into Supabase
        result = supabase.table("bookings").insert(booking_data).execute()
        
        if result.data:
            booking_id = result.data[0]['id']
            print(f"✅ Test booking created successfully!")
            print(f"   📅 Booking ID: {booking_id}")
            print(f"   ⏰ Start time: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"   ⏹️  End time: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"   📹 Camera ID: {CAMERA_ID}")
            print(f"   👤 User ID: {USER_ID}")
            print()
            print(f"🎬 Recording will start in {minutes_from_now} minutes and last {duration_minutes} minute(s)")
            print()
            print("📋 Next steps:")
            print("1. Monitor EZREC service: sudo journalctl -u ezrec-backend -f")
            print("2. Watch for 'Found booking' and 'Starting recording' messages")
            print("3. After recording, check videos table and storage bucket")
            print()
            print(f"⏱️  Time now: {now.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"⏱️  Recording starts: {start_time.strftime('%H:%M:%S')}")
            print(f"⏱️  Recording ends: {end_time.strftime('%H:%M:%S')}")
            
            return True
            
        else:
            print("❌ Failed to create booking - no data returned")
            return False
            
    except Exception as e:
        print(f"❌ Error creating test booking: {e}")
        return False

def show_existing_bookings():
    """Show existing bookings for debugging"""
    try:
        result = supabase.table("bookings").select("*").eq("user_id", USER_ID).execute()
        
        if result.data:
            print(f"📋 Found {len(result.data)} existing bookings:")
            for booking in result.data:
                print(f"   ID: {booking['id'][:8]}... Start: {booking['start_time']} End: {booking['end_time']}")
        else:
            print("📋 No existing bookings found")
            
    except Exception as e:
        print(f"❌ Error fetching bookings: {e}")

def check_system_status():
    """Check EZREC system status"""
    try:
        result = supabase.table("system_status").select("*").eq("camera_id", CAMERA_ID).execute()
        
        if result.data:
            status = result.data[0]
            print("📊 Current system status:")
            print(f"   Camera Status: {status.get('camera_status', 'unknown')}")
            print(f"   Recording Status: {status.get('recording_status', 'unknown')}")
            print(f"   Last Update: {status.get('updated_at', 'unknown')}")
        else:
            print("📊 No system status found")
            
    except Exception as e:
        print(f"❌ Error checking system status: {e}")

def main():
    print("🎬 EZREC Test Booking Creator for Raspberry Pi")
    print("==============================================")
    print()
    
    # Check configuration
    print(f"📹 Camera ID: {CAMERA_ID}")
    print(f"👤 User ID: {USER_ID}")
    print(f"🌐 Supabase: {'Connected' if supabase else 'Not connected'}")
    print()
    
    # Show current system status
    check_system_status()
    print()
    
    # Show existing bookings
    show_existing_bookings()
    print()
    
    # Get user input for timing
    try:
        minutes_from_now = input("⏰ Start recording in how many minutes? [2]: ").strip()
        if not minutes_from_now:
            minutes_from_now = 2
        else:
            minutes_from_now = int(minutes_from_now)
            
        duration_minutes = input("📹 Record for how many minutes? [1]: ").strip()
        if not duration_minutes:
            duration_minutes = 1
        else:
            duration_minutes = int(duration_minutes)
            
    except (ValueError, KeyboardInterrupt):
        print("\n❌ Invalid input or cancelled")
        return
    
    # Create the test booking
    success = create_test_booking(minutes_from_now, duration_minutes)
    
    if success:
        print("\n🎉 Test booking created successfully!")
        print("\n⚠️  Important reminders:")
        print("1. Ensure EZREC service is running: sudo systemctl status ezrec-backend")
        print("2. Check camera is working: sudo ./ultimate_camera_fix.sh")
        print("3. Monitor logs for recording activity")
        print("4. Booking will be automatically removed after recording")
        print("5. Video will be uploaded to Supabase storage/videos bucket")
    else:
        print("\n❌ Failed to create test booking")
        print("Check your configuration and network connection")

if __name__ == "__main__":
    main() 