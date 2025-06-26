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

class FixedSupabaseManager:
    """Fixed SupabaseManager that properly initializes its own client."""
    
    def __init__(self):
        # Initialize Supabase client directly
        try:
            from supabase import create_client
            self.client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
            print(f"✅ Supabase client initialized successfully")
        except Exception as e:
            print(f"❌ Failed to initialize Supabase client: {e}")
            self.client = None
    
    async def execute_query(self, query: str):
        """Execute a raw SQL query with proper WHERE clause parsing."""
        try:
            if not self.client:
                raise Exception("Supabase client not available")
            
            # Clean and normalize the query - handle multi-line queries
            clean_query = ' '.join(query.strip().split())
            print(f"🔍 Processing query: {clean_query[:100]}...")
            
            # For simple table queries, parse and execute
            if clean_query.upper().startswith('SELECT'):
                print("✅ Confirmed SELECT query detected")
                
                # Handle bookings queries with WHERE conditions
                if 'FROM bookings' in clean_query:
                    print("📋 Processing bookings table query")
                    query_builder = self.client.table("bookings").select("*")
                    
                    # Enhanced parsing - use regex for dynamic date/user_id matching
                    import re
                    
                    # Parse date condition dynamically - handle multi-line
                    date_match = re.search(r"date\s*=\s*'([^']+)'", clean_query, re.IGNORECASE | re.MULTILINE)
                    if date_match:
                        date_value = date_match.group(1)
                        query_builder = query_builder.eq("date", date_value)
                        print(f"📅 Filtering by date: {date_value}")
                    
                    # Parse user_id condition dynamically - handle multi-line and AND clause
                    user_id_match = re.search(r"(?:AND\s+)?user_id\s*=\s*'([^']+)'", clean_query, re.IGNORECASE | re.MULTILINE)
                    if user_id_match:
                        user_id_value = user_id_match.group(1)
                        query_builder = query_builder.eq("user_id", user_id_value)
                        print(f"👤 Filtering by user_id: {user_id_value}")
                    
                    # Add ordering
                    if "ORDER BY start_time ASC" in clean_query:
                        query_builder = query_builder.order("start_time", desc=False)
                        print("🔄 Ordering by start_time ASC")
                    
                    response = query_builder.execute()
                    print(f"✅ Bookings query executed successfully - returned {len(response.data)} results")
                    
                    # Add detailed logging of each booking found
                    if response.data:
                        for i, booking in enumerate(response.data):
                            print(f"  📋 Booking {i+1}: {booking['id']} - {booking['date']} {booking['start_time']}-{booking['end_time']}")
                    
                    return response.data
                else:
                    print(f"❌ Unsupported table in query: {clean_query}")
                    return []
            else:
                print(f"❌ Only SELECT queries supported. Received: {clean_query}")
                return []
                
        except Exception as e:
            print(f"❌ Query execution failed: {e}")
            raise

async def main():
    """Debug Supabase API calls"""
    print("🔍 EZREC Supabase API Debug")
    print("=" * 50)
    
    print(f"✅ Configuration loaded")
    print(f"📍 URL: {SUPABASE_URL}")
    print(f"👤 USER_ID: {USER_ID}")
    print(f"🔑 Using API Key: {SUPABASE_ANON_KEY[:20]}...")
    print(f"🔑 Key length: {len(SUPABASE_ANON_KEY)} chars")
    
    # Test using Fixed SupabaseManager
    print("\n🧪 Test 1: Fixed SupabaseManager - All bookings")
    try:
        db = FixedSupabaseManager()
        
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
    print("\n🧪 Test 2: Fixed SupabaseManager - Filter by date only")
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
    print("\n🧪 Test 3: Fixed SupabaseManager - Filter by user_id only")
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
    print("\n🧪 Test 4: Fixed SupabaseManager - EXACT orchestrator query")
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
    
    # Test 5: Direct Python client test (bypass SupabaseManager)
    print("\n🧪 Test 5: Direct Supabase Client - Bypass SupabaseManager")
    try:
        from supabase import create_client
        direct_client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
        
        # Direct API call
        response = direct_client.table("bookings")\
            .select("*")\
            .eq("date", "2025-06-25")\
            .eq("user_id", USER_ID)\
            .order("start_time")\
            .execute()
        
        print(f"✅ Direct client result: {len(response.data)} bookings")
        if response.data:
            for booking in response.data:
                print(f"  📋 {booking['id']}: {booking['start_time']}-{booking['end_time']}")
        else:
            print("  ❌ NO RESULTS from direct client either!")
            
    except Exception as e:
        print(f"❌ Direct client error: {e}")
        import traceback
        traceback.print_exc()
    
    # Test 6: Check current time and nearby bookings
    print("\n🧪 Test 6: Time-based analysis")
    current_time = datetime.now().strftime("%H:%M")
    print(f"⏰ Current time: {current_time}")
    
    try:
        # Get bookings for today with direct client
        response = direct_client.table("bookings")\
            .select("*")\
            .eq("date", "2025-06-25")\
            .order("start_time")\
            .execute()
        
        if response.data:
            print("📅 All bookings for today:")
            for booking in response.data:
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
    print("   • Results from direct client vs SupabaseManager")
    print("   • Any error messages or mismatches")

if __name__ == "__main__":
    asyncio.run(main()) 