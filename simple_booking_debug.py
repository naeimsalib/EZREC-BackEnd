#!/usr/bin/env python3

"""
🔍 Simple EZREC Booking Debug - No Environment Dependencies
Analyze the booking detection logic issues
"""

from datetime import datetime, timedelta

def print_header(title):
    print(f"\n{'='*60}")
    print(f"🔍 {title}")
    print(f"{'='*60}")

def print_section(title):
    print(f"\n📋 {title}")
    print("-" * 40)

def print_info(message):
    print(f"ℹ️ {message}")

def print_error(message):
    print(f"❌ {message}")

def analyze_orchestrator_logic():
    """Analyze the orchestrator's booking detection logic."""
    print_header("ORCHESTRATOR LOGIC ANALYSIS")
    
    # Current time simulation
    now = datetime.now()
    print_section("Current Time Analysis")
    print_info(f"Current time: {now}")
    print_info(f"Current date: {now.date()}")
    print_info(f"Current time: {now.time()}")
    
    # Test the orchestrator's get_upcoming_bookings query format
    print_section("Orchestrator Query Format Analysis")
    
    today = now.date()
    current_time = now.time()
    
    # This is the query format from orchestrator.py line 210-217
    query_format = f"""
    SELECT * FROM bookings 
    WHERE date = '{today}' 
    AND user_id = 'USER_ID_HERE'
    ORDER BY start_time ASC
    """
    
    print_info("Orchestrator uses this query format:")
    print_info(query_format)
    
    print_section("Potential Issues Identified")
    
    print_error("ISSUE 1: Query Format Mismatch")
    print_info("  - Orchestrator queries by 'date' and 'start_time' as separate columns")
    print_info("  - But your test mentioned '8:42 PM - 8:43 PM' which suggests timestamp format")
    print_info("  - Database might use 'start_time' and 'end_time' as full timestamps")
    
    print_error("ISSUE 2: Time Format Inconsistency")
    print_info("  - Orchestrator expects 'date' as YYYY-MM-DD")
    print_info("  - Orchestrator expects 'start_time' as HH:MM:SS")
    print_info("  - But database might store as full ISO timestamps")
    
    print_error("ISSUE 3: Time Zone Issues")
    print_info("  - No timezone handling in orchestrator")
    print_info("  - Database might store UTC timestamps")
    print_info("  - Local time vs UTC mismatch")
    
    print_error("ISSUE 4: should_start_recording Logic")
    print_section("Recording Start Logic Analysis")
    
    # Simulate booking detection logic
    test_booking = {
        'date': '2024-01-15',
        'start_time': '20:42:00',
        'end_time': '20:43:00'
    }
    
    print_info("Test booking: 8:42 PM - 8:43 PM today")
    
    # This is the logic from should_start_recording (line 226-244)
    try:
        booking_date = datetime.strptime(test_booking['date'], '%Y-%m-%d').date()
        booking_start = datetime.strptime(test_booking['start_time'], '%H:%M:%S').time()
        booking_datetime = datetime.combine(booking_date, booking_start)
        
        time_diff = (booking_datetime - now).total_seconds()
        
        print_info(f"Booking datetime: {booking_datetime}")
        print_info(f"Time difference: {time_diff} seconds")
        print_info(f"Would start recording: {-30 <= time_diff <= 30}")
        
    except Exception as e:
        print_error(f"Error in start logic: {e}")
    
    print_section("Database Schema Investigation Needed")
    print_info("To fix this, we need to check:")
    print_info("1. What columns exist in the bookings table?")
    print_info("2. What format are start_time/end_time stored in?")
    print_info("3. Are they separate date/time columns or full timestamps?")
    print_info("4. What timezone is used?")
    
    print_section("Recommended Next Steps")
    print_info("1. Run: python3 ezrec_diagnostics.py")
    print_info("2. Check the Supabase dashboard to see actual booking data")
    print_info("3. Verify the database schema matches orchestrator expectations")
    print_info("4. Test with a booking created right now for immediate testing")

if __name__ == "__main__":
    analyze_orchestrator_logic() 