#!/usr/bin/env python3
"""
Debug Camera Booking Issues
Identifies and fixes camera_id mismatches between bookings and EZREC configuration
"""
import sys
import os
sys.path.append('/opt/ezrec-backend/src')

from config import CAMERA_ID, USER_ID
from utils import supabase
from datetime import datetime

def debug_camera_bookings():
    """Debug and diagnose camera booking issues."""
    print("="*60)
    print("EZREC CAMERA BOOKING DIAGNOSTIC")
    print("="*60)
    
    # Current configuration
    print(f"Current EZREC Configuration:")
    print(f"  Camera ID: {CAMERA_ID}")
    print(f"  User ID: {USER_ID}")
    print()
    
    if not supabase:
        print("❌ ERROR: Supabase not connected")
        return
    
    print("✅ Supabase connected successfully")
    print()
    
    try:
        # 1. Check all bookings for this user
        print("1. All bookings for your user:")
        response = supabase.table('bookings').select('*').eq('user_id', USER_ID).execute()
        
        if not response.data:
            print("   ❌ No bookings found for your user ID")
            print("   💡 Check if bookings exist in your Supabase dashboard")
            return
        
        print(f"   Found {len(response.data)} total bookings")
        
        # Group by camera_id
        camera_ids = {}
        for booking in response.data:
            cid = booking.get('camera_id', 'NULL')
            if cid not in camera_ids:
                camera_ids[cid] = []
            camera_ids[cid].append(booking)
        
        print(f"   Camera IDs found in bookings:")
        for cid, bookings in camera_ids.items():
            print(f"     '{cid}': {len(bookings)} bookings")
        print()
        
        # 2. Check current camera_id specifically
        print(f"2. Bookings for current camera_id '{CAMERA_ID}':")
        exact_match = supabase.table('bookings').select('*').eq('camera_id', CAMERA_ID).eq('user_id', USER_ID).execute()
        
        if exact_match.data:
            print(f"   ✅ Found {len(exact_match.data)} bookings for current camera_id")
            for booking in exact_match.data:
                print(f"     - {booking['id']}: {booking['date']} {booking['start_time']}-{booking['end_time']} ({booking['status']})")
        else:
            print(f"   ❌ No bookings found for camera_id '{CAMERA_ID}'")
        print()
        
        # 3. Check confirmed bookings only
        print("3. Confirmed bookings:")
        confirmed = supabase.table('bookings').select('*').eq('user_id', USER_ID).eq('status', 'confirmed').execute()
        
        if confirmed.data:
            print(f"   Found {len(confirmed.data)} confirmed bookings:")
            for booking in confirmed.data:
                print(f"     - Camera: '{booking.get('camera_id', 'NULL')}' | {booking['date']} {booking['start_time']}-{booking['end_time']}")
                
                # Check if this is a future booking
                booking_date = booking['date']
                booking_start = booking['start_time']
                now = datetime.now()
                today = now.strftime('%Y-%m-%d')
                current_time = now.strftime('%H:%M')
                
                is_future = (booking_date > today) or (booking_date == today and booking_start >= current_time)
                status = "🔮 FUTURE" if is_future else "⏰ PAST"
                print(f"       Status: {status}")
        else:
            print("   ❌ No confirmed bookings found")
        print()
        
        # 4. Suggest fixes
        print("4. RECOMMENDED FIXES:")
        
        # If there are confirmed bookings but wrong camera_id
        if confirmed.data:
            wrong_camera_bookings = [b for b in confirmed.data if b.get('camera_id') != CAMERA_ID]
            
            if wrong_camera_bookings:
                print("   📋 OPTION A: Update EZREC configuration")
                most_common_camera_id = max(camera_ids.keys(), key=lambda k: len(camera_ids[k]))
                print(f"   Change CAMERA_ID in .env file to: {most_common_camera_id}")
                print()
                
                print("   📋 OPTION B: Update booking camera_ids")
                print("   Run this command to update your bookings:")
                print(f"   UPDATE bookings SET camera_id = '{CAMERA_ID}' WHERE user_id = '{USER_ID}';")
                print()
        
        # If no confirmed bookings
        else:
            pending_bookings = [b for b in response.data if b.get('status') != 'confirmed']
            if pending_bookings:
                print("   📋 ISSUE: Bookings exist but none are confirmed")
                print("   Check booking status in your dashboard")
            else:
                print("   📋 ISSUE: No bookings found")
                print("   Create a booking in your dashboard first")
        
    except Exception as e:
        print(f"❌ Error during diagnosis: {e}")
        import traceback
        traceback.print_exc()

def fix_camera_ids():
    """Fix camera_id mismatches by updating bookings."""
    print("\n" + "="*60)
    print("FIXING CAMERA ID MISMATCHES")
    print("="*60)
    
    try:
        # Get all user bookings
        response = supabase.table('bookings').select('*').eq('user_id', USER_ID).execute()
        
        if not response.data:
            print("No bookings to update")
            return
        
        # Find bookings with wrong camera_id
        wrong_bookings = [b for b in response.data if b.get('camera_id') != CAMERA_ID]
        
        if not wrong_bookings:
            print("✅ All bookings already have correct camera_id")
            return
        
        print(f"Found {len(wrong_bookings)} bookings with incorrect camera_id")
        print("Updating them now...")
        
        for booking in wrong_bookings:
            try:
                supabase.table('bookings').update({
                    'camera_id': CAMERA_ID
                }).eq('id', booking['id']).execute()
                
                print(f"  ✅ Updated booking {booking['id']}: '{booking.get('camera_id')}' → '{CAMERA_ID}'")
                
            except Exception as e:
                print(f"  ❌ Failed to update booking {booking['id']}: {e}")
        
        print(f"\n✅ Camera ID fix complete!")
        print("Restart EZREC service to pick up changes:")
        print("  sudo systemctl restart ezrec-backend")
        
    except Exception as e:
        print(f"❌ Error during fix: {e}")

if __name__ == "__main__":
    debug_camera_bookings()
    
    # Ask if user wants to fix camera IDs
    print("\n" + "="*60)
    try:
        fix_choice = input("Do you want to automatically fix camera_id mismatches? (y/n): ").lower()
        if fix_choice in ['y', 'yes']:
            fix_camera_ids()
        else:
            print("Skipping automatic fix. You can run this script again later.")
    except KeyboardInterrupt:
        print("\nSkipping automatic fix.") 