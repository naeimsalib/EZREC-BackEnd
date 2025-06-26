#!/usr/bin/env python3
"""
EZREC Backend Configuration - Optimized for Raspberry Pi
Handles environment variables, paths, and system configuration
"""
import os
import logging
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

def get_env_var(name: str, default=None, required=False, var_type=str):
    """Get environment variable with validation and type conversion."""
    value = os.getenv(name)
    
    if required and value is None:
        raise ValueError(f"Required environment variable {name} is not set")
    
    if value is None:
        return default
        
    # Type conversion
    if var_type == bool:
        return str(value).lower() in ('true', '1', 'yes', 'on')
    elif var_type == int:
        try:
            return int(value)
        except ValueError:
            logging.warning(f"Invalid integer value for {name}: {value}, using default: {default}")
            return default
    elif var_type == float:
        try:
            return float(value)
        except ValueError:
            logging.warning(f"Invalid float value for {name}: {value}, using default: {default}")
            return default
    
    return var_type(value)

# Base Directory Configuration
BASE_DIR = Path(get_env_var("EZREC_BASE_DIR", "/opt/ezrec-backend"))
TEMP_DIR = BASE_DIR / "temp"
UPLOAD_DIR = BASE_DIR / "uploads"
LOGS_DIR = BASE_DIR / "logs"
RECORDINGS_DIR = BASE_DIR / "recordings"
ASSETS_DIR = BASE_DIR / "user_assets"

# Create directories if they don't exist (with error handling for permissions)
for directory in [TEMP_DIR, UPLOAD_DIR, LOGS_DIR, RECORDINGS_DIR, ASSETS_DIR]:
    try:
        directory.mkdir(parents=True, exist_ok=True)
    except PermissionError:
        # Skip directory creation if permission denied (directories should already exist)
        logging.warning(f"Permission denied creating {directory}, assuming it exists")
        pass
    except Exception as e:
        logging.warning(f"Error creating directory {directory}: {e}")

# Supabase Configuration (Required)
SUPABASE_URL = get_env_var("SUPABASE_URL", required=True)
SUPABASE_ANON_KEY = get_env_var("SUPABASE_ANON_KEY") or get_env_var("SUPABASE_KEY", required=True)
SUPABASE_SERVICE_ROLE_KEY = get_env_var("SUPABASE_SERVICE_ROLE_KEY")

# User Configuration (Required)
USER_ID = get_env_var("USER_ID", required=True)
USER_EMAIL = get_env_var("USER_EMAIL", "user@example.com")

# Camera Configuration
CAMERA_ID = get_env_var("CAMERA_ID", "raspberry_pi_camera")
CAMERA_NAME = get_env_var("CAMERA_NAME", "Raspberry Pi Camera")
CAMERA_LOCATION = get_env_var("CAMERA_LOCATION", "Unknown Location")
CAMERA_DEVICE = get_env_var("CAMERA_DEVICE", "/dev/video0")

# Camera Settings - Optimized for Pi Camera
CAMERA_INDEX = get_env_var("CAMERA_INDEX", 0, var_type=int)
PREVIEW_WIDTH = get_env_var("PREVIEW_WIDTH", 640, var_type=int)
PREVIEW_HEIGHT = get_env_var("PREVIEW_HEIGHT", 480, var_type=int)
RECORD_WIDTH = get_env_var("RECORD_WIDTH", 1920, var_type=int)
RECORD_HEIGHT = get_env_var("RECORD_HEIGHT", 1080, var_type=int)
PREVIEW_FPS = get_env_var("PREVIEW_FPS", 24, var_type=int)
RECORD_FPS = get_env_var("RECORD_FPS", 30, var_type=int)

# Hardware Encoder for Pi
HARDWARE_ENCODER = get_env_var("HARDWARE_ENCODER", "h264_omx")

# Recording Configuration
MAX_RECORDING_DURATION = get_env_var("MAX_RECORDING_DURATION", 7200, var_type=int)  # 2 hours
MIN_RECORDING_DURATION = get_env_var("MIN_RECORDING_DURATION", 300, var_type=int)   # 5 minutes
RECORDING_BITRATE = get_env_var("RECORDING_BITRATE", 10000000, var_type=int)        # 10Mbps

# System Update Intervals - FIXED: Faster updates for real-time monitoring
STATUS_UPDATE_INTERVAL = get_env_var("STATUS_UPDATE_INTERVAL", 3, var_type=int)  # 3 seconds
BOOKING_CHECK_INTERVAL = get_env_var("BOOKING_CHECK_INTERVAL", 5, var_type=int)   # 5 seconds  
HEARTBEAT_INTERVAL = get_env_var("HEARTBEAT_INTERVAL", 3, var_type=int)           # 3 seconds

# Asset Paths
LOGO_PATH = get_env_var("LOGO_PATH", str(ASSETS_DIR / "logo.png"))
TRADEMARK_PATH = get_env_var("TRADEMARK_PATH", str(ASSETS_DIR / "trademark.png"))
INTRO_VIDEO_PATH = get_env_var("INTRO_VIDEO_PATH", str(ASSETS_DIR / "intro.mp4"))

# System Configuration
DEBUG = get_env_var("DEBUG", False, var_type=bool)
LOG_LEVEL = get_env_var("LOG_LEVEL", "INFO")
LOG_MAX_BYTES = get_env_var("LOG_MAX_BYTES", 10*1024*1024, var_type=int)  # 10MB
LOG_BACKUP_COUNT = get_env_var("LOG_BACKUP_COUNT", 5, var_type=int)

# Booking Management
DELETE_COMPLETED_BOOKINGS = get_env_var("DELETE_COMPLETED_BOOKINGS", False, var_type=bool)  # Mark as completed by default

# Network Configuration
NETWORK_TIMEOUT = get_env_var("NETWORK_TIMEOUT", 30, var_type=int)
UPLOAD_RETRY_COUNT = get_env_var("UPLOAD_RETRY_COUNT", 3, var_type=int)
UPLOAD_RETRY_DELAY = get_env_var("UPLOAD_RETRY_DELAY", 60, var_type=int)

# File paths for internal use
NEXT_BOOKING_FILE = TEMP_DIR / "next_booking.json"
CURRENT_BOOKING_FILE = TEMP_DIR / "current_booking.json"
UPLOAD_QUEUE_FILE = TEMP_DIR / "upload_queue.json"
SYSTEM_STATUS_FILE = TEMP_DIR / "system_status.json"

# Validate critical configuration
def validate_config():
    """Validate critical configuration values."""
    errors = []
    
    if not SUPABASE_URL:
        errors.append("SUPABASE_URL is required")
    if not SUPABASE_ANON_KEY:
        errors.append("SUPABASE_ANON_KEY is required")
    if not USER_ID:
        errors.append("USER_ID is required")
    
    if RECORD_WIDTH <= 0 or RECORD_HEIGHT <= 0:
        errors.append("Invalid recording dimensions")
    if RECORD_FPS <= 0 or RECORD_FPS > 60:
        errors.append("Invalid recording FPS (must be 1-60)")
    
    if errors:
        raise ValueError(f"Configuration errors: {', '.join(errors)}")

# Run validation on import
try:
    validate_config()
except ValueError as e:
    logging.error(f"Configuration validation failed: {e}")
    # Don't raise in production to avoid service failures
    if DEBUG:
        raise

# Export configuration summary for logging
CONFIG_SUMMARY = {
    "base_dir": str(BASE_DIR),
    "camera_id": CAMERA_ID,
    "record_resolution": f"{RECORD_WIDTH}x{RECORD_HEIGHT}@{RECORD_FPS}fps",
    "debug_mode": DEBUG,
    "log_level": LOG_LEVEL,
} 

# FIXED: Add Config class for proper module imports
class Config:
    """Configuration class for EZREC Backend."""
    
    # Directories
    BASE_DIR = BASE_DIR
    TEMP_DIR = TEMP_DIR
    UPLOAD_DIR = UPLOAD_DIR
    LOGS_DIR = LOGS_DIR
    RECORDINGS_DIR = RECORDINGS_DIR
    ASSETS_DIR = ASSETS_DIR
    
    # Supabase
    SUPABASE_URL = SUPABASE_URL
    SUPABASE_ANON_KEY = SUPABASE_ANON_KEY
    SUPABASE_SERVICE_ROLE_KEY = SUPABASE_SERVICE_ROLE_KEY
    
    # User
    USER_ID = USER_ID
    USER_EMAIL = USER_EMAIL
    
    # Camera
    CAMERA_ID = CAMERA_ID
    CAMERA_NAME = CAMERA_NAME
    CAMERA_LOCATION = CAMERA_LOCATION
    CAMERA_DEVICE = CAMERA_DEVICE
    CAMERA_INDEX = CAMERA_INDEX
    
    # Camera Settings
    PREVIEW_WIDTH = PREVIEW_WIDTH
    PREVIEW_HEIGHT = PREVIEW_HEIGHT
    RECORD_WIDTH = RECORD_WIDTH
    RECORD_HEIGHT = RECORD_HEIGHT
    PREVIEW_FPS = PREVIEW_FPS
    RECORD_FPS = RECORD_FPS
    HARDWARE_ENCODER = HARDWARE_ENCODER
    
    # Recording
    MAX_RECORDING_DURATION = MAX_RECORDING_DURATION
    MIN_RECORDING_DURATION = MIN_RECORDING_DURATION
    RECORDING_BITRATE = RECORDING_BITRATE
    
    # System Update Intervals
    STATUS_UPDATE_INTERVAL = STATUS_UPDATE_INTERVAL
    BOOKING_CHECK_INTERVAL = BOOKING_CHECK_INTERVAL
    HEARTBEAT_INTERVAL = HEARTBEAT_INTERVAL
    
    # System
    DEBUG = DEBUG
    LOG_LEVEL = LOG_LEVEL
    LOG_MAX_BYTES = LOG_MAX_BYTES
    LOG_BACKUP_COUNT = LOG_BACKUP_COUNT
    
    # Network
    NETWORK_TIMEOUT = NETWORK_TIMEOUT
    UPLOAD_RETRY_COUNT = UPLOAD_RETRY_COUNT
    UPLOAD_RETRY_DELAY = UPLOAD_RETRY_DELAY

# Backward compatibility
config = Config() 