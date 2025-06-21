import os
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables
load_dotenv()

# Pi-optimized: Default to /opt/ezrec-backend if not overridden
BASE_DIR = Path(os.getenv("EZREC_BASE_DIR", "/opt/ezrec-backend"))
TEMP_DIR = BASE_DIR / "temp"
UPLOAD_DIR = BASE_DIR / "uploads"
LOG_DIR = BASE_DIR / "logs"
RECORDING_DIR = BASE_DIR / "recordings"
ASSETS_DIR = BASE_DIR / "user_assets"

# Create directories if they don't exist
TEMP_DIR.mkdir(exist_ok=True)
UPLOAD_DIR.mkdir(exist_ok=True)
RECORDING_DIR.mkdir(exist_ok=True)
ASSETS_DIR.mkdir(exist_ok=True)

# Supabase configuration
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")
USER_ID = os.getenv("USER_ID")
CAMERA_ID = os.getenv("CAMERA_ID", "default_camera")
CAMERA_NAME = os.getenv("CAMERA_NAME", "Camera")
CAMERA_LOCATION = os.getenv("CAMERA_LOCATION", "")
CAMERA_DEVICE = os.getenv("CAMERA_DEVICE")

# Asset Paths
LOGO_PATH = os.getenv("LOGO_PATH", str(ASSETS_DIR / "logo.png"))
TRADEMARK_PATH = os.getenv("TRADEMARK_PATH", str(ASSETS_DIR / "trademark.png"))
INTRO_VIDEO_PATH = os.getenv("INTRO_VIDEO_PATH", str(ASSETS_DIR / "intro.mp4"))

# Camera settings
CAMERA_INDEX = 0
PREVIEW_WIDTH = 640
PREVIEW_HEIGHT = 480
RECORD_WIDTH = 1280
RECORD_HEIGHT = 720
PREVIEW_FPS = 24
RECORD_FPS = 30
HARDWARE_ENCODER = "h264_omx"

# Recording settings
MAX_RECORDING_DURATION = 7200  # 2 hours in seconds
MIN_RECORDING_DURATION = 300   # 5 minutes in seconds

# Status update intervals
STATUS_UPDATE_INTERVAL = 15  # seconds
BOOKING_CHECK_INTERVAL = 60  # seconds

# File paths
NEXT_BOOKING_FILE = TEMP_DIR / "next_booking.json"
UPLOAD_QUEUE_FILE = TEMP_DIR / "to_upload.txt" 