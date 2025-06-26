#!/usr/bin/env python3

import os
import sys
from datetime import datetime
from supabase import create_client

# Add the src directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

# Import config and logger
from config import SUPABASE_URL, SUPABASE_ANON_KEY, USER_ID

def debug_booking_query():
    """Debug the exact booking query to understand why 8:31-8:32pm booking isn't detected."""
    
    print("🔍 EZREC Booking Query Debug")
    print("=" * 50)
    
    # Initialize Supabase client
    supabase = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
    
    # Get current time info
    now = datetime.now()
    today = now.date()
    current_time = now.time()
    
    print(f"📅 Current Date: {today}")
    print(f"⏰ Current Time: {current_time}")
    print(f"👤 User ID: {USER_ID}")
    print()
    
    # Test 1: Raw query that orchestrator uses
    print("🔍 Test 1: Orchestrator Query (Raw)")
    query = f"""
    SELECT * FROM bookings 
    WHERE date = '{today}' 
    AND user_id = '{USER_ID}'
    ORDER BY start_time ASC
    """
    print(f"Query: {query.strip()}")
    
    try:
        # Direct Supabase query (what should work)
        response = supabase.table("bookings")\
            .select("*")\
            .eq("date", str(today))\
            .eq("user_id", USER_ID)\
            .order("start_time", desc=False)\
            .execute()
        
        print(f"✅ Direct Supabase query returned: {len(response.data)} bookings")
        for booking in response.data:
            print(f"   📋 Booking {booking['id']}: {booking['date']} {booking['start_time']}-{booking['end_time']}")
            
            # Check if this booking should trigger recording
            booking_start = datetime.strptime(booking['start_time'], '%H:%M:%S').time()
            booking_datetime = datetime.combine(today, booking_start)
            time_diff = (booking_datetime - now).total_seconds()
            
            print(f"      ⏱️  Time difference: {time_diff:.1f} seconds")
            print(f"      🎬 Should record: {-30 <= time_diff <= 30}")
            
    except Exception as e:
        print(f"❌ Direct query failed: {e}")
    
    print()
    
    # Test 2: Check what execute_query method actually does
    print("🔍 Test 2: Current execute_query Method")
    
    # Import the SupabaseManager to test execute_query
    from utils import SupabaseManager
    
    db = SupabaseManager()
    
    try:
        # This is what the orchestrator actually calls
        result = db.execute_query(query.strip())
        print(f"✅ execute_query returned: {len(result) if result else 0} bookings")
        
        if result:
            for booking in result:
                print(f"   📋 Booking {booking['id']}: {booking['date']} {booking['start_time']}-{booking['end_time']}")
        else:
            print("   ❌ No bookings returned by execute_query")
            
    except Exception as e:
        print(f"❌ execute_query failed: {e}")
    
    print()
    
    # Test 3: Check all bookings for user (no date filter)
    print("🔍 Test 3: All User Bookings (No Date Filter)")
    
    try:
        all_bookings = supabase.table("bookings")\
            .select("*")\
            .eq("user_id", USER_ID)\
            .order("date", desc=False)\
            .execute()
        
        print(f"✅ Total user bookings: {len(all_bookings.data)}")
        for booking in all_bookings.data:
            print(f"   📋 Booking {booking['id']}: {booking['date']} {booking['start_time']}-{booking['end_time']} (Status: {booking.get('status', 'N/A')})")
            
    except Exception as e:
        print(f"❌ All bookings query failed: {e}")
    
    print()
    print("🎯 Debug Complete!")

if __name__ == "__main__":
    debug_booking_query() 