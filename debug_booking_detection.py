#!/usr/bin/env python3

"""
🔍 EZREC Booking Detection Debug Tool
This script tests the booking detection logic step by step
"""

import os
import sys
import json
from datetime import datetime, timedelta
from pathlib import Path

# Add the src directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

from config import Config
from utils import SupabaseManager

def print_header(title):
    """Print a formatted header."""
    print(f"\n{'='*60}")
    print(f"🔍 {title}")
    print(f"{'='*60}")

def print_section(title):
    """Print a formatted section."""
    print(f"\n📋 {title}")
    print("-" * 40)

def print_success(message):
    """Print success message."""
    print(f"✅ {message}")

def print_error(message):
    """Print error message."""
    print(f"❌ {message}")

def print_info(message):
    """Print info message."""
    print(f"ℹ️ {message}")

def test_booking_detection():
    """Test the booking detection logic step by step."""
    print_header("BOOKING DETECTION DEBUG")
    
    try:
        # Initialize components
        print_section("Initializing Components")
        config = Config()
        db = SupabaseManager()
        print_success("Config and SupabaseManager initialized")
        
        # Test basic connection
        print_section("Testing Supabase Connection")
        test_query = "SELECT COUNT(*) as count FROM bookings"
        result = db.execute_query(test_query)
        if result:
            print_success(f"Connection successful - {result[0]['count']} total bookings")
        else:
            print_error("Connection failed")
            return
        
        # Get current time info
        now = datetime.now()
        print_section("Current Time Analysis")
        print_info(f"Current time: {now}")
        print_info(f"Current time ISO: {now.isoformat()}")
        print_info(f"Current time formatted: {now.strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Test different time ranges
        time_ranges = [
            ("Next 5 minutes", now, now + timedelta(minutes=5)),
            ("Next 30 minutes", now, now + timedelta(minutes=30)),
            ("Next 2 hours", now, now + timedelta(hours=2)),
            ("Past 30 minutes to next 30 minutes", now - timedelta(minutes=30), now + timedelta(minutes=30)),
        ]
        
        for range_name, start_time, end_time in time_ranges:
            print_section(f"Testing Range: {range_name}")
            print_info(f"Start: {start_time}")
            print_info(f"End: {end_time}")
            
            # Test the exact query used in orchestrator
            query = f"""
                SELECT * FROM bookings 
                WHERE start_time <= '{end_time.isoformat()}'
                AND end_time >= '{start_time.isoformat()}'
                ORDER BY start_time ASC
            """
            
            print_info(f"Query: {query}")
            
            result = db.execute_query(query)
            if result:
                print_success(f"Found {len(result)} bookings")
                for booking in result:
                    print_info(f"  Booking ID: {booking.get('id')}")
                    print_info(f"  Start: {booking.get('start_time')}")
                    print_info(f"  End: {booking.get('end_time')}")
                    print_info(f"  User: {booking.get('user_id')}")
            else:
                print_error("No bookings found")
        
        # Test specific time slot mentioned by user (8:42 PM - 8:43 PM)
        print_section("Testing Specific Time Slot (8:42 PM - 8:43 PM)")
        
        # Try today's date with the specific time
        today = now.date()
        test_start = datetime.combine(today, datetime.strptime("20:42", "%H:%M").time())
        test_end = datetime.combine(today, datetime.strptime("20:43", "%H:%M").time())
        
        print_info(f"Testing for booking: {test_start} to {test_end}")
        
        # Check if there's a booking in this exact slot
        specific_query = f"""
            SELECT * FROM bookings 
            WHERE start_time <= '{test_end.isoformat()}'
            AND end_time >= '{test_start.isoformat()}'
        """
        
        print_info(f"Specific query: {specific_query}")
        result = db.execute_query(specific_query)
        
        if result:
            print_success(f"Found {len(result)} bookings for 8:42-8:43 PM slot")
            for booking in result:
                print_info(f"  Booking: {booking}")
        else:
            print_error("No booking found for 8:42-8:43 PM slot")
        
        # Show all bookings for debugging
        print_section("All Current Bookings")
        all_bookings_query = "SELECT * FROM bookings ORDER BY start_time ASC"
        all_bookings = db.execute_query(all_bookings_query)
        
        if all_bookings:
            print_success(f"Total bookings in database: {len(all_bookings)}")
            for i, booking in enumerate(all_bookings, 1):
                print_info(f"  {i}. ID: {booking.get('id')}")
                print_info(f"     Start: {booking.get('start_time')}")
                print_info(f"     End: {booking.get('end_time')}")
                print_info(f"     User: {booking.get('user_id')}")
                print_info(f"     Created: {booking.get('created_at')}")
        else:
            print_error("No bookings found in database")
        
        # Test the orchestrator's exact logic
        print_section("Testing Orchestrator Logic")
        
        # Simulate get_upcoming_bookings
        current_time = datetime.now()
        buffer_minutes = 2  # 2-minute buffer
        
        query = f"""
            SELECT * FROM bookings 
            WHERE start_time <= '{(current_time + timedelta(minutes=buffer_minutes)).isoformat()}'
            AND end_time >= '{current_time.isoformat()}'
            ORDER BY start_time ASC
        """
        
        print_info(f"Orchestrator query: {query}")
        upcoming = db.execute_query(query)
        
        if upcoming:
            print_success(f"Orchestrator would find {len(upcoming)} upcoming bookings")
            for booking in upcoming:
                print_info(f"  Booking: {booking.get('id')} ({booking.get('start_time')} - {booking.get('end_time')})")
                
                # Test should_start_recording logic
                booking_start = datetime.fromisoformat(booking['start_time'].replace('Z', '+00:00')).replace(tzinfo=None)
                time_until_start = (booking_start - current_time).total_seconds()
                
                print_info(f"  Time until start: {time_until_start} seconds")
                
                should_start = time_until_start <= 60  # 1-minute buffer
                print_info(f"  Should start recording: {should_start}")
        else:
            print_error("Orchestrator would find no upcoming bookings")
            
    except Exception as e:
        print_error(f"Debug failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_booking_detection() 