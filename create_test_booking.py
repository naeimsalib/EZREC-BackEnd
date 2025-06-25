#!/usr/bin/env python3
"""
Create Test Booking for EZREC Camera Recording
This script creates a test booking that will start recording in 2 minutes and last for 1 minute
"""
import os
import sys
import time
from datetime import datetime, timedelta

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from utils import supabase, logger
from config import CAMERA_ID, USER_ID

def create_test_booking():
    """Create a test booking that starts in 2 minutes."""
    try:
        # Calculate times (start in 2 minutes, record for 1 minute)
        now = datetime.now()
        start_time = now + timedelta(minutes=2)
        end_time = start_time + timedelta(minutes=1)
        
        # Format for database
        booking_date = start_time.strftime('%Y-%m-%d')
        start_time_str = start_time.strftime('%H:%M')
        end_time_str = end_time.strftime('%H:%M')
        
        booking_data = {
            "id": f"test-booking-{int(time.time())}",
            "user_id": USER_ID,
            "camera_id": CAMERA_ID,
            "date": booking_date,
            "start_time": start_time_str,
            "end_time": end_time_str,
            "status": "confirmed",
            "title": "EZREC Test Recording",
            "description": "Automated test recording to verify storage upload",
            "created_at": now.isoformat(),
            "booking_type": "test"
        }
        
        print("🎬 Creating test booking for EZREC...")
        print(f"📅 Date: {booking_date}")
        print(f"⏰ Time: {start_time_str} - {end_time_str}")
        print(f"📹 Camera: {CAMERA_ID}")
        print(f"🆔 Booking ID: {booking_data['id']}")
        
        # Insert booking into Supabase
        response = supabase.table("bookings").insert(booking_data).execute()
        
        if response.data:
            print("\n✅ Test booking created successfully!")
            print(f"📋 Booking will start in 2 minutes: {start_time.strftime('%H:%M:%S')}")
            print(f"📋 Recording duration: 1 minute")
            print("\n🎯 What will happen:")
            print("1. EZREC will detect the booking in ~60 seconds")
            print("2. Recording will start automatically at the scheduled time")
            print("3. Video will be saved to Supabase Storage AND database")
            print("4. File will be cleaned up locally after upload")
            
            print("\n📱 Monitor the process:")
            print("sudo journalctl -u ezrec-backend -f")
            
            return True
        else:
            print("❌ Failed to create booking")
            return False
            
    except Exception as e:
        logger.error(f"Error creating test booking: {e}")
        print(f"❌ Error: {e}")
        return False

def check_service_status():
    """Check if EZREC service is running."""
    try:
        result = os.system("systemctl is-active --quiet ezrec-backend")
        if result == 0:
            print("✅ EZREC service is running")
            return True
        else:
            print("❌ EZREC service is not running")
            print("Start it with: sudo systemctl start ezrec-backend")
            return False
    except:
        return False

def main():
    print("🎬 EZREC Test Booking Creator")
    print("=" * 40)
    
    # Check service status
    if not check_service_status():
        return 1
    
    # Create test booking
    if create_test_booking():
        print("\n🚀 Test booking created! Watch for automatic recording...")
        return 0
    else:
        print("\n❌ Failed to create test booking")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 