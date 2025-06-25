#!/usr/bin/env python3
"""
EZREC Recording Upload Script
Uploads existing recordings to Supabase database and enhances recording workflow
"""
import os
import sys
import json
import time
from datetime import datetime
from pathlib import Path
import hashlib

# Add the src directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'src'))

from config import RECORDING_DIR, TEMP_DIR, USER_ID, CAMERA_ID
from utils import logger, supabase

def calculate_file_hash(filepath):
    """Calculate MD5 hash of a file."""
    hash_md5 = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def parse_recording_filename(filename):
    """Parse recording filename to extract booking info."""
    # Format: rec_BOOKING-ID_YYYYMMDD_HHMMSS.mp4
    try:
        parts = filename.replace('.mp4', '').split('_')
        if len(parts) >= 4 and parts[0] == 'rec':
            booking_id = parts[1]
            date_str = parts[2]  # YYYYMMDD
            time_str = parts[3]  # HHMMSS
            
            # Convert to proper datetime
            recording_date = datetime.strptime(date_str, '%Y%m%d').strftime('%Y-%m-%d')
            recording_time = datetime.strptime(time_str, '%H%M%S').strftime('%H:%M:%S')
            
            return {
                'booking_id': booking_id,
                'date': recording_date,
                'time': recording_time,
                'filename': filename
            }
    except Exception as e:
        logger.warning(f"Could not parse filename {filename}: {e}")
    
    return None

def upload_recording_to_database(recording_path, booking_info=None):
    """Upload recording metadata to Supabase database."""
    try:
        file_stats = os.stat(recording_path)
        file_hash = calculate_file_hash(recording_path)
        
        # Parse filename if booking_info not provided
        if not booking_info:
            booking_info = parse_recording_filename(os.path.basename(recording_path))
        
        # Create recording record
        recording_data = {
            'id': file_hash,  # Use file hash as unique ID
            'user_id': USER_ID,
            'camera_id': CAMERA_ID,
            'booking_id': booking_info.get('booking_id') if booking_info else None,
            'filename': os.path.basename(recording_path),
            'file_path': recording_path,
            'file_size': file_stats.st_size,
            'file_hash': file_hash,
            'duration_seconds': None,  # Could be calculated with ffprobe
            'recording_date': booking_info.get('date') if booking_info else datetime.now().strftime('%Y-%m-%d'),
            'recording_time': booking_info.get('time') if booking_info else datetime.now().strftime('%H:%M:%S'),
            'created_at': datetime.fromtimestamp(file_stats.st_ctime).isoformat(),
            'uploaded_at': datetime.now().isoformat(),
            'status': 'completed',
            'metadata': {
                'file_size_mb': round(file_stats.st_size / (1024*1024), 2),
                'camera_type': 'pi_camera',
                'resolution': '1920x1080',
                'fps': 30,
                'bitrate': 10000000,
                'format': 'h264'
            }
        }
        
        # Check if recording already exists
        existing = supabase.table('recordings').select('id').eq('id', file_hash).execute()
        
        if existing.data:
            logger.info(f"Recording {recording_data['filename']} already exists in database")
            return existing.data[0]['id']
        
        # Insert new recording
        response = supabase.table('recordings').insert(recording_data).execute()
        
        if response.data:
            logger.info(f"Recording uploaded to database: {recording_data['filename']} ({recording_data['metadata']['file_size_mb']} MB)")
            return response.data[0]['id']
        else:
            logger.error(f"Failed to upload recording {recording_data['filename']} to database")
            return None
            
    except Exception as e:
        logger.error(f"Error uploading recording {recording_path}: {e}")
        return None

def create_recordings_table_if_not_exists():
    """Create recordings table in Supabase if it doesn't exist."""
    try:
        # Try to query the table first
        test_query = supabase.table('recordings').select('id').limit(1).execute()
        logger.info("Recordings table exists")
    except Exception as e:
        logger.warning(f"Recordings table might not exist: {e}")
        logger.info("You may need to create the recordings table in Supabase manually")
        print("\nTo create the recordings table in Supabase, run this SQL:")
        print("""
CREATE TABLE recordings (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    camera_id TEXT NOT NULL,
    booking_id TEXT,
    filename TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    file_hash TEXT NOT NULL,
    duration_seconds INTEGER,
    recording_date DATE NOT NULL,
    recording_time TIME NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'completed',
    metadata JSONB
);

-- Create indexes for better performance
CREATE INDEX idx_recordings_user_id ON recordings(user_id);
CREATE INDEX idx_recordings_camera_id ON recordings(camera_id);
CREATE INDEX idx_recordings_booking_id ON recordings(booking_id);
CREATE INDEX idx_recordings_date ON recordings(recording_date);
        """)

def upload_all_existing_recordings():
    """Upload all existing recordings in the recordings directory."""
    recording_dir = Path(RECORDING_DIR)
    
    if not recording_dir.exists():
        logger.error(f"Recordings directory not found: {recording_dir}")
        return
    
    # Find all video files
    video_extensions = ['.mp4', '.avi', '.mov', '.h264']
    video_files = []
    
    for ext in video_extensions:
        video_files.extend(recording_dir.glob(f'*{ext}'))
    
    if not video_files:
        logger.info("No video files found in recordings directory")
        return
    
    logger.info(f"Found {len(video_files)} video files to upload")
    
    uploaded_count = 0
    failed_count = 0
    
    for video_file in video_files:
        logger.info(f"Processing: {video_file.name}")
        
        # Parse booking info from filename
        booking_info = parse_recording_filename(video_file.name)
        
        # Upload to database
        result = upload_recording_to_database(str(video_file), booking_info)
        
        if result:
            uploaded_count += 1
        else:
            failed_count += 1
    
    logger.info(f"Upload complete: {uploaded_count} successful, {failed_count} failed")
    return uploaded_count, failed_count

def main():
    """Main function."""
    print("EZREC Recording Upload Script")
    print("============================")
    
    # Check Supabase connection
    if not supabase:
        print("❌ Supabase connection failed")
        return 1
    
    print("✅ Supabase connection successful")
    
    # Check/create recordings table
    create_recordings_table_if_not_exists()
    
    # Upload existing recordings
    print(f"\nScanning recordings directory: {RECORDING_DIR}")
    
    try:
        uploaded, failed = upload_all_existing_recordings()
        
        if uploaded > 0:
            print(f"\n✅ Successfully uploaded {uploaded} recordings to database")
        
        if failed > 0:
            print(f"⚠️  {failed} recordings failed to upload")
        
        # Show current recordings in database
        try:
            recordings = supabase.table('recordings').select('filename, file_size, recording_date, recording_time').order('created_at', desc=True).execute()
            
            if recordings.data:
                print(f"\n📊 Current recordings in database ({len(recordings.data)} total):")
                for rec in recordings.data[:10]:  # Show first 10
                    size_mb = round(rec.get('file_size', 0) / (1024*1024), 1)
                    print(f"  • {rec['filename']} - {size_mb}MB - {rec['recording_date']} {rec['recording_time']}")
                
                if len(recordings.data) > 10:
                    print(f"  ... and {len(recordings.data) - 10} more")
            else:
                print("\n📊 No recordings found in database")
                
        except Exception as e:
            logger.warning(f"Could not fetch recordings from database: {e}")
        
        return 0
        
    except Exception as e:
        logger.error(f"Upload process failed: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 