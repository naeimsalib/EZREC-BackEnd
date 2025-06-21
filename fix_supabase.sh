#!/bin/bash

echo "🔧 Fixing Supabase Compatibility Issue"
echo "======================================"

# Navigate to backend directory
cd ~/code/SmartCam-Soccer/backend

# Activate virtual environment
source venv/bin/activate

echo "Uninstalling all conflicting packages..."
pip uninstall -y supabase gotrue httpx supafunc storage3 postgrest httpcore h11

echo "Installing latest compatible versions..."
pip install httpx==0.25.2
pip install httpcore==1.0.9
pip install h11==0.16.0
pip install supabase==2.3.5
pip install supafunc==0.3.3
pip install storage3==0.7.7
pip install postgrest==0.15.1

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