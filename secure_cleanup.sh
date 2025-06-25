#!/bin/bash

echo "🚨 SECURITY CLEANUP - REMOVING EXPOSED JWT TOKENS"
echo "================================================="
echo "Removing JWT tokens from repository and regenerating keys..."
echo

# 1. Remove the JWT token from the script
echo "1. 🧹 Cleaning Script Files"
echo "---------------------------"
echo "Removing JWT tokens from fix_env_and_permissions.sh..."

# Replace the actual token with a placeholder
sed -i 's/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[^'"'"']*/YOUR_SUPABASE_ANON_KEY_HERE/g' fix_env_and_permissions.sh

echo "✅ JWT tokens replaced with placeholders"

# 2. Add the file to .gitignore to prevent future exposure
echo "2. 🔒 Updating Security"
echo "----------------------"
if ! grep -q ".env" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Environment files" >> .gitignore
    echo ".env" >> .gitignore
    echo ".env.*" >> .gitignore
fi

if ! grep -q "*.key" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Security files" >> .gitignore
    echo "*.key" >> .gitignore
    echo "*.pem" >> .gitignore
    echo "secrets.txt" >> .gitignore
fi

echo "✅ Updated .gitignore for security"

# 3. Create a template env file
echo "3. 📝 Creating Template Environment File"
echo "---------------------------------------"
cat > .env.template << 'EOF'
# EZREC Backend Environment Configuration Template
# =============================================================================
# SUPABASE CONFIGURATION (Required) - GET FROM YOUR SUPABASE DASHBOARD
# =============================================================================
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# =============================================================================
# USER CONFIGURATION
# =============================================================================
USER_ID=your_user_id_here
USER_EMAIL=your_email@example.com

# =============================================================================
# CAMERA CONFIGURATION
# =============================================================================
CAMERA_ID=raspberry_pi_camera_01
CAMERA_NAME=Raspberry Pi Camera
CAMERA_LOCATION=Home Office

# =============================================================================
# SYSTEM PATHS
# =============================================================================
EZREC_BASE_DIR=/opt/ezrec-backend

# =============================================================================
# LOGGING & DEBUG
# =============================================================================
DEBUG=true
LOG_LEVEL=DEBUG
EOF

echo "✅ Created .env.template file"

# 4. Commit the cleanup
echo "4. 📚 Committing Security Cleanup"
echo "--------------------------------"
git add .
git commit -m "🚨 SECURITY: Remove exposed JWT tokens and add .env.template

- Replaced actual JWT tokens with placeholders
- Added comprehensive .gitignore rules
- Created .env.template for secure setup
- This commit removes accidentally exposed Supabase credentials"

echo "✅ Security cleanup committed"

echo
echo "🚨 CRITICAL NEXT STEPS:"
echo "======================"
echo "1. 🔄 Push this security cleanup:"
echo "   git push origin main"
echo ""
echo "2. 🔑 REGENERATE YOUR SUPABASE KEYS:"
echo "   - Go to your Supabase Dashboard"
echo "   - Go to Settings > API"
echo "   - Click 'Reset API Key' for anon key"
echo "   - Update your .env files with new keys"
echo ""
echo "3. 🔍 Consider these additional security steps:"
echo "   - Review who has access to the GitHub repo"
echo "   - Check if any other services are using the old keys"
echo "   - Rotate any other potentially exposed credentials"
echo ""
echo "4. ⚠️ The exposed token was your ANON key which has limited permissions,"
echo "   but should still be regenerated as a security best practice." 