#!/bin/bash

echo "🔧 Fixing Supabase Compatibility Issue"
echo "======================================"

# Navigate to backend directory
cd ~/code/SmartCam-Soccer/backend

# Activate virtual environment
source venv/bin/activate

echo "Uninstalling conflicting packages..."
pip uninstall -y supabase gotrue httpx

echo "Installing compatible versions..."
pip install httpx==0.23.3
pip install supabase==1.0.3

echo "Testing Supabase connection..."
python3 -c "
from src.utils import supabase
try:
    result = supabase.table('system_status').select('*').limit(1).execute()
    print('✅ Supabase connection successful')
    print('Tables accessible:', len(result.data) if result.data else 0, 'records found')
except Exception as e:
    print('❌ Supabase connection failed:', str(e))
"

echo "✅ Supabase fix completed!" 