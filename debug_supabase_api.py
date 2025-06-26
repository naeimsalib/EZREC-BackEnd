#!/usr/bin/env python3
"""
Debug Supabase API calls to identify the booking detection issue
"""
import os
import sys
from datetime import datetime
import asyncio

# Add the src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from config import SUPABASE_URL, SUPABASE_ANON_KEY, USER_ID
from supabase import create_client

async def main():
    """Debug Supabase API calls"""
    print("🔍 EZREC Supabase API Debug")
    print("=" * 50)
    
    # Initialize Supabase client
    supabase = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
    print(f"✅ Supabase client initialized")
    print(f"📍 URL: {SUPABASE_URL}")
    print(f"👤 USER_ID: {USER_ID}")
    
    # Test 1: Direct table query with no filters
    print("\n🧪 Test 1: Get all bookings (no filters)")
    try:
        response = supabase.table("bookings").select("*").execute()
        print(f"✅ Total bookings in database: {len(response.data)}")
        for booking in response.data:
            print(f"  📋 {booking['id']}: {booking['date']} {booking['start_time']}-{booking['end_time']} (user: {booking['user_id']})")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    # Test 2: Filter by date only
    print("\n🧪 Test 2: Filter by date only")
    try:
        response = supabase.table("bookings")\
            .select("*")\
            .eq("date", "2025-06-25")\
            .execute()
        print(f"✅ Bookings for 2025-06-25: {len(response.data)}")
        for booking in response.data:
            print(f"  📋 {booking['id']}: {booking['start_time']}-{booking['end_time']} (user: {booking['user_id']})")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    # Test 3: Filter by user_id only
    print("\n🧪 Test 3: Filter by user_id only")
    try:
        response = supabase.table("bookings")\
            .select("*")\
            .eq("user_id", USER_ID)\
            .execute()
        print(f"✅ Bookings for user {USER_ID}: {len(response.data)}")
        for booking in response.data:
            print(f"  📋 {booking['id']}: {booking['date']} {booking['start_time']}-{booking['end_time']}")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    # Test 4: Filter by date AND user_id (same as orchestrator)
    print("\n🧪 Test 4: Filter by date AND user_id (orchestrator query)")
    try:
        response = supabase.table("bookings")\
            .select("*")\
            .eq("date", "2025-06-25")\
            .eq("user_id", USER_ID)\
            .order("start_time")\
            .execute()
        print(f"✅ Bookings for 2025-06-25 + user {USER_ID}: {len(response.data)}")
        for booking in response.data:
            print(f"  📋 {booking['id']}: {booking['start_time']}-{booking['end_time']}")
    except Exception as e:
        print(f"❌ Error: {e}")
    
    # Test 5: Check the exact API URL being generated
    print("\n🧪 Test 5: Inspect the actual REST API call")
    print("URL that should be called:")
    api_url = f"{SUPABASE_URL}/rest/v1/bookings?select=*&date=eq.2025-06-25&user_id=eq.{USER_ID}&order=start_time"
    print(f"🔗 {api_url}")
    
    # Test 6: Try different date formats
    print("\n🧪 Test 6: Test different date formats")
    test_dates = ["2025-06-25", "2025-6-25", "2025/06/25"]
    for test_date in test_dates:
        try:
            response = supabase.table("bookings")\
                .select("*")\
                .eq("date", test_date)\
                .eq("user_id", USER_ID)\
                .execute()
            print(f"  📅 Date '{test_date}': {len(response.data)} results")
        except Exception as e:
            print(f"  📅 Date '{test_date}': Error - {e}")
    
    # Test 7: Check for case sensitivity issues
    print("\n🧪 Test 7: Test case sensitivity")
    try:
        # Test different user_id cases
        test_user_ids = [USER_ID, USER_ID.upper(), USER_ID.lower()]
        for test_user_id in test_user_ids:
            response = supabase.table("bookings")\
                .select("*")\
                .eq("date", "2025-06-25")\
                .eq("user_id", test_user_id)\
                .execute()
            print(f"  👤 user_id '{test_user_id}': {len(response.data)} results")
    except Exception as e:
        print(f"❌ Case sensitivity test error: {e}")
    
    # Test 8: Raw headers and authentication check
    print("\n🧪 Test 8: Authentication and headers check")
    print(f"🔑 Using API Key: {SUPABASE_ANON_KEY[:20]}...")
    print(f"🔑 Key length: {len(SUPABASE_ANON_KEY)} chars")
    
    # Test 9: Check if the issue is with the SupabaseManager implementation
    print("\n🧪 Test 9: Test SupabaseManager implementation")
    try:
        from utils import SupabaseManager
        
        db = SupabaseManager()
        
        # Test the exact query from orchestrator
        query = f"""
        SELECT * FROM bookings 
        WHERE date = '2025-06-25' 
        AND user_id = '{USER_ID}'
        ORDER BY start_time ASC
        """
        
        result = await db.execute_query(query)
        print(f"✅ SupabaseManager result: {len(result) if result else 0} bookings")
        if result:
            for booking in result:
                print(f"  📋 {booking['id']}: {booking['start_time']}-{booking['end_time']}")
    except Exception as e:
        print(f"❌ SupabaseManager test error: {e}")
    
    print("\n" + "=" * 50)
    print("🎯 Debug completed!")

if __name__ == "__main__":
    asyncio.run(main()) 