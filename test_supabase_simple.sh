#!/bin/bash

echo "🧪 SIMPLE SUPABASE CONNECTION TEST"
echo "================================="

# Test Supabase connection with simple Python script
sudo -u ezrec bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 << 'EOF'
import os
from dotenv import load_dotenv

# Load environment
load_dotenv()

# Check variables
url = os.getenv('SUPABASE_URL')
anon_key = os.getenv('SUPABASE_ANON_KEY')
service_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

print('=== Environment Check ===')
print(f'SUPABASE_URL: {\"✅ Present\" if url else \"❌ Missing\"}')
print(f'SUPABASE_ANON_KEY: {\"✅ Present\" if anon_key else \"❌ Missing\"}')
print(f'SUPABASE_SERVICE_ROLE_KEY: {\"✅ Present\" if service_key else \"❌ Missing\"}')
print()

if url and anon_key:
    print('=== Testing Supabase Connection ===')
    try:
        from supabase import create_client
        supabase = create_client(url, anon_key)
        print('✅ Supabase client created successfully')
        
        # Test query
        try:
            result = supabase.table('bookings').select('*').limit(1).execute()
            print(f'✅ Supabase query successful - found {len(result.data)} records')
            
            # Test for active bookings
            from datetime import datetime, timedelta
            now = datetime.now().isoformat()
            future = (datetime.now() + timedelta(hours=1)).isoformat()
            
            active_bookings = supabase.table('bookings').select('*').gte('start_time', now).lte('start_time', future).execute()
            print(f'📅 Found {len(active_bookings.data)} upcoming bookings in next hour')
            
            if len(active_bookings.data) > 0:
                for booking in active_bookings.data:
                    print(f'  - Booking ID: {booking.get(\"id\", \"unknown\")} at {booking.get(\"start_time\", \"unknown time\")}')
            
        except Exception as e:
            print(f'❌ Supabase query failed: {e}')
            
    except Exception as e:
        print(f'❌ Supabase client creation failed: {e}')
else:
    print('❌ Missing required environment variables')
EOF
"

echo
echo "=== Current Service Status ==="
sudo systemctl status ezrec-backend --no-pager -l | head -6

echo
echo "=== Recent Service Logs ==="
sudo journalctl -u ezrec-backend --since "1 minute ago" --no-pager | grep -E "(Supabase|booking|ERROR|INFO)" | tail -10 