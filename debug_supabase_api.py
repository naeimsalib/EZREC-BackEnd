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

async def main():
    """Debug Supabase API calls"""
    print("🔍 EZREC Supabase API Debug")
    print("=" * 50)
    
    print(f"✅ Configuration loaded")
    print(f"📍 URL: {SUPABASE_URL}")
    print(f"👤 USER_ID: {USER_ID}")
    print(f"🔑 Using API Key: {SUPABASE_ANON_KEY[:20]}...")
    print(f"🔑 Key length: {len(SUPABASE_ANON_KEY)} chars")
    
    # Test using SupabaseManager (same as orchestrator)
    print("\n🧪 Test 1: SupabaseManager - All bookings")
    try:
        from utils import SupabaseManager
        
        db = SupabaseManager()
        
        # Test 1: Get all bookings
        query1 = "SELECT * FROM bookings ORDER BY date, start_time"
        result1 = await db.execute_query(query1)
        print(f"✅ Total bookings in database: {len(result1) if result1 else 0}")
        if result1:
            for booking in result1[:5]:  # Show first 5
                print(f"  📋 {booking.get('id', 'N/A')}: {booking.get('date', 'N/A')} {booking.get('start_time', 'N/A')}-{booking.get('end_time', 'N/A')} (user: {booking.get('user_id', 'N/A')})")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    
    # Test 2: Filter by date only
    print("\n🧪 Test 2: SupabaseManager - Filter by date only")
    try:
        query2 = "SELECT * FROM bookings WHERE date = '2025-06-25' ORDER BY start_time"
        result2 = await db.execute_query(query2)
        print(f"✅ Bookings for 2025-06-25: {len(result2) if result2 else 0}")
        if result2:
            for booking in result2:
                print(f"  📋 {booking.get('id', 'N/A')}: {booking.get('start_time', 'N/A')}-{booking.get('end_time', 'N/A')} (user: {booking.get('user_id', 'N/A')})")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    
    # Test 3: Filter by user_id only  
    print("\n🧪 Test 3: SupabaseManager - Filter by user_id only")
    try:
        query3 = f"SELECT * FROM bookings WHERE user_id = '{USER_ID}' ORDER BY date, start_time"
        result3 = await db.execute_query(query3)
        print(f"✅ Bookings for user {USER_ID}: {len(result3) if result3 else 0}")
        if result3:
            for booking in result3:
                print(f"  📋 {booking.get('id', 'N/A')}: {booking.get('date', 'N/A')} {booking.get('start_time', 'N/A')}-{booking.get('end_time', 'N/A')}")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    
    # Test 4: The EXACT orchestrator query
    print("\n🧪 Test 4: SupabaseManager - EXACT orchestrator query")
    try:
        query4 = f"""
        SELECT * FROM bookings 
        WHERE date = '2025-06-25' 
        AND user_id = '{USER_ID}'
        ORDER BY start_time ASC
        """
        
        print(f"📋 Query being tested:\n{query4.strip()}")
        result4 = await db.execute_query(query4)
        print(f"✅ Orchestrator query result: {len(result4) if result4 else 0} bookings")
        if result4:
            for booking in result4:
                print(f"  📋 {booking.get('id', 'N/A')}: {booking.get('start_time', 'N/A')}-{booking.get('end_time', 'N/A')}")
        else:
            print("  ❌ NO RESULTS - This explains why orchestrator shows '0 results'!")
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    
    # Test 5: Try variations of the problematic query
    print("\n🧪 Test 5: Query variations")
    
    variations = [
        f"SELECT * FROM bookings WHERE date = '2025-06-25' AND user_id = '{USER_ID}' ORDER BY start_time",
        f"SELECT * FROM bookings WHERE date='2025-06-25' AND user_id='{USER_ID}' ORDER BY start_time",
        f"SELECT * FROM bookings WHERE date = '2025-06-25' and user_id = '{USER_ID}' ORDER BY start_time",
        f"SELECT id, date, start_time, end_time, user_id FROM bookings WHERE date = '2025-06-25' AND user_id = '{USER_ID}'"
    ]
    
    for i, query in enumerate(variations, 1):
        try:
            print(f"  🔍 Variation {i}: {query[:80]}...")
            result = await db.execute_query(query)
            print(f"    ✅ Results: {len(result) if result else 0}")
        except Exception as e:
            print(f"    ❌ Error: {e}")
    
    # Test 6: Check current time and nearby bookings
    print("\n🧪 Test 6: Time-based analysis")
    current_time = datetime.now().strftime("%H:%M")
    print(f"⏰ Current time: {current_time}")
    
    try:
        # Get bookings for today
        query6 = f"SELECT * FROM bookings WHERE date = '2025-06-25' ORDER BY start_time"
        result6 = await db.execute_query(query6)
        
        if result6:
            print("📅 All bookings for today:")
            for booking in result6:
                start_time = booking.get('start_time', 'N/A')
                end_time = booking.get('end_time', 'N/A')
                user_id = booking.get('user_id', 'N/A')
                status = "🎯 MATCH" if user_id == USER_ID else "❌ Different user"
                print(f"  📋 {start_time}-{end_time} | User: {user_id[:8]}... | {status}")
        else:
            print("❌ No bookings found for today")
            
    except Exception as e:
        print(f"❌ Time analysis error: {e}")
    
    print("\n" + "=" * 50)
    print("🎯 Debug completed!")
    print("\n💡 Key findings will be above - look for:")
    print("   • Total bookings in database")
    print("   • Results for date filtering")  
    print("   • Results for user filtering")
    print("   • Results for EXACT orchestrator query")
    print("   • Any error messages or mismatches")

if __name__ == "__main__":
    asyncio.run(main()) 