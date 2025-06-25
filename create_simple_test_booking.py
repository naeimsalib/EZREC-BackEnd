#!/usr/bin/env python3
"""
Create Simple Test Booking for EZREC
Works with the actual database schema (including title column)
"""
import os
import sys
from datetime import datetime, timedelta

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'src'))

from utils import supabase, logger
from config import CAMERA_ID, USER_ID

def create_simple_test_booking():
    """Create a test booking that starts in 2 minutes."""
    try:
        now = datetime.now()
        start_time = now + timedelta(minutes=2)
        end_time = start_time + timedelta(minutes=1)
        
        # Use the actual database schema (with title column)
        booking_data = {
            'id': f'simple-test-{int(now.timestamp())}',
            'user_id': USER_ID,
            'camera_id': CAMERA_ID,
            'date': start_time.strftime('%Y-%m-%d'),
            'start_time': start_time.strftime('%H:%M'),
            'end_time': end_time.strftime('%H:%M'),
            'status': 'confirmed',
            'title': f'Test Recording {now.strftime("%H:%M")}',  # Required column
            'description': 'Automated test booking for storage upload verification',
            'booking_type': 'standard'
        }
        
        print(f"📅 Creating test booking:")
        print(f"   ID: {booking_data['id']}")
        print(f"   Camera: {CAMERA_ID}")
        print(f"   Date: {booking_data['date']}")
        print(f"   Time: {booking_data['start_time']} - {booking_data['end_time']}")
        print(f"   Recording starts in 2 minutes...")
        
        # Insert booking
        response = supabase.table('bookings').insert(booking_data).execute()
        
        if response.data:
            print(f"✅ Test booking created successfully!")
            print(f"📹 Recording will start at {start_time.strftime('%H:%M')} and last 1 minute")
            print(f"\n🔍 Monitor with: sudo journalctl -u ezrec-backend -f")
            return True
        else:
            print(f"❌ Failed to create booking")
            return False
            
    except Exception as e:
        print(f"❌ Error creating test booking: {e}")
        return False

if __name__ == "__main__":
    print("🎬 EZREC Simple Test Booking Creator")
    print("=" * 50)
    
    success = create_simple_test_booking()
    
    if success:
        print("\n🎯 Next steps:")
        print("1. Wait 2 minutes for recording to start")
        print("2. Recording will last 1 minute")
        print("3. Check for new file in /opt/ezrec-backend/recordings/")
        print("4. Run upload script to test storage upload")
    else:
        print("\n❌ Booking creation failed. Check your Supabase connection.") 