#!/usr/bin/env python3
"""
Test Supabase authentication and API key permissions
"""
import os
import sys

# Add the src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from config import SUPABASE_URL, SUPABASE_ANON_KEY, USER_ID

def test_authentication():
    print("🔐 EZREC Authentication Test")
    print("=" * 40)
    
    print(f"📍 URL: {SUPABASE_URL}")
    print(f"🔑 API Key: {SUPABASE_ANON_KEY[:30]}...")
    print(f"🔑 Key Length: {len(SUPABASE_ANON_KEY)}")
    print(f"👤 USER_ID: {USER_ID}")
    
    try:
        from supabase import create_client
        client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
        print("✅ Supabase client created successfully")
        
        # Test 1: Simple table access
        print("\n🧪 Test 1: Basic table access")
        try:
            response = client.table("bookings").select("count", count="exact").execute()
            print(f"✅ Table access successful")
            print(f"📊 Total rows accessible: {response.count}")
        except Exception as e:
            print(f"❌ Table access failed: {e}")
        
        # Test 2: Check if we can see any bookings at all
        print("\n🧪 Test 2: Any bookings visible")
        try:
            response = client.table("bookings").select("*").limit(5).execute()
            print(f"✅ Query successful - {len(response.data)} bookings visible")
            for booking in response.data:
                print(f"  📋 {booking['id']}: {booking['date']} {booking['start_time']}")
        except Exception as e:
            print(f"❌ Query failed: {e}")
        
        # Test 3: RLS (Row Level Security) check
        print("\n🧪 Test 3: RLS Policy Check")
        try:
            # Try to access bookings without any filters
            response = client.table("bookings").select("*").execute()
            print(f"✅ Unfiltered query: {len(response.data)} bookings")
            
            # Try with user_id filter
            response = client.table("bookings").select("*").eq("user_id", USER_ID).execute()
            print(f"✅ User filtered query: {len(response.data)} bookings")
            
        except Exception as e:
            print(f"❌ RLS test failed: {e}")
        
        # Test 4: Direct REST API test
        print("\n🧪 Test 4: Direct REST API call")
        try:
            import requests
            
            headers = {
                "apikey": SUPABASE_ANON_KEY,
                "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
                "Content-Type": "application/json"
            }
            
            url = f"{SUPABASE_URL}/rest/v1/bookings?select=*&limit=5"
            response = requests.get(url, headers=headers)
            
            print(f"📡 Status Code: {response.status_code}")
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Direct API success: {len(data)} bookings")
                for booking in data[:3]:
                    print(f"  📋 {booking['id']}: {booking['date']} {booking['start_time']}")
            else:
                print(f"❌ Direct API failed: {response.text}")
                
        except Exception as e:
            print(f"❌ Direct API test failed: {e}")
            
    except Exception as e:
        print(f"❌ Client creation failed: {e}")
        
    print("\n" + "=" * 40)
    print("🎯 Authentication test completed!")

if __name__ == "__main__":
    test_authentication() 