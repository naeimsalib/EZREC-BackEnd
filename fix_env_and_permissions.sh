#!/bin/bash

echo "🔧 FIXING ENVIRONMENT AND PERMISSION ISSUES"
echo "==========================================="
echo "Fixing .env file and path permission problems..."
echo

# Fix .env file - add missing SUPABASE_ANON_KEY
echo "1. 🔧 Fixing .env File"
echo "--------------------"

# Check if SUPABASE_ANON_KEY exists
if ! grep -q "SUPABASE_ANON_KEY" /opt/ezrec-backend/.env; then
    echo "❌ Missing SUPABASE_ANON_KEY - adding it"
    
    # Add the anon key after the service role key
    sudo sed -i '/SUPABASE_SERVICE_ROLE_KEY/a SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjYwMTMsImV4cCI6MjA2Mzk0MjAxM30.qLd-Jh8eQRPJG4K19ZMSB1DdVEsIUG7H-C1CG0_4R7k' /opt/ezrec-backend/.env
    
    echo "✅ Added SUPABASE_ANON_KEY"
else
    echo "✅ SUPABASE_ANON_KEY already present"
fi

# Fix the path issue - change EZREC_BASE_DIR to /opt/ezrec-backend
echo "Fixing EZREC_BASE_DIR path..."
sudo sed -i 's|EZREC_BASE_DIR=/home/michomanoly14892/code/EZREC-BackEnd|EZREC_BASE_DIR=/opt/ezrec-backend|' /opt/ezrec-backend/.env
echo "✅ Fixed EZREC_BASE_DIR path"

echo "Current .env configuration:"
sudo grep -E '^(SUPABASE_|EZREC_BASE_DIR)' /opt/ezrec-backend/.env | sed 's/=.*/=***HIDDEN***/'
echo

# Test environment loading with fixed syntax
echo "2. 🧪 Testing Environment Loading"
echo "--------------------------------"
sudo -u ezrec bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 -c \"
import os
from dotenv import load_dotenv

# Load environment
load_dotenv()

# Check Supabase variables
url = os.getenv('SUPABASE_URL')
anon_key = os.getenv('SUPABASE_ANON_KEY')
service_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
base_dir = os.getenv('EZREC_BASE_DIR')

print('Environment variables:')
print(f'SUPABASE_URL: {\"Present\" if url else \"Missing\"}')
print(f'SUPABASE_ANON_KEY: {\"Present\" if anon_key else \"Missing\"}')
print(f'SUPABASE_SERVICE_ROLE_KEY: {\"Present\" if service_key else \"Missing\"}')
print(f'EZREC_BASE_DIR: {base_dir}')

if url and anon_key and service_key:
    print('✅ All Supabase credentials present')
else:
    print('❌ Missing Supabase credentials')
\"
"
echo

# Test Supabase connection
echo "3. 🌐 Testing Supabase Connection"
echo "--------------------------------"
sudo -u ezrec bash -c "
cd /opt/ezrec-backend
/opt/ezrec-backend/venv/bin/python3 -c \"
import os
from dotenv import load_dotenv

# Load environment
load_dotenv()

try:
    from supabase import create_client, Client
    
    url = os.getenv('SUPABASE_URL')
    key = os.getenv('SUPABASE_ANON_KEY')
    
    if url and key:
        supabase = create_client(url, key)
        print('✅ Supabase client created successfully')
        
        # Test a simple query
        try:
            result = supabase.table('bookings').select('*').limit(1).execute()
            print('✅ Supabase connection test successful')
            print(f'Found {len(result.data)} bookings in test query')
        except Exception as e:
            print(f'⚠️ Supabase query failed: {e}')
            print('This might be a table permissions issue')
    else:
        print('❌ Missing Supabase URL or key')
        
except Exception as e:
    print(f'❌ Supabase connection failed: {e}')
\"
"
echo

# Create logs directory with correct permissions
echo "4. 📂 Fixing Directory Permissions"
echo "---------------------------------"
sudo mkdir -p /opt/ezrec-backend/logs
sudo mkdir -p /opt/ezrec-backend/recordings
sudo chown -R ezrec:ezrec /opt/ezrec-backend/logs
sudo chown -R ezrec:ezrec /opt/ezrec-backend/recordings
echo "✅ Created logs and recordings directories with correct permissions"

# Restart service
echo "5. 🔄 Restarting Service"
echo "-----------------------"
sudo systemctl restart ezrec-backend
sleep 5

echo "Service status:"
sudo systemctl status ezrec-backend --no-pager | head -8
echo

# Check logs
echo "6. 📊 Checking Service Logs"
echo "--------------------------"
echo "Recent logs:"
sudo journalctl -u ezrec-backend --since "30 seconds ago" --no-pager | tail -15

echo
echo "🎯 ENVIRONMENT AND PERMISSIONS FIXED!"
echo "===================================="
echo "📋 What was fixed:"
echo "  ✅ Added missing SUPABASE_ANON_KEY"
echo "  ✅ Fixed EZREC_BASE_DIR path to /opt/ezrec-backend"
echo "  ✅ Created required directories with correct permissions"
echo "  ✅ Tested Supabase connection"
echo "  ✅ Service restarted"
echo
echo "🎬 Your service should now connect to Supabase!"
echo "Monitor logs: sudo journalctl -u ezrec-backend -f" 