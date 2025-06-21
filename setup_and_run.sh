#!/bin/bash

echo "Setting up your Python environment..."

# 0. Create .env file with required variables
echo "Creating .env file..."
cat > .env <<EOL
USER_EMAIL=michomanoly@gmail.com
USER_ID=65aa2e2a-e463-424d-b88f-0724bb0bea3a
SUPABASE_URL=https://iszmsaayxpdrovealrrp.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNjYwMTMsImV4cCI6MjA2Mzk0MjAxM30.5bE_fPBOgkNtEyjCieW328oxyDHWGpf2OTDWssJ_Npk
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlzem1zYWF5eHBkcm92ZWFscnJwIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODM2NjAxMywiZXhwIjoyMDYzOTQyMDEzfQ.tzm80_eIy2xho652OxV37ErGnxwOuUvE4-MIPWrdS0c
EOL

echo ".env file created."

# 1. Check for Python 3
if ! command -v python3 &> /dev/null
then
    echo "Python 3 is not installed."
    echo "On Raspberry Pi, run the following commands to install Python 3:"
    echo "sudo apt update"
    echo "sudo apt install python3 python3-venv python3-pip -y"
    exit 1
fi

# 2. Create a virtual environment
#python3 -m venv venv

# 3. Activate the virtual environment
#source venv/bin/activate

# 4. Upgrade pip
pip install --upgrade pip

# 5. Install dependencies
pip install -r requirements.txt

echo "Setup complete!"
# echo "If you are using a Raspberry Pi camera, make sure it is enabled using 'sudo raspi-config' > Interface Options > Camera."
echo "Starting the backend script..."

# 6. Run the backend script
python main.py