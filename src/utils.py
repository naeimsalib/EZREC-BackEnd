#!/usr/bin/env python3
import logging
import logging.handlers
import socket
import json
import os
from datetime import datetime
import pytz
from typing import Optional, Dict, Any, List
from supabase import create_client, Client
import time
import threading
import psutil

from .config import (
    SUPABASE_URL,
    SUPABASE_KEY,
    USER_ID,
    LOG_DIR,
    TEMP_DIR,
    RECORDING_DIR,
    CAMERA_ID
)

# Initialize Supabase client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def get_local_timezone():
    """Get the local timezone name."""
    return datetime.now().astimezone().tzinfo

# Setup logging with local timezone
def setup_logging():
    """Configure logging with both file and console handlers using local timezone."""
    os.makedirs(LOG_DIR, exist_ok=True)
    
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # Custom formatter that uses local time
    class LocalTimeFormatter(logging.Formatter):
        def converter(self, timestamp):
            dt = datetime.fromtimestamp(timestamp)
            return dt.astimezone()
            
        def formatTime(self, record, datefmt=None):
            dt = self.converter(record.created)
            if datefmt:
                return dt.strftime(datefmt)
            return dt.strftime('%Y-%m-%d %H:%M:%S %z')
    
    # File handler with rotation
    file_handler = logging.handlers.RotatingFileHandler(
        os.path.join(LOG_DIR, 'smartcam.log'),
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5
    )
    file_handler.setFormatter(LocalTimeFormatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    ))
    
    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(LocalTimeFormatter(
        '%(asctime)s - %(levelname)s - %(message)s'
    ))
    
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    return logger

logger = setup_logging()

def get_ip() -> str:
    """Get the local IP address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception as e:
        logger.error(f"Failed to get IP address: {e}")
        return "127.0.0.1"

def local_now():
    """Get current datetime in local timezone."""
    return datetime.now().astimezone()

def update_system_status(
    is_recording: bool = False,
    is_streaming: bool = False,
    storage_used: int = 0,
    last_backup: Optional[str] = None
) -> bool:
    """Update system status in the database."""
    try:
        # Collect memory and CPU usage
        mem = psutil.virtual_memory()
        cpu = psutil.cpu_percent(interval=0.5)
        
        now = local_now()
        
        # Update system status - try update first, then insert if not found
        system_data = {
            "user_id": USER_ID,
            "is_recording": is_recording,
            "is_streaming": is_streaming,
            "storage_used": storage_used or get_storage_used(),
            "last_backup": last_backup,
            "last_seen": now.isoformat(),
            "last_heartbeat": now.isoformat(),
            "ip_address": get_ip(),
            "memory_usage": mem.percent,
            "cpu_usage": cpu,
            "pi_active": True
        }
        
        # Try to update existing record first
        try:
            result = supabase.table("system_status").update(system_data).eq("user_id", USER_ID).execute()
            if not result.data:
                # No existing record found, insert new one
                supabase.table("system_status").insert(system_data).execute()
                logger.info("Created new system_status record")
            else:
                logger.info("Updated existing system_status record")
        except Exception as e:
            # If update fails, try insert
            logger.warning(f"Update failed, trying insert: {e}")
            try:
                supabase.table("system_status").insert(system_data).execute()
                logger.info("Inserted new system_status record")
            except Exception as insert_error:
                logger.error(f"Both update and insert failed: {insert_error}")
                return False
        
        logger.info(f"System status updated: memory={mem.percent}%, cpu={cpu}%, storage={storage_used}")
        return True
        
    except Exception as e:
        logger.error(f"Error updating system status: {e}", exc_info=True)
        return False

def save_booking(booking: Dict[str, Any]) -> bool:
    """Save booking information to a JSON file."""
    try:
        logger.info(f"Saving booking: {booking}")
        os.makedirs(TEMP_DIR, exist_ok=True)
        filepath = os.path.join(TEMP_DIR, "current_booking.json")
        
        with open(filepath, "w") as f:
            json.dump(booking, f)
            
        logger.info(f"Booking saved: {booking['id']}")
        return True
        
    except Exception as e:
        logger.error(f"Error saving booking: {e}", exc_info=True)
        return False

def load_booking() -> Optional[Dict[str, Any]]:
    """Load booking information from JSON file."""
    try:
        filepath = os.path.join(TEMP_DIR, "current_booking.json")
        
        if not os.path.exists(filepath):
            logger.info("No booking file found to load.")
            return None
            
        with open(filepath, "r") as f:
            booking = json.load(f)
            
        logger.info(f"Loaded booking: {booking}")
        return booking
        
    except Exception as e:
        logger.error(f"Error loading booking: {e}", exc_info=True)
        return None

def remove_booking() -> bool:
    """Remove the current booking file."""
    try:
        filepath = os.path.join(TEMP_DIR, "current_booking.json")
        
        if os.path.exists(filepath):
            os.remove(filepath)
            logger.info("Booking file removed")
            
        else:
            logger.info("No booking file to remove.")
            
        return True
        
    except Exception as e:
        logger.error(f"Error removing booking: {e}", exc_info=True)
        return False

def queue_upload(filepath: str) -> bool:
    """Add a file to the upload queue."""
    try:
        logger.info(f"Queueing file for upload: {filepath}")
        queue_file = os.path.join(TEMP_DIR, "upload_queue.json")
        queue = get_upload_queue()
        
        if filepath not in queue:
            queue.append(filepath)
            
            with open(queue_file, "w") as f:
                json.dump(queue, f)
                
            logger.info(f"File queued for upload: {filepath}")
            
        else:
            logger.info(f"File already in upload queue: {filepath}")
            
        return True
        
    except Exception as e:
        logger.error(f"Error queueing file for upload: {e}", exc_info=True)
        return False

def get_upload_queue() -> List[str]:
    """Get the list of files in the upload queue."""
    try:
        queue_file = os.path.join(TEMP_DIR, "upload_queue.json")
        
        if not os.path.exists(queue_file):
            logger.info("No upload queue file found.")
            return []
            
        with open(queue_file, "r") as f:
            queue = json.load(f)
            
        logger.info(f"Loaded upload queue: {queue}")
        return queue
        
    except Exception as e:
        logger.error(f"Error getting upload queue: {e}", exc_info=True)
        return []

def clear_upload_queue() -> bool:
    """Clear the upload queue."""
    try:
        queue_file = os.path.join(TEMP_DIR, "upload_queue.json")
        
        if os.path.exists(queue_file):
            os.remove(queue_file)
            
        logger.info("Upload queue cleared")
        return True
        
    except Exception as e:
        logger.error(f"Error clearing upload queue: {e}", exc_info=True)
        return False

def format_timestamp(timestamp: datetime) -> str:
    """Format timestamp for Supabase."""
    return timestamp.isoformat()

def cleanup_temp_files(directory: str) -> None:
    """Clean up temporary files in the specified directory."""
    try:
        for filename in os.listdir(directory):
            filepath = os.path.join(directory, filename)
            try:
                if os.path.isfile(filepath):
                    os.remove(filepath)
                    logger.info(f"Removed temporary file: {filepath}")
            except Exception as e:
                logger.error(f"Error removing file {filepath}: {e}")
                
    except Exception as e:
        logger.error(f"Error cleaning up temporary files: {e}")

def get_storage_used() -> int:
    """Calculate total storage used by recordings."""
    try:
        total_size = 0
        for dirpath, _, filenames in os.walk(RECORDING_DIR):
            for filename in filenames:
                filepath = os.path.join(dirpath, filename)
                total_size += os.path.getsize(filepath)
        return total_size
    except Exception as e:
        logger.error(f"Error calculating storage used: {e}")
        return 0

HEARTBEAT_INTERVAL = 5  # seconds - reduced from 20 to 5 for faster frontend updates

_heartbeat_thread = None
_heartbeat_stop_event = threading.Event()

def send_heartbeat(is_recording=False, is_streaming=False, storage_used=None, last_backup=None):
    """Send a heartbeat update to keep the system marked as active"""
    try:
        now = datetime.utcnow()
        
        # Prepare update data
        data = {
            "pi_active": True,
            "last_heartbeat": now.isoformat(),
            "last_seen": now.isoformat(),
            "is_recording": is_recording,
            "is_streaming": is_streaming,
        }
        
        if storage_used is not None:
            data["storage_used"] = storage_used
        if last_backup is not None:
            data["last_backup"] = last_backup
            
        # Try to update existing record first
        try:
            result = supabase.table("system_status").update(data).eq("user_id", USER_ID).execute()
            if not result.data:
                # No existing record found, insert new one with user_id
                data["user_id"] = USER_ID
                supabase.table("system_status").insert(data).execute()
            print("[Heartbeat] Sent successfully")
        except Exception as e:
            # If update fails, try insert with user_id
            try:
                data["user_id"] = USER_ID
                supabase.table("system_status").insert(data).execute()
                print("[Heartbeat] Sent successfully (inserted)")
            except Exception as insert_error:
                print(f"[Heartbeat] Failed to send: {insert_error}")
                logger.error(f"Heartbeat failed: {insert_error}", exc_info=True)
        
    except Exception as e:
        print(f"[Heartbeat] Failed to send: {e}")
        logger.error(f"Heartbeat failed: {e}", exc_info=True)

def _heartbeat_loop():
    while not _heartbeat_stop_event.is_set():
        send_heartbeat()
        _heartbeat_stop_event.wait(HEARTBEAT_INTERVAL)

def start_heartbeat_thread():
    global _heartbeat_thread
    if _heartbeat_thread is None or not _heartbeat_thread.is_alive():
        _heartbeat_stop_event.clear()
        _heartbeat_thread = threading.Thread(target=_heartbeat_loop, daemon=True)
        _heartbeat_thread.start()

def stop_heartbeat_thread():
    _heartbeat_stop_event.set()
    if _heartbeat_thread:
        _heartbeat_thread.join() 