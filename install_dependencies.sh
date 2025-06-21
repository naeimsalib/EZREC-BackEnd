#!/bin/bash

# Install missing Python dependencies for the SmartCam system
echo "Installing missing Python dependencies..."

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
fi

# Install supabase-py for test scripts
echo "Installing supabase-py..."
pip install supabase

# Install python-dotenv for environment variables
echo "Installing python-dotenv..."
pip install python-dotenv

echo "Dependencies installation complete!"
echo "You can now run the test scripts:"
echo "  python3 test_booking_logic.py"
echo "  python3 check_videos.py" 