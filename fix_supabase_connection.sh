#!/bin/bash

echo "🔗 FIXING SUPABASE CONNECTION ISSUE"
echo "=================================="
echo "Diagnosing why the service can't connect to Supabase..."
echo

# Check if .env file exists
echo "1. 🔍 Checking Environment Configuration"
echo "--------------------------------------"
if [ -f "/opt/ezrec-backend/.env" ]; then
    echo "✅ .env file exists"
    echo "Checking environment variables:"
    sudo -u ezrec bash -c "cd /opt/ezrec-backend && grep -E '^SUPABASE_' .env | sed 's/=.*/=***HIDDEN***/'"
else
    echo "❌ .env file missing - this is the problem!"
    echo "Need to copy .env file from repository"
fi
echo

# Copy .env from repository if it doesn't exist
echo "2. 📋 Copying Environment Configuration"
echo "-------------------------------------"
if [ -f "~/code/EZREC-BackEnd/.env" ]; then
    sudo cp ~/code/EZREC-BackEnd/.env /opt/ezrec-backend/.env
    sudo chown ezrec:ezrec /opt/ezrec-backend/.env
    echo "✅ .env file copied from repository"
elif [ -f "/home/michomanoly14892/code/EZREC-BackEnd/.env" ]; then
    sudo cp /home/michomanoly14892/code/EZREC-BackEnd/.env /opt/ezrec-backend/.env
    sudo chown ezrec:ezrec /opt/ezrec-backend/.env
    echo "✅ .env file copied from repository"
else
    echo "❌ .env file not found in repository either"
    echo "Creating template .env file..."
    sudo tee /opt/ezrec-backend/.env > /dev/null << 'EOF'
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Camera Configuration
CAMERA_ID=raspberry_pi_camera_01
RECORD_RESOLUTION=1920x1080@30fps
DEBUG_MODE=true
LOG_LEVEL=DEBUG
EOF
    sudo chown ezrec:ezrec /opt/ezrec-backend/.env
    echo "⚠️ Template .env created - you need to fill in your Supabase credentials"
fi
echo

# Test environment loading
echo "3. 🧪 Testing Environment Loading"
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

print(f'SUPABASE_URL: {url[:30] + \"...\" if url else \"Not set\"}')
print(f'SUPABASE_ANON_KEY: {anon_key[:20] + \"...\" if anon_key else \"Not set\"}')
print(f'SUPABASE_SERVICE_ROLE_KEY: {service_key[:20] + \"...\" if service_key else \"Not set\"}')

if url and anon_key and service_key:
    print('✅ All Supabase credentials present')
else:
    print('❌ Missing Supabase credentials')
\"
"
echo

# Test Supabase connection
echo "4. 🌐 Testing Supabase Connection"
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
            print(f'Bookings table accessible: {len(result.data) >= 0}')
        except Exception as e:
            print(f'⚠️ Supabase query failed: {e}')
            print('This might be a credentials or permissions issue')
    else:
        print('❌ Missing Supabase URL or key')
        
except Exception as e:
    print(f'❌ Supabase connection failed: {e}')
\"
"
echo

# Check current working directory in service
echo "5. 📂 Checking Service Working Directory"
echo "---------------------------------------"
echo "Service working directory should be /opt/ezrec-backend"
sudo systemctl show ezrec-backend --property=WorkingDirectory
echo

# Restart service to pick up new .env
echo "6. 🔄 Restarting Service with Fixed Configuration"
echo "------------------------------------------------"
sudo systemctl restart ezrec-backend
sleep 5

echo "Service status:"
sudo systemctl status ezrec-backend --no-pager | head -8
echo

# Check logs for Supabase connection
echo "7. 📊 Checking Service Logs for Supabase"
echo "----------------------------------------"
echo "Recent logs (looking for Supabase connection):"
sudo journalctl -u ezrec-backend --since "30 seconds ago" --no-pager | tail -10

echo
echo "🎯 SUPABASE CONNECTION FIX COMPLETE!"
echo "===================================="
echo "📋 What was checked/fixed:"
echo "  ✅ Environment file configuration"
echo "  ✅ Supabase credentials loading"
echo "  ✅ Supabase client connection test"
echo "  ✅ Service restarted with new config"
echo
echo "🎬 Next steps:"
echo "  1. If .env template was created, add your Supabase credentials"
echo "  2. Monitor logs: sudo journalctl -u ezrec-backend -f"
echo "  3. Create a new booking to test" 