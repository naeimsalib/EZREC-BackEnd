#!/bin/bash

echo "🔧 Fixing Supabase Compatibility Issue"
echo "======================================"

# Navigate to backend directory
cd ~/code/SmartCam-Soccer/backend

# Activate virtual environment
source venv/bin/activate

echo "Uninstalling all conflicting packages..."
pip uninstall -y supabase gotrue httpx supafunc storage3 postgrest httpcore h11

echo "Installing known working combination..."
pip install httpx==0.24.1
pip install httpcore==0.17.3
pip install h11==0.14.0
pip install gotrue==1.3.1
pip install postgrest==0.10.8
pip install storage3==0.5.3
pip install supafunc==0.3.3
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