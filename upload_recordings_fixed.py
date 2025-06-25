#!/usr/bin/env python3
"""
EZREC Recording Upload Script - FIXED VERSION
Uploads video recordings to Supabase Storage and videos table for dashboard visibility
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

# Setup logging
import logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Import Supabase client
try:
    from supabase import create_client, Client
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    logger.info("✅ Supabase client initialized")
except Exception as e:
    logger.error(f"❌ Failed to initialize Supabase client: {e}")
    supabase = None

# Import storage3 for file uploads
try:
    from storage3 import create_client as create_storage_client
    STORAGE_AVAILABLE = True
    logger.info("✅ Storage3 library available")
except ImportError as e:
    STORAGE_AVAILABLE = False
    logger.error(f"❌ Storage3 not available: {e}")
    logger.error("Install with: pip install storage3")

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

def upload_video_to_storage_and_db(video_path: str, booking_id: str = None) -> Dict[str, Any]:
    """
    FIXED: Upload video to 'videos' bucket and add metadata to 'videos' table.
    """
    try:
        if not supabase:
            return {'success': False, 'error': 'Supabase client not available'}
        
        storage_client = get_storage_client()
        if not storage_client:
            return {'success': False, 'error': 'Storage client not available'}
        
        # Generate storage path: user_id/filename
        filename = os.path.basename(video_path)
        storage_path = f"{USER_ID}/{filename}"
        
        logger.info(f"📤 Uploading {filename} to videos bucket...")
        
        # Read and upload file
        with open(video_path, 'rb') as f:
            file_content = f.read()
        
        # Upload to 'videos' bucket (FIXED)
        response = storage_client.from_("videos").upload(
            storage_path, 
            file_content,
            file_options={"content-type": "video/mp4"}
        )
        
        if response.status_code in [200, 201]:
            logger.info(f"✅ Video uploaded to storage: {storage_path}")
            
            # Get public URL
            try:
                public_url = storage_client.from_("videos").get_public_url(storage_path)
            except:
                public_url = f"{SUPABASE_URL}/storage/v1/object/public/videos/{storage_path}"
            
            # FIXED: Add metadata to 'videos' table (not 'recordings' table)
            video_metadata = {
                'user_id': USER_ID,
                'filename': filename,
                'storage_path': storage_path,
                'booking_id': booking_id
            }
            
            # Insert into videos table
            db_response = supabase.table("videos").insert(video_metadata).execute()
            
            if db_response.data:
                video_id = db_response.data[0]['id']
                logger.info(f"✅ Video metadata added to videos table (ID: {video_id})")
                
                return {
                    'success': True,
                    'storage_path': storage_path,
                    'public_url': public_url,
                    'video_id': video_id,
                    'table': 'videos'  # Confirm which table was used
                }
            else:
                logger.warning(f"⚠️ Video uploaded but metadata insert failed")
                return {
                    'success': True,
                    'storage_path': storage_path,
                    'public_url': public_url,
                    'warning': 'Metadata insert failed'
                }
        else:
            logger.error(f"❌ Video upload failed: {response.status_code} - {response.text}")
            return {'success': False, 'error': f"Upload failed: {response.status_code}"}
            
    except Exception as e:
        logger.error(f"❌ Error uploading video: {e}")
        return {'success': False, 'error': str(e)}

def create_videos_bucket_if_not_exists():
    """Create the 'videos' bucket if it doesn't exist."""
    try:
        if not STORAGE_AVAILABLE:
            logger.error("❌ Cannot create bucket - storage3 not available")
            return False
        
        storage_client = get_storage_client()
        if not storage_client:
            return False
        
        # Try to list buckets to see if 'videos' exists
        try:
            buckets = storage_client.list_buckets()
            bucket_names = [bucket.name for bucket in buckets]
            
            if 'videos' in bucket_names:
                logger.info("✅ 'videos' bucket already exists")
                return True
            else:
                logger.info("📁 Creating 'videos' bucket...")
                # Create the bucket
                result = storage_client.create_bucket("videos", {"public": True})
                logger.info("✅ 'videos' bucket created successfully")
                return True
                
        except Exception as e:
            logger.warning(f"⚠️ Could not check/create bucket: {e}")
            # Assume bucket exists and continue
            return True
            
    except Exception as e:
        logger.error(f"❌ Error creating videos bucket: {e}")
        return False

def upload_all_recordings():
    """Upload all recordings from the recordings directory."""
    if not os.path.exists(RECORDING_DIR):
        logger.warning(f"⚠️ Recording directory not found: {RECORDING_DIR}")
        return
    
    # Create bucket if needed
    create_videos_bucket_if_not_exists()
    
    # Find all video files
    video_files = []
    for ext in ['*.mp4', '*.avi', '*.mov', '*.h264']:
        video_files.extend(Path(RECORDING_DIR).glob(f"**/{ext}"))
    
    if not video_files:
        logger.info("📂 No video files found to upload")
        return
    
    logger.info(f"📹 Found {len(video_files)} video files to upload")
    
    uploaded_count = 0
    failed_count = 0
    
    for video_file in video_files:
        try:
            # Extract booking ID from filename if possible
            booking_id = None
            filename = video_file.name
            
            # Try to extract booking ID from different filename formats
            if 'rec_' in filename:
                # Format: rec_booking-id_date_time.mp4
                parts = filename.split('_')
                if len(parts) >= 2:
                    booking_id = parts[1]
            elif '_' in filename:
                # Other formats - try to find UUID-like patterns
                parts = filename.split('_')
                for part in parts:
                    if '-' in part and len(part) > 30:  # Likely a UUID
                        booking_id = part.replace('.mp4', '')
                        break
            
            logger.info(f"📤 Uploading: {filename} (booking: {booking_id or 'unknown'})")
            
            result = upload_video_to_storage_and_db(str(video_file), booking_id)
            
            if result['success']:
                uploaded_count += 1
                logger.info(f"✅ Upload successful: {filename}")
                
                # Optionally delete local file after successful upload
                if os.getenv("DELETE_AFTER_UPLOAD", "false").lower() == "true":
                    try:
                        os.remove(video_file)
                        logger.info(f"🗑️ Deleted local file: {filename}")
                    except Exception as e:
                        logger.warning(f"⚠️ Could not delete local file: {e}")
            else:
                failed_count += 1
                logger.error(f"❌ Upload failed: {filename} - {result.get('error', 'Unknown error')}")
                
        except Exception as e:
            failed_count += 1
            logger.error(f"❌ Error processing {video_file}: {e}")
    
    logger.info(f"📊 Upload Summary: {uploaded_count} successful, {failed_count} failed")

def test_upload_system():
    """Test the upload system configuration."""
    logger.info("🧪 Testing Upload System Configuration")
    logger.info("=" * 50)
    
    # Test 1: Supabase connection
    if supabase:
        try:
            # Test database connection
            response = supabase.table("videos").select("id").limit(1).execute()
            logger.info("✅ Database connection working")
        except Exception as e:
            logger.error(f"❌ Database connection failed: {e}")
    else:
        logger.error("❌ Supabase client not initialized")
    
    # Test 2: Storage3 availability
    if STORAGE_AVAILABLE:
        logger.info("✅ Storage3 library available")
        
        # Test storage client creation
        storage_client = get_storage_client()
        if storage_client:
            logger.info("✅ Storage client created successfully")
        else:
            logger.error("❌ Storage client creation failed")
    else:
        logger.error("❌ Storage3 library not available")
    
    # Test 3: Check videos bucket
    create_videos_bucket_if_not_exists()
    
    # Test 4: Directory access
    if os.path.exists(RECORDING_DIR):
        logger.info(f"✅ Recording directory accessible: {RECORDING_DIR}")
    else:
        logger.warning(f"⚠️ Recording directory not found: {RECORDING_DIR}")
    
    logger.info("🧪 Test completed")

def main():
    """Main function."""
    logger.info("🚀 EZREC Video Upload Script - FIXED VERSION")
    logger.info("=" * 60)
    logger.info(f"Target Database: {SUPABASE_URL}")
    logger.info(f"User ID: {USER_ID}")
    logger.info(f"Recording Directory: {RECORDING_DIR}")
    logger.info(f"Target Table: videos")
    logger.info(f"Target Bucket: videos")
    logger.info("=" * 60)
    
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        test_upload_system()
    else:
        upload_all_recordings()

if __name__ == "__main__":
    main() 