#!/usr/bin/env python3
"""
EZREC Test Booking Creation with User Information
Creates a test booking 10 minutes from now for testing
"""
import asyncio
import sys
import os
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

try:
    from supabase import create_client
    
    # Get environment variables
    SUPABASE_URL = os.getenv('SUPABASE_URL')
    SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_ANON_KEY')
    USER_ID = os.getenv('USER_ID')
    USER_EMAIL = os.getenv('USER_EMAIL', 'michomanoly@gmail.com')
    
    if not all([SUPABASE_URL, SUPABASE_KEY, USER_ID]):
        print("❌ Missing required environment variables")
        print(f"   SUPABASE_URL: {'✅' if SUPABASE_URL else '❌'}")
        print(f"   SUPABASE_KEY: {'✅' if SUPABASE_KEY else '❌'}")
        print(f"   USER_ID: {'✅' if USER_ID else '❌'}")
        sys.exit(1)
    
    # Create Supabase client
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # Calculate test booking time (10 minutes from now)
    now = datetime.now()
    start_time = now + timedelta(minutes=10)
    end_time = start_time + timedelta(minutes=15)  # 15-minute recording
    
    # Create booking data
    booking_data = {
        'user_id': USER_ID,
        'date': start_time.strftime('%Y-%m-%d'),
        'start_time': start_time.strftime('%H:%M'),
        'end_time': end_time.strftime('%H:%M'),
        'camera_id': '0',
        'status': 'confirmed',
        'title': f'Test Recording - {now.strftime("%H:%M")}',
        'description': f'Automated test booking created at {now.strftime("%Y-%m-%d %H:%M:%S")}',
        'booking_type': 'test'
    }
    
    print("🎬 EZREC Test Booking Creation")
    print("=" * 40)
    print(f"📧 User: {USER_EMAIL}")
    print(f"🆔 User ID: {USER_ID}")
    print(f"⏰ Current Time: {now.strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    print("📝 Creating test booking:")
    print(f"   🗓️  Date: {booking_data['date']}")
    print(f"   ⏰ Start: {booking_data['start_time']}")
    print(f"   ⏰ End: {booking_data['end_time']}")
    print(f"   📷 Camera: {booking_data['camera_id']}")
    print(f"   📧 User: {booking_data['user_id']}")
    print(f"   📱 Status: {booking_data['status']}")
    print()
    
    # Insert booking
    print("📤 Inserting booking into database...")
    
    try:
        response = supabase.table("bookings").insert(booking_data).execute()
        
        if response.data:
            booking_id = response.data[0]['id']
            print("✅ Test booking created successfully!")
            print(f"   🆔 Booking ID: {booking_id}")
            print(f"   📅 Scheduled for: {booking_data['date']} {booking_data['start_time']}-{booking_data['end_time']}")
            print()
            print("🎯 Next Steps:")
            print("   1. Monitor service logs: sudo journalctl -u ezrec-backend -f")
            print("   2. Wait for recording to start at scheduled time")
            print("   3. Check videos table after recording completes")
            print()
            print("🔍 Service monitoring commands:")
            print("   sudo systemctl status ezrec-backend")
            print("   sudo journalctl -u ezrec-backend --lines=20")
            
        else:
            print("❌ Failed to create booking - no data returned")
            
    except Exception as e:
        print(f"❌ Error creating booking: {e}")
        sys.exit(1)
        
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Make sure you're running this from the project root directory")
    sys.exit(1)
except Exception as e:
    print(f"❌ Unexpected error: {e}")
    sys.exit(1) 