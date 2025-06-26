#!/bin/bash

# 🔐 EZREC Supabase RLS Fix Script
# This script resolves the critical Row Level Security issue that prevents
# the EZREC system from accessing bookings using the anonymous API key
#
# Problem: RLS policies required auth.uid() = user_id, blocking anonymous access
# Solution: Create policies that allow anonymous access for EZREC functionality
#
# Date: 2025-06-25
# Issue: System returning "0 results" despite bookings existing in database

echo "🔐 EZREC Supabase RLS Fix Script"
echo "================================"
echo "This script helps fix Row Level Security policies that block EZREC access"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${YELLOW}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if migration file exists
check_migration_file() {
    MIGRATION_FILE="migrations/007_fix_rls_anonymous_access.sql"
    
    if [[ -f "$MIGRATION_FILE" ]]; then
        print_success "Found RLS migration file: $MIGRATION_FILE"
        return 0
    else
        print_error "Migration file not found: $MIGRATION_FILE"
        return 1
    fi
}

# Display the migration content
show_migration_content() {
    print_status "Migration content that needs to be applied to Supabase:"
    echo ""
    echo "==================== MIGRATION SQL ===================="
    cat migrations/007_fix_rls_anonymous_access.sql
    echo "======================================================="
    echo ""
}

# Instructions for manual application
show_manual_instructions() {
    print_warning "MANUAL APPLICATION REQUIRED"
    echo ""
    echo "To fix the RLS issue, you need to apply the migration to your Supabase database:"
    echo ""
    echo "1. 🌐 Open your Supabase project dashboard:"
    echo "   https://supabase.com/dashboard/project/iszmsaayxpdrovealrrp"
    echo ""
    echo "2. 📝 Go to 'SQL Editor' in the left sidebar"
    echo ""
    echo "3. 📋 Copy and paste the SQL migration shown above"
    echo ""
    echo "4. ▶️  Click 'Run' to execute the migration"
    echo ""
    echo "5. ✅ Verify the fix by checking if your EZREC system now shows bookings"
    echo ""
    print_warning "This migration fixes the core issue where:"
    echo "   • System showed 'returned 0 results' despite bookings existing"
    echo "   • Anonymous API key couldn't access bookings due to RLS policies"
    echo "   • auth.uid() = NULL didn't match user_id requirements"
    echo ""
}

# Check system status
check_system_status() {
    print_status "Checking EZREC system status..."
    
    if systemctl is-active --quiet ezrec-backend.service; then
        print_success "EZREC service is running"
        
        # Check recent logs for booking detection
        RECENT_LOGS=$(sudo journalctl -u ezrec-backend.service --since="2 minutes ago" --no-pager)
        
        if echo "$RECENT_LOGS" | grep -q "returned 0 results"; then
            print_error "System still showing '0 results' - RLS migration needed!"
            return 1
        elif echo "$RECENT_LOGS" | grep -q "returned [1-9][0-9]* results"; then
            print_success "System detecting bookings - RLS fix appears to be working!"
            return 0
        else
            print_warning "Cannot determine booking detection status from recent logs"
            return 2
        fi
    else
        print_warning "EZREC service is not running"
        return 3
    fi
}

# Test booking detection
test_booking_detection() {
    print_status "Testing booking detection..."
    
    if command -v python3 >/dev/null; then
        if [[ -f "test_auth.py" ]]; then
            print_status "Running authentication test..."
            cd /opt/ezrec-backend && source venv/bin/activate && cd ~/code/EZREC-BackEnd
            python3 test_auth.py | grep "Total rows accessible"
        else
            print_warning "test_auth.py not found - cannot run automated test"
        fi
    else
        print_warning "Python3 not available for testing"
    fi
}

# Main execution
main() {
    echo "🔍 Checking RLS migration status..."
    echo ""
    
    # Check if migration file exists
    if check_migration_file; then
        show_migration_content
        show_manual_instructions
        
        echo ""
        check_system_status
        STATUS=$?
        
        case $STATUS in
            0)
                print_success "🎉 RLS fix appears to be working! System is detecting bookings."
                ;;
            1)
                print_error "🚨 RLS migration still needed! Please apply the migration above."
                ;;
            2)
                print_warning "🤔 Status unclear - check logs manually or run test_auth.py"
                ;;
            3)
                print_warning "⏸️  Service not running - start it to test RLS status"
                ;;
        esac
    else
        print_error "Migration file missing - please ensure the repository is up to date"
        exit 1
    fi
    
    echo ""
    print_status "🔧 Additional troubleshooting commands:"
    echo "  • Check service logs: sudo journalctl -u ezrec-backend.service -f"
    echo "  • Test authentication: python3 test_auth.py"
    echo "  • Debug queries: python3 debug_supabase_api.py"
    echo ""
    print_success "Script completed!"
}

# Run main function
main "$@" 