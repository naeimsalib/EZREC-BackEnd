#!/bin/bash

# SmartCam Backend Push Updates Script
# This script will commit and push all changes to the GitHub repository

echo "🚀 SmartCam Backend Push Updates Script"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Navigate to backend directory
cd ~/code/EZREC-BackEnd

# Check git status
print_status "Checking git status..."
git status

# Add all changes
print_status "Adding all changes..."
git add .

# Commit changes
print_status "Committing changes..."
git commit -m "Add comprehensive installation and testing script

- Fixed Supabase compatibility issues
- Added complete installation script with testing
- Created proper systemd service files
- Added camera device testing
- Added comprehensive system verification
- Fixed environment variable configuration
- Added troubleshooting and monitoring tools"

# Push to GitHub
print_status "Pushing to GitHub..."
git push origin main

print_success "✅ All changes pushed to GitHub successfully!"
echo ""
echo "📋 What was updated:"
echo "- install_and_test.sh: Complete installation and testing script"
echo "- Fixed Supabase version compatibility"
echo "- Added proper systemd service configurations"
echo "- Added comprehensive testing procedures"
echo ""
echo "🔗 Repository: https://github.com/naeimsalib/EZREC-BackEnd.git" 