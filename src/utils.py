#!/usr/bin/env python3
"""
EZREC Backend Utilities - FIXED VERSION
Enhanced with proper database connections and video upload functionality
"""
import logging
import logging.handlers
import socket
import json
import os
import sys
import time
import threading
from datetime import datetime
from typing import Optional, Dict, Any, List
import pytz
import psutil
import cv2

# Add the src directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    SUPABASE_URL, SUPABASE_ANON_KEY, USER_ID, LOGS_DIR, TEMP_DIR,
    RECORDINGS_DIR, CAMERA_ID, DEBUG, LOG_LEVEL
)

# Global logger instance
logger = None

def setup_logging():
    """Configure enhanced logging with rotation and proper formatting."""
    global logger
    
    if logger is not None:
        return logger
    
    # Ensure log directory exists
    os.makedirs(LOGS_DIR, exist_ok=True)
    
    # Create logger
    logger = logging.getLogger('ezrec')
    logger.setLevel(getattr(logging, LOG_LEVEL.upper()))
    
    # Prevent duplicate handlers
    if logger.handlers:
        return logger
    
    # File handler with rotation
    file_handler = logging.handlers.RotatingFileHandler(
        os.path.join(LOGS_DIR, 'ezrec.log'),
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5
    )
    file_handler.setFormatter(logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
    ))
    
    # Console handler (only if not in systemd)
    if not os.getenv('JOURNAL_STREAM'):
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(logging.Formatter(
            '%(asctime)s - %(levelname)s - %(message)s'
        ))
        logger.addHandler(console_handler)
    
    logger.addHandler(file_handler)
    
    # Log startup information
    logger.info("="*60)
    logger.info("EZREC Backend Logging Initialized - FIXED VERSION")
    logger.info(f"Log Level: {LOG_LEVEL}")
    logger.info(f"Debug Mode: {DEBUG}")
    logger.info(f"Log Directory: {LOGS_DIR}")
    logger.info("="*60)
    
    return logger

# Initialize logging on import
logger = setup_logging()

# Supabase client setup with error handling
try:
    from supabase import create_client, Client
    
    # Create client - check for both service role and anon keys
    supabase_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY') or os.getenv('SUPABASE_ANON_KEY') or SUPABASE_ANON_KEY
    supabase: Client = create_client(SUPABASE_URL, supabase_key)
    
    logger.info("Supabase client initialized successfully")
        
except Exception as e:
    logger.warning(f"Failed to initialize Supabase client: {e}")
    supabase = None

def get_next_booking() -> Optional[Dict[str, Any]]:
    """
    FIXED: Get the next upcoming booking from Supabase with proper camera ID handling.
    """
    if not supabase:
        logger.warning("Supabase client not available")
        return None
    
    try:
        now = datetime.now()
        today = now.strftime('%Y-%m-%d')
        current_time = now.strftime('%H:%M')
        
        logger.info(f"🔍 Looking for bookings for USER_ID: {USER_ID}")
        logger.info(f"🔍 Current time: {today} {current_time}")
        
        # FIXED: Query by USER_ID instead of CAMERA_ID since database has multiple camera IDs
        response = supabase.table("bookings")\
            .select("*")\
            .eq("user_id", USER_ID)\
            .eq("status", "confirmed")\
            .gte("date", today)\
            .order("date, start_time")\
            .execute()
        
        logger.info(f"📊 Found {len(response.data)} total bookings for user")
        
        if response.data and len(response.data) > 0:
            # Filter bookings to find the next valid one
            for booking in response.data:
                booking_date = booking['date']
                booking_start = booking['start_time']
                
                logger.info(f"🔍 Checking booking {booking['id']}: {booking_date} {booking_start}")
                
                # For today's bookings, check if start time hasn't passed
                if booking_date == today:
                    if booking_start >= current_time:
                        logger.info(f"✅ Found next booking: {booking['id']} at {booking_date} {booking_start}")
                        return booking
                    else:
                        logger.info(f"⏰ Booking {booking['id']} already passed ({booking_start} < {current_time})")
                else:
                    # Future date bookings are always valid
                    logger.info(f"✅ Found future booking: {booking['id']} at {booking_date} {booking_start}")
                    return booking
            
            logger.debug("No upcoming bookings found")
            return None
        else:
            logger.debug("No confirmed bookings found")
            return None
            
    except Exception as e:
        logger.error(f"Error fetching next booking: {e}", exc_info=True)
        return None

def upload_video_to_supabase(video_path: str, booking_id: str = None) -> Dict[str, Any]:
    """
    FIXED: Upload video file to Supabase Storage and add metadata to videos table.
    """
    try:
        # Import storage3 for file uploads
        from storage3 import create_client as create_storage_client
        
        # Create storage client
        headers = {
            "apiKey": os.getenv('SUPABASE_ANON_KEY', SUPABASE_ANON_KEY),
            "Authorization": f"Bearer {os.getenv('SUPABASE_SERVICE_ROLE_KEY', SUPABASE_ANON_KEY)}"
        }
        
        storage_url = f"{SUPABASE_URL}/storage/v1"
        storage_client = create_storage_client(storage_url, headers, is_async=False)
        
        # Generate storage path: user_id/filename
        filename = os.path.basename(video_path)
        storage_path = f"{USER_ID}/{filename}"
        
        logger.info(f"📤 Uploading video to storage: {storage_path}")
        
        # Read and upload file
        with open(video_path, 'rb') as f:
            file_content = f.read()
        
        # Upload to 'videos' bucket
        response = storage_client.from_("videos").upload(
            storage_path, 
            file_content,
            file_options={"content-type": "video/mp4"}
        )
        
        if response.status_code in [200, 201]:
            logger.info(f"✅ Video uploaded to storage successfully")
            
            # Get public URL
            public_url = storage_client.from_("videos").get_public_url(storage_path)
            
            # FIXED: Add metadata to videos table (not recordings table)
            video_metadata = {
                'user_id': USER_ID,
                'filename': filename,
                'storage_path': storage_path,
                'booking_id': str(booking_id) if booking_id else None
            }
            
            # Insert into videos table
            db_response = supabase.table("videos").insert(video_metadata).execute()
            
            if db_response.data:
                logger.info(f"✅ Video metadata added to videos table")
                return {
                    'success': True,
                    'storage_path': storage_path,
                    'public_url': public_url,
                    'video_id': db_response.data[0]['id']
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
            logger.error(f"❌ Video upload failed: {response.status_code}")
            return {'success': False, 'error': f"Upload failed: {response.status_code}"}
            
    except ImportError:
        logger.error("❌ storage3 library not installed. Run: pip install storage3")
        return {'success': False, 'error': 'storage3 library missing'}
    except Exception as e:
        logger.error(f"❌ Error uploading video: {e}")
        return {'success': False, 'error': str(e)}

def update_system_status(
    is_recording: bool = False,
    is_streaming: bool = False,
    storage_used: int = 0,
    last_backup: Optional[str] = None,
    recording_errors: int = 0,
    **kwargs
) -> bool:
    """
    FIXED: Enhanced system status update with proper user ID filtering.
    """
    if not supabase:
        logger.warning("Supabase client not available, skipping status update")
        return False
    
    try:
        # Get current timestamp
        now = datetime.now().isoformat()
        
        # Get system metrics
        metrics = get_system_metrics()
        
        # Prepare status data with FIXED user_id
        status_data = {
            'user_id': USER_ID,  # FIXED: Use correct user ID
            'is_recording': is_recording,
            'is_streaming': is_streaming,
            'storage_used': storage_used,
            'last_backup': last_backup,
            'updated_at': now,
            'last_heartbeat': now,
            'last_seen': now,
            'ip_address': get_ip_address(),
            'recording_errors': recording_errors,
            'camera_id': CAMERA_ID,
            'pi_active': True,
            **metrics,
            **kwargs
        }
        
        # Try to update existing record, then insert if not found
        try:
            response = supabase.table("system_status")\
                .update(status_data)\
                .eq("user_id", USER_ID)\
                .execute()
            
            if response.data:
                logger.debug("✅ System status updated successfully")
                return True
            else:
                # No existing record, insert new one
                response = supabase.table("system_status")\
                    .insert(status_data)\
                    .execute()
                
                if response.data:
                    logger.info("✅ System status inserted successfully")
                    return True
                else:
                    logger.warning("⚠️ System status update/insert failed")
                    return False
                    
        except Exception as e:
            logger.error(f"❌ System status update failed: {e}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error in update_system_status: {e}")
        return False

def get_system_metrics() -> Dict[str, Any]:
    """Collect comprehensive system metrics."""
    try:
        metrics = {
            "cpu_usage_percent": psutil.cpu_percent(interval=0.5),
            "cpu_count": psutil.cpu_count(),
            "load_average": list(os.getloadavg()) if hasattr(os, 'getloadavg') else [0.0, 0.0, 0.0],
            "memory_usage_percent": psutil.virtual_memory().percent,
            "memory_total_gb": round(psutil.virtual_memory().total / (1024**3), 2),
            "memory_available_gb": round(psutil.virtual_memory().available / (1024**3), 2),
            "disk_usage_percent": psutil.disk_usage("/").percent,
            "disk_total_gb": round(psutil.disk_usage("/").total / (1024**3), 2),
            "disk_free_gb": round(psutil.disk_usage("/").free / (1024**3), 2),
            "uptime_seconds": int(time.time() - psutil.boot_time()),
            "active_processes": len(psutil.pids()),
            "network_io": psutil.net_io_counters()._asdict() if psutil.net_io_counters() else {},
            "temperature_celsius": get_cpu_temperature(),
        }
        
        return {k: v for k, v in metrics.items() if v is not None}
        
    except Exception as e:
        logger.error(f"Error collecting system metrics: {e}")
        return {}

def get_cpu_temperature() -> Optional[float]:
    """Get CPU temperature from Raspberry Pi sensor."""
    try:
        with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
            temp = int(f.read().strip()) / 1000.0
        return round(temp, 1)
    except FileNotFoundError:
        return None
    except Exception as e:
        logger.warning(f"Could not read temperature: {e}")
        return None

def get_ip_address() -> str:
    """Get the local IP address with fallback."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
        return ip
    except Exception:
        try:
            return socket.gethostbyname(socket.gethostname())
        except Exception:
            return "127.0.0.1"

def save_booking(booking: Dict[str, Any]) -> bool:
    """Save booking to local file for processing."""
    try:
        os.makedirs(TEMP_DIR, exist_ok=True)
        filepath = os.path.join(TEMP_DIR, "current_booking.json")
        
        with open(filepath, 'w') as f:
            json.dump(booking, f, indent=2)
        
        logger.info(f"✅ Booking {booking.get('id', 'unknown')} saved locally")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error saving booking: {e}")
        return False

def load_booking() -> Optional[Dict[str, Any]]:
    """Load current booking from local file."""
    try:
        filepath = os.path.join(TEMP_DIR, "current_booking.json")
        
        if not os.path.exists(filepath):
            return None
            
        with open(filepath, 'r') as f:
            booking = json.load(f)
            
        return booking
        
    except Exception as e:
        logger.error(f"❌ Error loading booking: {e}")
        return None

def complete_booking(booking_id: str) -> bool:
    """FIXED: Complete a booking by removing it from database after recording."""
    try:
        if not supabase:
            logger.warning("Supabase client not available for booking completion")
            return False
        
        logger.info(f"🎯 Completing booking: {booking_id}")
        
        # FIXED: Delete booking from database (removes from bookings table)
        # Ensure booking_id is treated as string for compatibility
        response = supabase.table("bookings")\
            .delete()\
            .eq("id", str(booking_id))\
            .execute()
        
        if response.data is not None:  # DELETE returns empty list on success
            logger.info(f"✅ Booking {booking_id} removed from database")
            
            # Remove local booking file
            try:
                filepath = os.path.join(TEMP_DIR, "current_booking.json")
                if os.path.exists(filepath):
                    os.remove(filepath)
                    logger.info("✅ Local booking file removed")
            except Exception as e:
                logger.warning(f"⚠️ Could not remove local booking file: {e}")
            
            return True
        else:
            logger.warning(f"⚠️ Failed to remove booking {booking_id} from database")
            return False
            
    except Exception as e:
        logger.error(f"❌ Error completing booking {booking_id}: {e}")
        return False

# Export the fixed functions
__all__ = [
    'setup_logging', 'logger', 'get_next_booking', 'upload_video_to_supabase',
    'update_system_status', 'save_booking', 'load_booking', 'complete_booking',
    'get_system_metrics', 'get_ip_address'
] 

# FIXED: Add SupabaseManager class for compatibility with test scripts
class SupabaseManager:
    """Supabase database manager for async operations."""
    
    def __init__(self):
        self.client = supabase
        self.supabase = supabase  # Add this for backward compatibility
        
    async def execute_query(self, query: str, params: Dict[str, Any] = None):
        """Execute a raw SQL query with proper WHERE clause parsing - ENHANCED VERSION."""
        try:
            if not self.client:
                raise Exception("Supabase client not available")
            
            # Clean and normalize the query
            clean_query = query.strip()
            logger.info(f"🔍 Processing query: {clean_query[:50]}...")
            
            # For simple table queries, parse and execute
            if clean_query.upper().startswith('SELECT'):
                logger.info("✅ Confirmed SELECT query detected")
                
                # Handle bookings queries with WHERE conditions
                if 'FROM bookings' in clean_query:
                    logger.info("📋 Processing bookings table query")
                    query_builder = self.client.table("bookings").select("*")
                    
                    # Enhanced parsing - use regex for dynamic date/user_id matching
                    import re
                    
                    # Parse date condition dynamically
                    date_match = re.search(r"date\s*=\s*'([^']+)'", clean_query, re.IGNORECASE)
                    if date_match:
                        date_value = date_match.group(1)
                        query_builder = query_builder.eq("date", date_value)
                        logger.info(f"📅 Filtering by date: {date_value}")
                    
                    # Parse user_id condition dynamically
                    user_id_match = re.search(r"user_id\s*=\s*'([^']+)'", clean_query, re.IGNORECASE)
                    if user_id_match:
                        user_id_value = user_id_match.group(1)
                        query_builder = query_builder.eq("user_id", user_id_value)
                        logger.info(f"👤 Filtering by user_id: {user_id_value}")
                    
                    # Parse status condition
                    status_match = re.search(r"status\s*=\s*'([^']+)'", clean_query, re.IGNORECASE)
                    if status_match:
                        status_value = status_match.group(1)
                        query_builder = query_builder.eq("status", status_value)
                        logger.info(f"📊 Filtering by status: {status_value}")
                    
                    # Add ordering
                    if "ORDER BY start_time ASC" in clean_query:
                        query_builder = query_builder.order("start_time", desc=False)
                        logger.info("🔄 Ordering by start_time ASC")
                    
                    response = query_builder.execute()
                    logger.info(f"✅ Bookings query executed successfully - returned {len(response.data)} results")
                    return response.data
                    
                elif 'FROM videos' in clean_query:
                    logger.info("🎥 Processing videos table query")
                    response = self.client.table("videos").select("*").execute()
                    logger.info(f"✅ Videos query executed - returned {len(response.data)} results")
                    return response.data
                elif 'FROM system_status' in clean_query:
                    logger.info("📊 Processing system_status table query")
                    response = self.client.table("system_status").select("*").execute()
                    logger.info(f"✅ System status query executed - returned {len(response.data)} results")
                    return response.data
                else:
                    logger.warning(f"❌ Unsupported table in query: {clean_query}")
                    return []
            else:
                logger.warning(f"❌ Only SELECT queries supported. Received: {clean_query}")
                return []
                
        except Exception as e:
            logger.error(f"❌ Query execution failed: {e}")
            raise
    
    async def insert_booking(self, booking_data: Dict[str, Any]):
        """Insert a new booking."""
        try:
            response = self.client.table("bookings").insert(booking_data).execute()
            return response.data
        except Exception as e:
            logger.error(f"Booking insert failed: {e}")
            raise
    
    async def get_bookings(self, user_id: str, limit: int = 10):
        """Get bookings for a user."""
        try:
            response = self.client.table("bookings")\
                .select("*")\
                .eq("user_id", user_id)\
                .order("created_at", desc=True)\
                .limit(limit)\
                .execute()
            return response.data
        except Exception as e:
            logger.error(f"Get bookings failed: {e}")
            raise 