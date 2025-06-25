#!/usr/bin/env python3
"""
Debug script to troubleshoot booking detection issues
Run on Raspberry Pi to diagnose why bookings aren't being found
"""

import sys
import os
from datetime import datetime

# Set working directory and path
os.chdir('/opt/ezrec-backend')
sys.path.insert(0, '/opt/ezrec-backend/src')

def debug_bookings():
    print("=== EZREC Booking Detection Debug ===")
    
    try:
        # Import configuration
        from config import USER_ID, CAMERA_ID, SUPABASE_URL
        print(f"✓ Config loaded:")
        print(f"  USER_ID: {USER_ID}")
        print(f"  CAMERA_ID: {CAMERA_ID}")
        print(f"  SUPABASE_URL: {SUPABASE_URL}")
        
        # Import utils
        from utils import supabase, local_now
        print(f"✓ Supabase client: {'Available' if supabase else 'NOT AVAILABLE'}")
        
        if not supabase:
            print("❌ CRITICAL: Supabase client not available!")
            return
        
        # Check current time
        now = local_now()
        today = now.strftime('%Y-%m-%d')
        current_time = now.strftime('%H:%M')
        print(f"✓ Current time: {now} (Local)")
        print(f"  Today: {today}")
        print(f"  Current time: {current_time}")
        
        # Test database connection
        print("\n--- Testing Database Connection ---")
        try:
            test_response = supabase.table("bookings").select("count", count="exact").execute()
            print(f"✓ Database connection successful")
            print(f"  Total bookings in database: {test_response.count}")
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return
        
        # Get all bookings for debugging
        print("\n--- All Bookings for User ---")
        try:
            all_bookings = supabase.table("bookings")\
                .select("*")\
                .eq("user_id", USER_ID)\
                .order("date, start_time")\
                .execute()
            
            print(f"Found {len(all_bookings.data)} total bookings for user")
            for booking in all_bookings.data:
                print(f"  Booking: {booking['id'][:8]}... | {booking['date']} {booking['start_time']}-{booking['end_time']} | Status: {booking['status']} | Camera: {booking['camera_id']}")
        except Exception as e:
            print(f"❌ Failed to get all bookings: {e}")
            return
        
        # Test specific filters
        print(f"\n--- Testing Booking Filters ---")
        
        # Filter 1: Camera ID
        print(f"Filter 1: camera_id = '{CAMERA_ID}'")
        try:
            camera_bookings = supabase.table("bookings")\
                .select("*")\
                .eq("camera_id", CAMERA_ID)\
                .execute()
            print(f"  Found {len(camera_bookings.data)} bookings for camera {CAMERA_ID}")
        except Exception as e:
            print(f"  ❌ Camera filter failed: {e}")
        
        # Filter 2: Status
        print(f"Filter 2: status = 'confirmed'")
        try:
            confirmed_bookings = supabase.table("bookings")\
                .select("*")\
                .eq("camera_id", CAMERA_ID)\
                .eq("status", "confirmed")\
                .execute()
            print(f"  Found {len(confirmed_bookings.data)} confirmed bookings for camera {CAMERA_ID}")
        except Exception as e:
            print(f"  ❌ Status filter failed: {e}")
        
        # Filter 3: Date filter
        print(f"Filter 3: date >= '{today}'")
        try:
            date_bookings = supabase.table("bookings")\
                .select("*")\
                .eq("camera_id", CAMERA_ID)\
                .eq("status", "confirmed")\
                .gte("date", today)\
                .execute()
            print(f"  Found {len(date_bookings.data)} bookings from today onwards")
            for booking in date_bookings.data:
                print(f"    {booking['date']} {booking['start_time']}-{booking['end_time']}")
        except Exception as e:
            print(f"  ❌ Date filter failed: {e}")
        
        # Test the actual get_next_booking function
        print(f"\n--- Testing get_next_booking Function ---")
        try:
            from utils import get_next_booking
            next_booking = get_next_booking()
            print(f"get_next_booking() result: {next_booking}")
            
            if next_booking:
                print(f"  Found booking: {next_booking['id']}")
                print(f"  Date/Time: {next_booking['date']} {next_booking['start_time']}-{next_booking['end_time']}")
            else:
                print("  No booking found - investigating why...")
                
                # Manual time comparison test
                print(f"\n  Manual Time Comparison Test:")
                for booking in date_bookings.data:
                    booking_date = booking['date']
                    booking_start = booking['start_time']
                    
                    print(f"    Booking: {booking_date} {booking_start}")
                    print(f"    Today: {today}, Current time: {current_time}")
                    
                    if booking_date == today:
                        print(f"      Same date - comparing times: '{booking_start}' >= '{current_time}' = {booking_start >= current_time}")
                    else:
                        print(f"      Future date - should be valid")
                
        except Exception as e:
            print(f"  ❌ get_next_booking failed: {e}")
            import traceback
            traceback.print_exc()
        
        print("\n=== Debug Complete ===")
        
    except Exception as e:
        print(f"❌ Debug script failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    debug_bookings() 