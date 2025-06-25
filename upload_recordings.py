#!/usr/bin/env python3
"""
EZREC Recording Upload Script
Uploads video recordings to Supabase Storage and database for dashboard visibility
"""
import os
import sys
import json
import time
from datetime import datetime
from pathlib import Path
import hashlib
import mimetypes

# Add the src directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'src'))

from config import RECORDING_DIR, TEMP_DIR, USER_ID, CAMERA_ID, SUPABASE_URL, SUPABASE_KEY
from utils import logger, supabase

# Import storage3 for file uploads
try:
    from storage3 import create_client as create_storage_client
    STORAGE_AVAILABLE = True
    logger.info("Storage3 library available for file uploads")
except ImportError as e:
    STORAGE_AVAILABLE = False
    logger.error(f"Storage3 not available: {e}")
    logger.error("Install with: pip install storage3")

# File cleanup configuration - set DELETE_AFTER_UPLOAD=false in environment to keep local files
DELETE_AFTER_UPLOAD = os.getenv("DELETE_AFTER_UPLOAD", "true").lower() in ('true', '1', 'yes', 'on')

def get_storage_client():
    """Create and return Supabase Storage client."""
    if not STORAGE_AVAILABLE:
        return None
    
    try:
        # Create storage client with proper headers
        headers = {
            "apiKey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}"
        }
        
        storage_url = f"{SUPABASE_URL}/storage/v1"
        storage_client = create_storage_client(storage_url, headers, is_async=False)
        
        logger.debug("Storage client created successfully")
        return storage_client
        
    except Exception as e:
        logger.error(f"Failed to create storage client: {e}")
        return None

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
            
            # Create start_time as full timestamp
            start_time = datetime.strptime(f"{date_str} {time_str}", '%Y%m%d %H%M%S')
            
            return {
                'booking_id': booking_id,
                'date': recording_date,
                'time': recording_time,
                'start_time': start_time,
                'filename': filename
            }
    except Exception as e:
        logger.warning(f"Could not parse filename {filename}: {e}")
    
    return None

def upload_video_to_storage(storage_client, local_path, remote_path):
    """Upload video file to Supabase Storage."""
    try:
        # Read file content
        with open(local_path, 'rb') as f:
            file_content = f.read()
        
        # Get MIME type
        mime_type, _ = mimetypes.guess_type(local_path)
        if not mime_type:
            mime_type = 'video/mp4'
        
        # Upload file to storage
        # Format: videos/{user_id}/filename.mp4
        response = storage_client.from_("videos").upload(
            remote_path, 
            file_content,
            file_options={"content-type": mime_type}
        )
        
        if response.status_code in [200, 201]:
            logger.info(f"✅ File uploaded to storage: {remote_path}")
            
            # Get public URL for the uploaded file
            public_url = storage_client.from_("videos").get_public_url(remote_path)
            return {
                'success': True,
                'public_url': public_url,
                'storage_path': remote_path
            }
        else:
            logger.error(f"❌ Storage upload failed: {response.status_code} - {response.text}")
            return {'success': False, 'error': f"Upload failed: {response.status_code}"}
        
    except Exception as e:
        logger.error(f"❌ Error uploading to storage: {e}")
        return {'success': False, 'error': str(e)}

def upload_recording_to_database(recording_path, storage_result, booking_info=None):
    """Upload recording metadata to Supabase database."""
    try:
        file_stats = os.stat(recording_path)
        file_hash = calculate_file_hash(recording_path)
        
        # Parse filename if booking_info not provided
        if not booking_info:
            booking_info = parse_recording_filename(os.path.basename(recording_path))
        
        # Create start_time and end_time
        if booking_info and booking_info.get('start_time'):
            start_time = booking_info['start_time']
            # Assume 3-minute recording duration if not specified
            from datetime import timedelta
            end_time = start_time + timedelta(minutes=3)
        else:
            start_time = datetime.fromtimestamp(file_stats.st_ctime)
            end_time = datetime.fromtimestamp(file_stats.st_mtime)
        
        # Create recording record with only basic columns that should exist
        recording_data = {
            'user_id': USER_ID,
            'camera_id': CAMERA_ID,
            'booking_id': booking_info.get('booking_id') if booking_info else None,
            'filename': os.path.basename(recording_path),
            'file_path': recording_path,  # Always use local path for now
            'file_size': file_stats.st_size,
            'duration_seconds': 180,  # 3 minutes default
            'start_time': start_time.isoformat(),
            'end_time': end_time.isoformat(),
            'recording_date': booking_info.get('date') if booking_info else start_time.strftime('%Y-%m-%d'),
            'status': 'completed',
            'format': 'mp4',
            'resolution': '1920x1080',
            'fps': 30
        }
        
        # Add optional columns only if they might exist
        try:
            # Try to add file_hash if column exists
            if file_hash:
                recording_data['file_hash'] = file_hash
        except:
            pass
            
        try:
            # Try to add metadata if column exists
            recording_data['metadata'] = {
                'file_size_mb': round(file_stats.st_size / (1024*1024), 2),
                'camera_type': 'pi_camera',
                'resolution': '1920x1080',
                'fps': 30,
                'bitrate': 10000000,
                'format': 'h264'
            }
        except:
            pass
        
        # Check if recording already exists (by filename and file_size)
        existing = supabase.table('recordings').select('id').eq('filename', recording_data['filename']).eq('file_size', recording_data['file_size']).execute()
        
        if existing.data:
            logger.info(f"📝 Recording {recording_data['filename']} already exists in database")
            return existing.data[0]['id']
        
        # Insert new recording
        response = supabase.table('recordings').insert(recording_data).execute()
        
        if response.data:
            size_mb = round(file_stats.st_size / (1024*1024), 2)
            logger.info(f"📝 Recording added to database: {recording_data['filename']} ({size_mb} MB)")
            return response.data[0]['id']
        else:
            logger.error(f"❌ Failed to add recording {recording_data['filename']} to database")
            return None
            
    except Exception as e:
        logger.error(f"❌ Error uploading recording {recording_path}: {e}")
        return None

def create_recordings_table_if_not_exists():
    """Check if recordings table exists and provide creation instructions if needed."""
    try:
        # Try to query the table first
        test_query = supabase.table('recordings').select('id').limit(1).execute()
        logger.info("Recordings table exists")
        return True
    except Exception as e:
        if "does not exist" in str(e).lower():
            logger.error("❌ Recordings table does not exist in Supabase")
            print("\n🔧 To create the recordings table in Supabase:")
            print("1. Go to your Supabase dashboard: https://supabase.com/dashboard")
            print("2. Open SQL Editor")
            print("3. Run the migration: migrations/006_create_recordings_table.sql")
            print("4. Or run the fix script: sudo cp ~/code/EZREC-BackEnd/fix_database_schema.py /opt/ezrec-backend/ && sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 fix_database_schema.py")
            return False
        else:
            logger.warning(f"Could not verify recordings table: {e}")
            return True

def upload_all_existing_recordings():
    """Upload all existing recordings to Supabase Storage and database."""
    # Check if recordings table exists
    if not create_recordings_table_if_not_exists():
        logger.error("Cannot proceed without recordings table")
        return
    
    # Initialize storage client for cloud uploads
    storage_client = get_storage_client()
    if storage_client:
        logger.info("✅ Storage client initialized - uploading to Supabase Storage")
    else:
        logger.info("⚠️  Storage client not available - uploading metadata only to database")
    
    recording_dir = Path(RECORDING_DIR)
    
    if not recording_dir.exists():
        logger.error(f"❌ Recordings directory not found: {recording_dir}")
        return
    
    # Find all video files
    video_extensions = ['.mp4', '.avi', '.mov', '.h264']
    video_files = []
    
    for ext in video_extensions:
        video_files.extend(recording_dir.glob(f'*{ext}'))
    
    if not video_files:
        logger.info("📂 No video files found in recordings directory")
        return
    
    logger.info(f"📁 Found {len(video_files)} video files to upload")
    
    uploaded_count = 0
    failed_count = 0
    total_size = 0
    
    for video_file in video_files:
        logger.info(f"🎬 Processing: {video_file.name}")
        
        # Parse booking info from filename
        booking_info = parse_recording_filename(video_file.name)
        
        # Prepare storage upload
        storage_result = {'success': False}
        
        if storage_client:
            # Create remote path: videos/{user_id}/filename.mp4
            remote_path = f"{USER_ID}/{video_file.name}"
            
            # Upload to Supabase Storage
            storage_result = upload_video_to_storage(storage_client, str(video_file), remote_path)
        else:
            logger.warning(f"⚠️  Storage client not available - adding {video_file.name} to database only")
        
        # Upload metadata to database
        db_result = upload_recording_to_database(str(video_file), storage_result, booking_info)
        
        if db_result:
            uploaded_count += 1
            total_size += video_file.stat().st_size
            
            # Remove local file after successful upload to database (if enabled)
            if DELETE_AFTER_UPLOAD:
                try:
                    video_file.unlink()  # Delete the file
                    logger.info(f"🗑️  Local file removed after successful upload: {video_file.name}")
                except Exception as e:
                    logger.warning(f"⚠️  Failed to remove local file {video_file.name}: {e}")
                    # Don't fail the upload just because we couldn't delete the file
            else:
                logger.info(f"📁 Local file preserved (DELETE_AFTER_UPLOAD=false): {video_file.name}")
        else:
            failed_count += 1
    
    # Summary
    total_size_mb = round(total_size / (1024*1024), 1)
    logger.info(f"📊 Upload complete: {uploaded_count} successful, {failed_count} failed")
    logger.info(f"📊 Total size processed: {total_size_mb} MB")
    
    if uploaded_count > 0:
        print(f"\n✅ Successfully processed {uploaded_count} recordings ({total_size_mb} MB)")
        print(f"📱 Recordings are now visible in your dashboard under user: {USER_ID}")
        
        if storage_client:
            print(f"🌐 Files uploaded to Supabase Storage: videos/{USER_ID}/")
        else:
            if DELETE_AFTER_UPLOAD:
                print("🗑️  Local files removed after successful upload to database")
            else:
                print("📁 Local files preserved - set DELETE_AFTER_UPLOAD=true to auto-clean")
    
    if failed_count > 0:
        print(f"⚠️  {failed_count} recordings failed to upload")

def check_storage_bucket():
    """Check if the videos bucket exists in Supabase Storage."""
    storage_client = get_storage_client()
    if not storage_client:
        return False
    
    try:
        # Try to list files in the videos bucket - this will fail if bucket doesn't exist
        try:
            storage_client.from_("videos").list()
            logger.info("✅ 'videos' bucket exists in Supabase Storage")
            return True
        except Exception as bucket_error:
            if "not found" in str(bucket_error).lower() or "does not exist" in str(bucket_error).lower():
                logger.error("❌ 'videos' bucket not found in Supabase Storage")
                print("\n🔧 To create the videos bucket:")
                print("1. Go to your Supabase dashboard: https://supabase.com/dashboard")
                print("2. Navigate to Storage")
                print("3. Create a new bucket named 'videos'")
                print("4. Set it to public if you want direct access to videos")
                return False
            else:
                raise bucket_error
            
    except Exception as e:
        logger.error(f"❌ Error checking storage bucket: {e}")
        return False

def main():
    """Main function to handle recording uploads."""
    print("EZREC Recording Upload Script")
    print("=" * 40)
    
    # Test Supabase connection
    if not supabase:
        print("❌ Supabase client not available")
        sys.exit(1)
    
    print("✅ Supabase connection successful")
    
    # Check for storage bucket availability
    if STORAGE_AVAILABLE:
        bucket_exists = check_storage_bucket()
        if bucket_exists:
            print("✅ Supabase Storage bucket 'videos' found - enabling cloud uploads")
        else:
            print("⚠️  Storage bucket 'videos' not found - uploading metadata only")
            print("   📝 Create the 'videos' bucket in Supabase Storage for cloud uploads")
    
    # Start upload process
    upload_all_existing_recordings()
    
    # Show current recordings in database
    try:
        result = supabase.table('recordings').select('filename, file_size, start_time, upload_status').eq('user_id', USER_ID).order('start_time', desc=True).execute()
        
        if result.data:
            print(f"\n📊 Current recordings in database ({len(result.data)}):")
            for rec in result.data:
                size_mb = round(rec['file_size'] / (1024*1024), 1)
                status = "☁️" if rec.get('upload_status') == 'uploaded' else "📍"
                print(f"  {status} {rec['filename']} ({size_mb}MB) - {rec['start_time']}")
        else:
            print("\n📂 No recordings found in database")
            
    except Exception as e:
        logger.warning(f"Could not fetch recordings from database: {e}")

if __name__ == "__main__":
    main() 