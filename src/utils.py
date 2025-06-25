#!/usr/bin/env python3
"""
EZREC Backend Utilities - Optimized for Raspberry Pi
Enhanced logging, system monitoring, and utility functions
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
    SUPABASE_URL, SUPABASE_KEY, USER_ID, LOG_DIR, TEMP_DIR, 
    RECORDING_DIR, CAMERA_ID, LOG_MAX_BYTES, LOG_BACKUP_COUNT,
    LOG_LEVEL, DEBUG
)

# Global logger instance
logger = None

def get_local_timezone():
    """Get the local timezone name."""
    return datetime.now().astimezone().tzinfo

class LocalTimeFormatter(logging.Formatter):
    """Custom formatter that uses local time instead of UTC."""
    
    def converter(self, timestamp):
        dt = datetime.fromtimestamp(timestamp)
        return dt.astimezone()
        
    def formatTime(self, record, datefmt=None):
        dt = self.converter(record.created)
        if datefmt:
            return dt.strftime(datefmt)
        return dt.strftime('%Y-%m-%d %H:%M:%S %z')

def setup_logging():
    """Configure enhanced logging with rotation and proper formatting."""
    global logger
    
    if logger is not None:
        return logger
    
    # Ensure log directory exists
    os.makedirs(LOG_DIR, exist_ok=True)
    
    # Create logger
    logger = logging.getLogger('ezrec')
    logger.setLevel(getattr(logging, LOG_LEVEL.upper()))
    
    # Prevent duplicate handlers
    if logger.handlers:
        return logger
    
    # File handler with rotation
    file_handler = logging.handlers.RotatingFileHandler(
        os.path.join(LOG_DIR, 'ezrec.log'),
        maxBytes=LOG_MAX_BYTES,
        backupCount=LOG_BACKUP_COUNT
    )
    file_handler.setFormatter(LocalTimeFormatter(
        '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
    ))
    
    # Console handler (only if not in systemd)
    if not os.getenv('JOURNAL_STREAM'):
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(LocalTimeFormatter(
            '%(asctime)s - %(levelname)s - %(message)s'
        ))
        logger.addHandler(console_handler)
    
    logger.addHandler(file_handler)
    
    # Log startup information
    logger.info("="*60)
    logger.info("EZREC Backend Logging Initialized")
    logger.info(f"Log Level: {LOG_LEVEL}")
    logger.info(f"Debug Mode: {DEBUG}")
    logger.info(f"Log Directory: {LOG_DIR}")
    logger.info("="*60)
    
    return logger

# Initialize logging on import
logger = setup_logging()

# Supabase client setup with error handling
try:
    from supabase import create_client, Client
    
    # Create a simple, compatible client for version 2.0.3
    # Use positional arguments as documented in the official docs
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    logger.info("Supabase client initialized successfully")
        
except Exception as e:
    logger.warning(f"Failed to initialize Supabase client: {e}")
    supabase = None

def get_system_metrics() -> Dict[str, Any]:
    """Collect comprehensive system metrics."""
    try:
        metrics = {
            # CPU metrics
            "cpu_usage_percent": psutil.cpu_percent(interval=0.5),
            "cpu_count": psutil.cpu_count(),
            "load_average": list(os.getloadavg()) if hasattr(os, 'getloadavg') else [0.0, 0.0, 0.0],
            
            # Memory metrics
            "memory_usage_percent": psutil.virtual_memory().percent,
            "memory_total_gb": round(psutil.virtual_memory().total / (1024**3), 2),
            "memory_available_gb": round(psutil.virtual_memory().available / (1024**3), 2),
            
            # Disk metrics
            "disk_usage_percent": psutil.disk_usage("/").percent,
            "disk_total_gb": round(psutil.disk_usage("/").total / (1024**3), 2),
            "disk_free_gb": round(psutil.disk_usage("/").free / (1024**3), 2),
            
            # System info
            "uptime_seconds": int(time.time() - psutil.boot_time()),
            "active_processes": len(psutil.pids()),
            
            # Network metrics
            "network_io": psutil.net_io_counters()._asdict() if psutil.net_io_counters() else {},
            
            # Temperature (Pi-specific)
            "temperature_celsius": get_cpu_temperature(),
        }
        
        # Filter out None values
        return {k: v for k, v in metrics.items() if v is not None}
        
    except Exception as e:
        logger.error(f"Error collecting system metrics: {e}")
        return {}

def get_cpu_temperature() -> Optional[float]:
    """Get CPU temperature from Raspberry Pi sensor."""
    try:
        # Raspberry Pi thermal sensor
        with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
            temp = int(f.read().strip()) / 1000.0
        return round(temp, 1)
    except FileNotFoundError:
        # Not a Raspberry Pi or sensor not available
        return None
    except Exception as e:
        logger.warning(f"Could not read temperature: {e}")
        return None

def get_ip_address() -> str:
    """Get the local IP address with fallback."""
    try:
        # Try to connect to a remote address to determine local IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
        return ip
    except Exception:
        try:
            # Fallback: get IP from hostname
            return socket.gethostbyname(socket.gethostname())
        except Exception:
            return "127.0.0.1"

def local_now():
    """Get current datetime in local timezone."""
    return datetime.now().astimezone()

def update_system_status(
    is_recording: bool = False,
    is_streaming: bool = False,
    storage_used: int = 0,
    last_backup: Optional[str] = None,
    recording_errors: int = 0,
    **kwargs
) -> bool:
    """
    Enhanced system status update with comprehensive metrics and error handling.
    """
    if not supabase:
        logger.warning("Supabase client not available, skipping status update")
        return False
    
    try:
        # Get current timestamp
        now = local_now()
        
        # Collect system metrics
        metrics = get_system_metrics()
        
        # Build comprehensive status data
        system_data = {
            "user_id": USER_ID,
            "camera_id": CAMERA_ID,
            "last_seen": now.isoformat(),
            "ip_address": get_ip_address(),
            "pi_active": True,
            
            # Recording status
            "is_recording": is_recording,
            "is_streaming": is_streaming,
            "recording_errors": recording_errors,
            
            # Storage information
            "storage_used": storage_used or get_storage_used(),
            "last_backup": last_backup,
            
            # Camera status for dashboard
            "cameras_online": 1,  # This Pi has 1 camera online
            "total_cameras": 1,
            
            # System metrics
            **metrics,
            
            # Additional custom data
            **kwargs
        }
        
        # Remove None values to avoid database issues
        system_data = {k: v for k, v in system_data.items() if v is not None}
        
        # Upsert to Supabase with retry logic
        max_retries = 3
        for attempt in range(max_retries):
            try:
                response = supabase.table("system_status").upsert(
                    system_data, 
                    on_conflict="user_id"
                ).execute()
                
                if response.data:
                    logger.debug("System status updated successfully")
                    
                    # Also update cameras table for dashboard
                    try:
                        import uuid
                        
                        # Generate a consistent UUID for this camera
                        camera_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{USER_ID}-camera-{CAMERA_ID}"))
                        
                        camera_data = {
                            "id": camera_uuid,
                            "user_id": USER_ID,
                            "name": f"Camera {CAMERA_ID}",
                            "camera_on": True,
                            "is_recording": is_recording,
                            "pi_active": True,
                            "last_seen": now.isoformat(),
                            "ip_address": get_ip_address(),
                            "last_heartbeat": now.isoformat(),
                        }
                        
                        # Upsert camera status
                        supabase.table("cameras").upsert(
                            camera_data, 
                            on_conflict="id"
                        ).execute()
                        
                        logger.debug("Camera status updated successfully")
                        
                    except Exception as cam_e:
                        logger.warning(f"Failed to update cameras table: {cam_e}")
                    
                    return True
                else:
                    logger.warning(f"System status update returned no data (attempt {attempt + 1})")
                    
            except Exception as e:
                logger.warning(f"System status update attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                else:
                    raise
        
        return False
        
    except Exception as e:
        logger.error(f"Error updating system status: {e}", exc_info=True)
        return False

def save_booking(booking: Dict[str, Any]) -> bool:
    """Save booking information to local JSON file with validation."""
    try:
        # Validate booking data
        required_fields = ['id', 'start_time', 'end_time']
        for field in required_fields:
            if field not in booking:
                logger.error(f"Booking missing required field: {field}")
                return False
        
        # Ensure temp directory exists
        os.makedirs(TEMP_DIR, exist_ok=True)
        
        # Save to file with timestamp
        booking_data = {
            **booking,
            "saved_at": local_now().isoformat(),
            "saved_by": "utils.save_booking"
        }
        
        filepath = os.path.join(TEMP_DIR, "current_booking.json")
        with open(filepath, "w") as f:
            json.dump(booking_data, f, indent=2)
            
        logger.info(f"Booking saved: {booking['id']} ({booking.get('start_time')} - {booking.get('end_time')})")
        return True
        
    except Exception as e:
        logger.error(f"Error saving booking: {e}", exc_info=True)
        return False

def load_booking() -> Optional[Dict[str, Any]]:
    """Load current booking from local JSON file with validation."""
    try:
        filepath = os.path.join(TEMP_DIR, "current_booking.json")
        
        if not os.path.exists(filepath):
            logger.debug("No current booking file found")
            return None
            
        with open(filepath, "r") as f:
            booking = json.load(f)
        
        # Validate booking data
        if not booking.get('id'):
            logger.warning("Invalid booking data: missing ID")
            return None
            
        # Check if booking is still valid (not expired)
        if 'end_time' in booking:
            try:
                end_time = datetime.fromisoformat(booking['end_time'])
                if local_now() > end_time:
                    logger.info(f"Booking {booking['id']} has expired, removing")
                    remove_booking()
                    return None
            except ValueError:
                logger.warning(f"Invalid end_time format in booking: {booking.get('end_time')}")
        
        logger.debug(f"Loaded booking: {booking['id']}")
        return booking
        
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON in booking file: {e}")
        return None
    except Exception as e:
        logger.error(f"Error loading booking: {e}", exc_info=True)
        return None

def get_next_booking() -> Optional[Dict[str, Any]]:
    """Get the next upcoming booking from Supabase with enhanced error handling."""
    if not supabase:
        logger.warning("Supabase client not available")
        return None
    
    try:
        now = local_now()
        
        # Query for bookings today and in the future
        today = now.strftime('%Y-%m-%d')
        current_time = now.strftime('%H:%M')
        
        # Get all confirmed bookings for today or future dates
        response = supabase.table("bookings")\
            .select("*")\
            .eq("camera_id", CAMERA_ID)\
            .eq("status", "confirmed")\
            .gte("date", today)\
            .order("date, start_time")\
            .execute()
        
        if response.data and len(response.data) > 0:
            # Filter bookings to find the next valid one
            for booking in response.data:
                booking_date = booking['date']
                booking_start = booking['start_time']
                
                # For today's bookings, check if start time hasn't passed
                if booking_date == today:
                    if booking_start >= current_time:
                        logger.info(f"Found next booking: {booking['id']} at {booking_date} {booking_start}")
                        return booking
                else:
                    # Future date bookings are always valid
                    logger.info(f"Found next booking: {booking['id']} at {booking_date} {booking_start}")
                    return booking
            
            logger.debug("No upcoming bookings found")
            return None
        else:
            logger.debug("No confirmed bookings found")
            return None
            
    except Exception as e:
        logger.error(f"Error fetching next booking: {e}", exc_info=True)
        return None

def remove_booking() -> bool:
    """Remove current booking file."""
    try:
        filepath = os.path.join(TEMP_DIR, "current_booking.json")
        if os.path.exists(filepath):
            os.remove(filepath)
            logger.info("Current booking removed")
        return True
    except Exception as e:
        logger.error(f"Error removing booking: {e}")
        return False

def get_storage_used() -> int:
    """Calculate storage used by recordings and temp files."""
    try:
        total_size = 0
        
        # Check recordings directory
        if os.path.exists(RECORDING_DIR):
            for root, dirs, files in os.walk(RECORDING_DIR):
                for file in files:
                    filepath = os.path.join(root, file)
                    try:
                        total_size += os.path.getsize(filepath)
                    except OSError:
                        pass
        
        # Check temp directory
        if os.path.exists(TEMP_DIR):
            for root, dirs, files in os.walk(TEMP_DIR):
                for file in files:
                    if file.endswith(('.mp4', '.avi', '.mov', '.h264')):
                        filepath = os.path.join(root, file)
                        try:
                            total_size += os.path.getsize(filepath)
                        except OSError:
                            pass
        
        return total_size
        
    except Exception as e:
        logger.error(f"Error calculating storage usage: {e}")
        return 0

def cleanup_temp_files(max_age_hours: int = 24) -> int:
    """Clean up old temporary files and return number of files cleaned."""
    try:
        cleaned_count = 0
        cutoff_time = time.time() - (max_age_hours * 3600)
        
        if not os.path.exists(TEMP_DIR):
            return 0
        
        for root, dirs, files in os.walk(TEMP_DIR):
            for file in files:
                filepath = os.path.join(root, file)
                try:
                    if os.path.getmtime(filepath) < cutoff_time:
                        os.remove(filepath)
                        cleaned_count += 1
                        logger.debug(f"Cleaned up old file: {file}")
                except OSError as e:
                    logger.warning(f"Could not remove {file}: {e}")
        
        if cleaned_count > 0:
            logger.info(f"Cleaned up {cleaned_count} old temporary files")
        
        return cleaned_count
        
    except Exception as e:
        logger.error(f"Error during cleanup: {e}")
        return 0

def format_timestamp(timestamp: datetime) -> str:
    """Format timestamp for display."""
    return timestamp.strftime('%Y-%m-%d %H:%M:%S')

def validate_camera_access() -> bool:
    """Validate that camera is accessible."""
    try:
        # Quick OpenCV test
        cap = cv2.VideoCapture(0)
        if cap.isOpened():
            ret, frame = cap.read()
            cap.release()
            return ret and frame is not None
        return False
    except Exception:
        return False

def get_system_info() -> Dict[str, Any]:
    """Get comprehensive system information for debugging."""
    try:
        import platform
        
        info = {
            "platform": platform.platform(),
            "system": platform.system(),
            "machine": platform.machine(),
            "processor": platform.processor(),
            "python_version": platform.python_version(),
            "hostname": socket.gethostname(),
            "ip_address": get_ip_address(),
            "uptime_seconds": int(time.time() - psutil.boot_time()),
            "boot_time": datetime.fromtimestamp(psutil.boot_time()).isoformat(),
            "cpu_count": psutil.cpu_count(),
            "memory_total": psutil.virtual_memory().total,
            "disk_total": psutil.disk_usage("/").total,
            "temperature": get_cpu_temperature(),
        }
        
        return info
        
    except Exception as e:
        logger.error(f"Error getting system info: {e}")
        return {"error": str(e)}

# Heartbeat functionality for monitoring
_heartbeat_thread = None
_heartbeat_stop = threading.Event()

def start_heartbeat_thread(interval: int = 300):  # 5 minutes default
    """Start heartbeat monitoring thread."""
    global _heartbeat_thread
    
    if _heartbeat_thread and _heartbeat_thread.is_alive():
        logger.warning("Heartbeat thread already running")
        return
    
    def heartbeat_worker():
        logger.info(f"Heartbeat thread started (interval: {interval}s)")
        
        while not _heartbeat_stop.wait(interval):
            try:
                # Update system status as heartbeat
                update_system_status()
                logger.debug("Heartbeat sent")
            except Exception as e:
                logger.error(f"Heartbeat error: {e}")
    
    _heartbeat_stop.clear()
    _heartbeat_thread = threading.Thread(target=heartbeat_worker, daemon=True, name="Heartbeat")
    _heartbeat_thread.start()
    
    logger.info("Heartbeat monitoring started")

def stop_heartbeat_thread():
    """Stop heartbeat monitoring thread."""
    global _heartbeat_thread
    
    if _heartbeat_thread and _heartbeat_thread.is_alive():
        _heartbeat_stop.set()
        _heartbeat_thread.join(timeout=5)
        logger.info("Heartbeat monitoring stopped")

# Queue management functions for upload handling
def queue_upload(filepath: str, metadata: Dict[str, Any] = None) -> bool:
    """Queue a file for upload with metadata."""
    try:
        queue_file = os.path.join(TEMP_DIR, "upload_queue.json")
        queue_data = []
        
        # Load existing queue
        if os.path.exists(queue_file):
            with open(queue_file, "r") as f:
                queue_data = json.load(f)
        
        # Add new item
        queue_item = {
            "filepath": filepath,
            "queued_at": local_now().isoformat(),
            "metadata": metadata or {},
            "attempts": 0,
            "last_attempt": None,
            "status": "queued"
        }
        
        queue_data.append(queue_item)
        
        # Save queue
        with open(queue_file, "w") as f:
            json.dump(queue_data, f, indent=2)
        
        logger.info(f"File queued for upload: {filepath}")
        return True
        
    except Exception as e:
        logger.error(f"Error queueing upload: {e}")
        return False

def get_upload_queue() -> List[Dict[str, Any]]:
    """Get current upload queue."""
    try:
        queue_file = os.path.join(TEMP_DIR, "upload_queue.json")
        
        if not os.path.exists(queue_file):
            return []
        
        with open(queue_file, "r") as f:
            return json.load(f)
            
    except Exception as e:
        logger.error(f"Error reading upload queue: {e}")
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
        logger.error(f"Error clearing upload queue: {e}")
        return False

# Legacy compatibility functions
def send_heartbeat(*args, **kwargs):
    """Legacy heartbeat function for backward compatibility."""
    return update_system_status(*args, **kwargs)

def _heartbeat_loop():
    """Legacy heartbeat loop for backward compatibility."""
    start_heartbeat_thread()

# Initialize heartbeat on import if not in debug mode
if not DEBUG:
    start_heartbeat_thread() 