#!/usr/bin/env python3
"""
Script to check video files and database entries
"""

import os
import datetime
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
USER_ID = os.getenv("USER_ID")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def check_local_videos():
    """Check what video files exist locally"""
    print("=" * 50)
    print("LOCAL VIDEO FILES")
    print("=" * 50)
    
    temp_dir = "temp"
    if not os.path.exists(temp_dir):
        print(f"Temp directory '{temp_dir}' does not exist")
        return
        
    video_files = [f for f in os.listdir(temp_dir) if f.endswith(('.mp4', '.h264', '.avi'))]
    
    if not video_files:
        print("No video files found in temp directory")
    else:
        print(f"Found {len(video_files)} video files:")
        for file in video_files:
            file_path = os.path.join(temp_dir, file)
            size = os.path.getsize(file_path)
            modified = datetime.datetime.fromtimestamp(os.path.getmtime(file_path))
            print(f"  - {file} ({size} bytes, modified: {modified})")

def check_database_videos():
    """Check what video entries exist in database"""
    print("\n" + "=" * 50)
    print("DATABASE VIDEO ENTRIES")
    print("=" * 50)
    
    try:
        response = supabase.table("videos").select("*").eq("user_id", USER_ID).order("created_at").execute()
        
        if not response.data:
            print("No video entries found in database")
        else:
            print(f"Found {len(response.data)} video entries:")
            for video in response.data:
                print(f"  - {video.get('filename', 'N/A')}")
                print(f"    ID: {video.get('id', 'N/A')}")
                print(f"    Storage Path: {video.get('storage_path', 'N/A')}")
                print(f"    Booking ID: {video.get('booking_id', 'N/A')}")
                print(f"    Created: {video.get('created_at', 'N/A')}")
                print()
                
    except Exception as e:
        print(f"Error fetching videos from database: {str(e)}")

def check_bookings():
    """Check current bookings"""
    print("=" * 50)
    print("CURRENT BOOKINGS")
    print("=" * 50)
    
    try:
        today = datetime.datetime.now().strftime("%Y-%m-%d")
        response = supabase.table("bookings").select("*").eq("user_id", USER_ID).eq("date", today).order("start_time").execute()
        
        if not response.data:
            print("No bookings found for today")
        else:
            print(f"Found {len(response.data)} bookings for today:")
            for booking in response.data:
                print(f"  - {booking['id']}: {booking['start_time']}-{booking['end_time']}")
                
    except Exception as e:
        print(f"Error fetching bookings: {str(e)}")

if __name__ == "__main__":
    check_bookings()
    check_local_videos()
    check_database_videos() 