#!/bin/bash

echo "🚀 EZREC Complete Deployment Script"
echo "==================================="
echo "This script will install EZREC exactly as configured on your working Pi"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root: sudo $0"
    exit 1
fi

# Check if we're in the EZREC directory
if [ ! -f "install_ezrec.sh" ]; then
    echo "❌ Please run this script from the EZREC-BackEnd directory"
    echo "   Example: cd EZREC-BackEnd && sudo ./deploy_ezrec.sh"
    exit 1
fi

echo "📋 Pre-flight checks passed!"
echo "🔄 Starting complete EZREC installation..."
echo

# Step 1: Run main installation
echo "Step 1/5: Installing EZREC core system..."
if ./install_ezrec.sh; then
    echo "✅ Core installation complete"
else
    echo "❌ Core installation failed"
    exit 1
fi

# Step 2: Setup Pi environment
echo "Step 2/5: Setting up Raspberry Pi environment..."
if ./setup_pi_env.sh; then
    echo "✅ Pi environment setup complete"
else
    echo "❌ Pi environment setup failed"
    exit 1
fi

# Step 3: Fix any camera issues (just in case)
echo "Step 3/5: Applying camera fixes..."
if [ -f "fix_camera_issues.sh" ]; then
    ./fix_camera_issues.sh || echo "⚠️  Camera fixes had some warnings (may be normal)"
else
    echo "⚠️  Camera fix script not found (skipping)"
fi

# Step 4: Fix Picamera2 virtual environment
echo "Step 4/5: Fixing Picamera2 virtual environment..."
if [ -f "fix_picamera2_venv.sh" ]; then
    ./fix_picamera2_venv.sh || echo "⚠️  Picamera2 fix had warnings (may be normal)"
else
    echo "⚠️  Picamera2 fix script not found (skipping)"
fi

# Step 5: Fix Supabase compatibility
echo "Step 5/5: Fixing Supabase compatibility..."
if [ -f "fix_supabase_compatibility.sh" ]; then
    ./fix_supabase_compatibility.sh || echo "⚠️  Supabase fix had warnings (may be normal)"
else
    echo "⚠️  Supabase fix script not found (skipping)"
fi

echo
echo "🎉 EZREC Installation Complete!"
echo "==============================="
echo
echo "📝 NEXT STEPS:"
echo "1. Create your .env file:"
echo "   sudo ./create_env_file.sh"
echo
echo "2. Edit the .env file with your Supabase credentials:"
echo "   sudo nano /opt/ezrec-backend/.env"
echo
echo "3. Start the service:"
echo "   sudo systemctl start ezrec-backend"
echo "   sudo systemctl enable ezrec-backend"
echo
echo "4. Check status:"
echo "   ./check_recordings.sh"
echo
echo "🔧 TROUBLESHOOTING:"
echo "If you encounter issues, run:"
echo "   ./camera_diagnostic.py"
echo "   ./verify_installation.sh"
echo
echo "✅ Your Pi is now ready for EZREC!" 