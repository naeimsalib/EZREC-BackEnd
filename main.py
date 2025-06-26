#!/usr/bin/env python3
"""
🎬 EZREC Backend - Main Execution Logic
Handles recording, booking management, and uploads for Raspberry Pi
Production Version - Simplified Structure
"""

import os
import sys
import time
import logging
import asyncio
import threading
import signal
import json
import subprocess
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from pathlib import Path
import psutil

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import configuration and dependencies
from dotenv import load_dotenv
import requests
from supabase import create_client, Client
import pytz

# Load environment variables
load_dotenv()

class EZRECMain:
    """
    🎬 EZREC Main Controller
    
    Complete Workflow:
    1. Monitor bookings table for active bookings
    2. Start recording at booking start time using Picamera2
    3. Stop recording at booking end time
    4. Remove booking from bookings table
    5. Upload video to videos table + storage bucket
    6. Delete local file after confirmed upload
    7. Maintain exclusive camera access
    """
    
    def __init__(self):
        """Initialize EZREC Main Controller"""
        self.is_running = False
        self.current_booking: Optional[Dict] = None
        self.recording_active = False
        self.camera_process: Optional[subprocess.Popen] = None
        self.stop_event = threading.Event()
        
        # Configuration from environment
        self.base_dir = Path(os.getenv("EZREC_BASE_DIR", "/opt/ezrec-backend"))
        self.recordings_dir = self.base_dir / "recordings"
        self.temp_dir = self.base_dir / "temp"
        self.logs_dir = self.base_dir / "logs"
        
        # Ensure directories exist
        for directory in [self.recordings_dir, self.temp_dir, self.logs_dir]:
            directory.mkdir(parents=True, exist_ok=True)
        
        # Setup logging
        self.setup_logging()
        
        # Initialize Supabase
        self.setup_supabase()
        
        # Camera configuration
        self.camera_config = {
            "width": int(os.getenv("RECORD_WIDTH", "1920")),
            "height": int(os.getenv("RECORD_HEIGHT", "1080")),
            "fps": int(os.getenv("RECORD_FPS", "30")),
            "bitrate": int(os.getenv("RECORDING_BITRATE", "10000000"))
        }
        
        # System status tracking
        self.system_status = {
            "orchestrator_status": "initializing",
            "camera_status": "available",
            "current_booking": None,
            "recording_active": False,
            "last_update": datetime.now().isoformat(),
            "uptime_start": datetime.now().isoformat(),
            "total_recordings": 0,
            "successful_uploads": 0,
            "errors_count": 0,
            "camera_protected": False
        }
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
        
        self.logger.info("🎬 EZREC Main Controller initialized")
    
    def setup_logging(self):
        """Setup comprehensive logging"""
        log_file = self.logs_dir / f"ezrec_{datetime.now().strftime('%Y%m%d')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        
        self.logger = logging.getLogger("EZREC")
    
    def setup_supabase(self):
        """Initialize Supabase client"""
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_KEY")
        
        if not url or not key:
            raise ValueError("Missing Supabase configuration")
        
        self.supabase: Client = create_client(url, key)
        self.user_id = os.getenv("USER_ID")
        self.camera_id = os.getenv("CAMERA_ID", "raspberry_pi_camera_1")
        
        self.logger.info("✅ Supabase client initialized")
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        self.logger.info(f"🛑 Received signal {signum}, shutting down...")
        self.stop_event.set()
        self.is_running = False
    
    async def start_main_controller(self):
        """Start the main controller process"""
        try:
            self.logger.info("🚀 Starting EZREC Main Controller...")
            self.is_running = True
            self.stop_event.clear()
            
            # Protect camera from other processes
            await self.protect_camera_resources()
            
            # Update initial system status
            await self.update_system_status("running")
            
            # Start background status updates (every 3 seconds)
            self.start_status_updater()
            
            # Main controller loop
            await self.main_loop()
            
        except Exception as e:
            self.logger.error(f"❌ Controller startup failed: {e}")
            await self.update_system_status("error", str(e))
            raise
    
    async def protect_camera_resources(self):
        """Ensure exclusive camera access"""
        try:
            self.logger.info("🛡️ Protecting camera resources...")
            
            # Kill any existing camera processes
            camera_processes = ["libcamera", "raspistill", "raspivid", "motion", "fswebcam"]
            for proc_name in camera_processes:
                try:
                    subprocess.run(["sudo", "pkill", "-f", proc_name], 
                                 capture_output=True, check=False)
                except:
                    pass
            
            # Check if camera is available
            try:
                from picamera2 import Picamera2
                test_cam = Picamera2()
                test_cam.close()
                self.system_status["camera_protected"] = True
                self.system_status["camera_status"] = "available"
                self.logger.info("✅ Camera protection active - Picamera2 available")
            except Exception as e:
                self.logger.error(f"❌ Camera protection failed: {e}")
                self.system_status["camera_status"] = "error"
                self.system_status["camera_protected"] = False
                
        except Exception as e:
            self.logger.error(f"❌ Camera protection error: {e}")
    
    def start_status_updater(self):
        """Start background status update thread (every 3 seconds)"""
        def status_loop():
            while self.is_running and not self.stop_event.is_set():
                try:
                    asyncio.run(self.update_system_status_in_db())
                    time.sleep(3)  # Update every 3 seconds
                except Exception as e:
                    self.logger.error(f"❌ Status update error: {e}")
                    time.sleep(3)
        
        status_thread = threading.Thread(target=status_loop, name="StatusUpdater", daemon=True)
        status_thread.start()
        self.logger.info("✅ Status updater started (3-second intervals)")
    
    async def main_loop(self):
        """Main execution loop"""
        self.logger.info("🔄 Starting main execution loop...")
        
        while self.is_running and not self.stop_event.is_set():
            try:
                # Check for bookings that need to start
                upcoming_bookings = await self.get_upcoming_bookings()
                
                for booking in upcoming_bookings:
                    if self.should_start_recording(booking):
                        await self.start_booking_recording(booking)
                
                # Check if current recording should stop
                if self.current_booking and self.recording_active:
                    if self.should_stop_recording(self.current_booking):
                        await self.stop_booking_recording()
                
                # Brief pause
                await asyncio.sleep(2)
                
            except Exception as e:
                self.logger.error(f"❌ Error in main loop: {e}")
                self.system_status["errors_count"] += 1
                await asyncio.sleep(5)
    
    async def get_upcoming_bookings(self):
        """Get bookings that should start soon"""
        try:
            # Get current time in EST
            est = pytz.timezone('America/New_York')
            current_time = datetime.now(est)
            current_date = current_time.strftime('%Y-%m-%d')
            current_time_str = current_time.strftime('%H:%M')
            
            # Query bookings for today
            result = self.supabase.table("bookings").select("*").eq("user_id", self.user_id).eq("date", current_date).execute()
            
            bookings = result.data if result.data else []
            self.logger.info(f"📋 Found {len(bookings)} bookings for today")
            
            return bookings
            
        except Exception as e:
            self.logger.error(f"❌ Error fetching bookings: {e}")
            return []
    
    def should_start_recording(self, booking: Dict) -> bool:
        """Check if recording should start for this booking"""
        try:
            if self.recording_active:
                self.logger.debug(f"🔄 Already recording, skipping booking {booking.get('id')}")
                return False  # Already recording
            
            est = pytz.timezone('America/New_York')
            current_time = datetime.now(est)
            
            # Parse booking start time (handle both HH:MM and HH:MM:SS formats)
            start_time_str = booking.get("start_time", "")
            end_time_str = booking.get("end_time", "")
            
            try:
                # Try HH:MM:SS format first
                booking_start = datetime.strptime(start_time_str, "%H:%M:%S").time()
            except ValueError:
                try:
                    # Try HH:MM format
                    booking_start = datetime.strptime(start_time_str, "%H:%M").time()
                except ValueError:
                    self.logger.error(f"❌ Invalid start time format: {start_time_str}")
                    return False

            try:
                # Try HH:MM:SS format first for end time
                booking_end = datetime.strptime(end_time_str, "%H:%M:%S").time()
            except ValueError:
                try:
                    # Try HH:MM format
                    booking_end = datetime.strptime(end_time_str, "%H:%M").time()
                except ValueError:
                    self.logger.error(f"❌ Invalid end time format: {end_time_str}")
                    return False
            
            current_time_only = current_time.time()
            
            # Calculate time differences for debugging
            start_diff = (datetime.combine(datetime.today(), current_time_only) - 
                         datetime.combine(datetime.today(), booking_start)).total_seconds()
            end_diff = (datetime.combine(datetime.today(), current_time_only) - 
                       datetime.combine(datetime.today(), booking_end)).total_seconds()
            
            # Log detailed timing info
            booking_id = booking.get('id')
            self.logger.info(f"🕐 Booking {booking_id}: {booking.get('date')} {start_time_str}-{end_time_str}")
            self.logger.info(f"⏰ Current time: {current_time_only}, Start diff: {start_diff:.1f}s, End diff: {end_diff:.1f}s")
            
            # Recording should start if:
            # 1. Current time is within 60 seconds BEFORE the start time (pre-start window)
            # 2. OR current time is BETWEEN start and end time (active period)
            pre_start_window = -60 <= start_diff <= 0  # Up to 1 minute before start
            active_period = start_diff >= 0 and end_diff <= 0  # Between start and end
            
            should_start = pre_start_window or active_period
            
            if should_start:
                if pre_start_window:
                    self.logger.info(f"🎬 SHOULD START (Pre-start): {booking_id} starts in {abs(start_diff):.1f}s")
                else:
                    self.logger.info(f"🎬 SHOULD START (Active): {booking_id} started {start_diff:.1f}s ago, ends in {abs(end_diff):.1f}s")
            else:
                if start_diff < -60:
                    self.logger.debug(f"⏱️  Too early: {booking_id} starts in {abs(start_diff):.1f}s (>60s)")
                elif end_diff > 0:
                    self.logger.debug(f"⏱️  Too late: {booking_id} ended {end_diff:.1f}s ago")
            
            return should_start
            
        except Exception as e:
            self.logger.error(f"❌ Error checking start time: {e}")
            return False
    
    def should_stop_recording(self, booking: Dict) -> bool:
        """Check if recording should stop for this booking"""
        try:
            est = pytz.timezone('America/New_York')
            current_time = datetime.now(est)
            
            # Parse booking end time (handle both formats)
            end_time_str = booking.get("end_time", "")
            try:
                # Try HH:MM:SS format first
                booking_end = datetime.strptime(end_time_str, "%H:%M:%S").time()
            except ValueError:
                try:
                    # Try HH:MM format
                    booking_end = datetime.strptime(end_time_str, "%H:%M").time()
                except ValueError:
                    self.logger.error(f"❌ Invalid time format: {end_time_str}")
                    return False
            
            current_time_only = current_time.time()
            
            # Check if it's time to stop
            return current_time_only >= booking_end
            
        except Exception as e:
            self.logger.error(f"❌ Error checking stop time: {e}")
            return False
    
    async def start_booking_recording(self, booking: Dict):
        """Start recording for a booking"""
        try:
            self.logger.info(f"🎬 Starting recording for booking: {booking.get('id')}")
            
            # Generate filename
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"ezrec_{timestamp}_{booking.get('id', 'unknown')}.mp4"
            output_path = self.recordings_dir / filename
            
            # Start Picamera2 recording
            await self.start_picamera2_recording(str(output_path))
            
            # Update status
            self.current_booking = booking
            self.recording_active = True
            self.system_status["current_booking"] = booking.get('id')
            self.system_status["recording_active"] = True
            
            self.logger.info(f"✅ Recording started: {filename}")
            
        except Exception as e:
            self.logger.error(f"❌ Failed to start recording: {e}")
            await self.handle_recording_error(booking, str(e))
    
    async def start_picamera2_recording(self, output_path: str):
        """Start Picamera2 recording process"""
        try:
            from picamera2 import Picamera2
            from picamera2.encoders import H264Encoder
            from picamera2.outputs import FileOutput
            
            # Ensure recordings directory exists
            output_file = Path(output_path)
            output_file.parent.mkdir(parents=True, exist_ok=True)
            self.logger.info(f"📁 Recordings directory: {output_file.parent}")
            
            # Initialize camera
            self.logger.info("📷 Initializing Picamera2...")
            picam2 = Picamera2()
            
            # Configure for recording
            self.logger.info(f"📷 Configuring camera: {self.camera_config['width']}x{self.camera_config['height']} @ {self.camera_config['fps']}fps")
            config = picam2.create_video_configuration(
                main={"size": (self.camera_config["width"], self.camera_config["height"])},
                controls={"FrameRate": self.camera_config["fps"]}
            )
            picam2.configure(config)
            
            # Setup encoder
            self.logger.info(f"🎞️  Setting up H264 encoder with bitrate: {self.camera_config['bitrate']}")
            encoder = H264Encoder(bitrate=self.camera_config["bitrate"])
            output = FileOutput(output_path)
            
            # Start camera first
            self.logger.info("📷 Starting camera...")
            picam2.start()
            
            # Brief delay to ensure camera is ready
            await asyncio.sleep(0.5)
            
            # Start recording
            self.logger.info(f"🎬 Starting recording to: {output_path}")
            picam2.start_recording(encoder, output)
            
            # Store camera reference for stopping
            self.camera_process = picam2
            
            # Verify file is being created
            await asyncio.sleep(1)  # Give it a second to start writing
            if output_file.exists():
                self.logger.info(f"✅ Recording file created: {output_path} ({output_file.stat().st_size} bytes)")
            else:
                self.logger.warning(f"⚠️  Recording file not yet visible: {output_path}")
            
            self.logger.info(f"✅ Picamera2 recording started successfully")
            
        except ImportError as e:
            self.logger.error(f"❌ Picamera2 import failed - install required: {e}")
            raise
        except Exception as e:
            self.logger.error(f"❌ Picamera2 recording failed: {e}")
            # Clean up camera if initialization failed
            try:
                if 'picam2' in locals():
                    picam2.close()
            except:
                pass
            raise
    
    async def stop_booking_recording(self):
        """Stop current recording and process"""
        try:
            if not self.recording_active or not self.current_booking:
                return
            
            self.logger.info(f"🛑 Stopping recording for booking: {self.current_booking.get('id')}")
            
            # Stop camera recording
            if self.camera_process:
                try:
                    self.camera_process.stop_recording()
                    self.camera_process.close()
                    self.camera_process = None
                    self.logger.info("✅ Camera recording stopped")
                except Exception as e:
                    self.logger.error(f"❌ Error stopping camera: {e}")
            
            # Find the recording file
            booking_id = self.current_booking.get('id')
            self.logger.info(f"🔍 Looking for recording files: *{booking_id}*.mp4 in {self.recordings_dir}")
            
            # List all files in recordings directory for debugging
            all_files = list(self.recordings_dir.glob("*.mp4"))
            self.logger.info(f"📁 All MP4 files in recordings dir: {[f.name for f in all_files]}")
            
            recording_files = list(self.recordings_dir.glob(f"*{booking_id}*.mp4"))
            self.logger.info(f"📁 Matching recording files: {[f.name for f in recording_files]}")
            
            if recording_files:
                recording_path = recording_files[0]
                self.logger.info(f"✅ Found recording file: {recording_path}")
                
                # Process the completed recording
                await self.process_completed_recording(self.current_booking, str(recording_path))
            else:
                # Check if any files were created
                if all_files:
                    # Use the most recent file as fallback
                    latest_file = max(all_files, key=lambda f: f.stat().st_mtime)
                    self.logger.warning(f"⚠️  No matching file found, using latest: {latest_file}")
                    await self.process_completed_recording(self.current_booking, str(latest_file))
                else:
                    self.logger.error("❌ No recording files found at all - camera recording likely failed")
                    # Still remove the booking to prevent infinite loops
                    await self.remove_booking(booking_id)
            
            # Update status
            self.recording_active = False
            self.system_status["recording_active"] = False
            self.system_status["current_booking"] = None
            self.system_status["total_recordings"] += 1
            
            # Clear current booking
            self.current_booking = None
            
            self.logger.info("✅ Recording stopped and processed")
            
        except Exception as e:
            self.logger.error(f"❌ Failed to stop recording: {e}")
            # Clear state to prevent infinite loops
            self.recording_active = False
            self.current_booking = None
    
    async def process_completed_recording(self, booking: Dict, recording_path: str):
        """Process completed recording: upload and cleanup"""
        try:
            self.logger.info(f"📤 Processing completed recording: {recording_path}")
            
            # Upload video to storage
            upload_success = await self.upload_video_to_storage(booking, recording_path)
            
            if upload_success:
                # Remove booking from table
                await self.remove_booking(booking.get('id'))
                
                # Delete local file
                await self.cleanup_local_recording(recording_path)
                
                self.system_status["successful_uploads"] += 1
                self.logger.info("✅ Recording processed successfully")
            else:
                self.logger.error("❌ Upload failed, keeping local file")
                
        except Exception as e:
            self.logger.error(f"❌ Error processing recording: {e}")
    
    async def upload_video_to_storage(self, booking: Dict, recording_path: str) -> bool:
        """Upload video to Supabase storage and create video record"""
        try:
            recording_file = Path(recording_path)
            if not recording_file.exists():
                self.logger.error(f"❌ Recording file not found: {recording_path}")
                return False
            
            file_size = recording_file.stat().st_size
            self.logger.info(f"📁 Found recording file: {recording_file.name} ({file_size} bytes)")
            
            # Generate storage path
            timestamp = datetime.now().strftime("%Y/%m/%d")
            storage_path = f"recordings/{timestamp}/{recording_file.name}"
            self.logger.info(f"📤 Uploading to storage path: {storage_path}")
            
            # Upload to storage bucket
            try:
                with open(recording_path, 'rb') as file:
                    self.logger.info("📤 Starting file upload to Supabase storage...")
                    result = self.supabase.storage.from_("videos").upload(storage_path, file)
                    self.logger.info(f"📤 Upload result: {result}")
                
                if result:
                    self.logger.info("✅ File uploaded successfully to storage")
                    
                    # Get public URL
                    try:
                        public_url = self.supabase.storage.from_("videos").get_public_url(storage_path)
                        self.logger.info(f"🔗 Generated public URL: {public_url}")
                    except Exception as e:
                        self.logger.error(f"❌ Failed to get public URL: {e}")
                        # Use a fallback URL format
                        public_url = f"https://iszmsaayxpdrovealrrp.supabase.co/storage/v1/object/public/videos/{storage_path}"
                        self.logger.info(f"🔗 Using fallback URL: {public_url}")
                    
                    # Create video record in database
                    video_data = {
                        "user_id": self.user_id,
                        "camera_id": self.camera_id,
                        "filename": recording_file.name,
                        "file_url": public_url,
                        "file_size": file_size,
                        "duration_seconds": None,  # Could be calculated if needed
                        "recording_date": booking.get("date"),
                        "recording_start_time": booking.get("start_time"),
                        "recording_end_time": booking.get("end_time"),
                        "upload_timestamp": datetime.now().isoformat(),
                        "storage_path": storage_path
                    }
                    
                    self.logger.info(f"💾 Creating video record in database: {video_data}")
                    video_result = self.supabase.table("videos").insert(video_data).execute()
                    
                    if video_result.data:
                        self.logger.info(f"✅ Video uploaded and recorded: {storage_path}")
                        return True
                    else:
                        self.logger.error(f"❌ Failed to create video record: {video_result}")
                        return False
                else:
                    self.logger.error(f"❌ Failed to upload to storage: {result}")
                    return False
                    
            except Exception as upload_error:
                self.logger.error(f"❌ Storage upload error: {upload_error}")
                
                # Try alternative storage bucket names in case "videos" doesn't exist
                alternative_buckets = ["ezrec-videos", "recordings", "camera-recordings"]
                for bucket_name in alternative_buckets:
                    try:
                        self.logger.info(f"🔄 Trying alternative bucket: {bucket_name}")
                        with open(recording_path, 'rb') as file:
                            result = self.supabase.storage.from_(bucket_name).upload(storage_path, file)
                        if result:
                            self.logger.info(f"✅ Successfully uploaded to {bucket_name}")
                            public_url = f"https://iszmsaayxpdrovealrrp.supabase.co/storage/v1/object/public/{bucket_name}/{storage_path}"
                            return True
                    except Exception as alt_error:
                        self.logger.debug(f"❌ Alternative bucket {bucket_name} failed: {alt_error}")
                        continue
                
                return False
                
        except Exception as e:
            self.logger.error(f"❌ Upload error: {e}")
            return False
    
    async def remove_booking(self, booking_id: str):
        """Remove booking from bookings table"""
        try:
            result = self.supabase.table("bookings").delete().eq("id", booking_id).execute()
            self.logger.info(f"✅ Booking removed: {booking_id}")
        except Exception as e:
            self.logger.error(f"❌ Failed to remove booking {booking_id}: {e}")
    
    async def cleanup_local_recording(self, recording_path: str):
        """Delete local recording file after successful upload"""
        try:
            Path(recording_path).unlink()
            self.logger.info(f"✅ Local file deleted: {recording_path}")
        except Exception as e:
            self.logger.error(f"❌ Failed to delete local file: {e}")
    
    async def handle_recording_error(self, booking: Dict, error_msg: str):
        """Handle recording errors"""
        self.logger.error(f"❌ Recording error for booking {booking.get('id')}: {error_msg}")
        self.system_status["errors_count"] += 1
        self.recording_active = False
        self.current_booking = None
    
    async def update_system_status(self, status: str, error: Optional[str] = None):
        """Update system status"""
        self.system_status["orchestrator_status"] = status
        self.system_status["last_update"] = datetime.now().isoformat()
        if error:
            self.system_status["last_error"] = error
    
    async def update_system_status_in_db(self):
        """Update system status in database (every 3 seconds)"""
        try:
            status_data = {
                "user_id": self.user_id,
                "camera_id": self.camera_id,
                "status": self.system_status["orchestrator_status"],
                "is_recording": self.recording_active,
                "current_booking_id": self.system_status.get("current_booking"),
                "last_heartbeat": datetime.now().isoformat(),
                "total_recordings": self.system_status["total_recordings"],
                "successful_uploads": self.system_status["successful_uploads"],
                "errors_count": self.system_status["errors_count"],
                "camera_status": self.system_status["camera_status"],
                "uptime_start": self.system_status["uptime_start"]
            }
            
            # Upsert system status
            result = self.supabase.table("system_status").upsert(status_data, on_conflict="user_id,camera_id").execute()
            
        except Exception as e:
            self.logger.error(f"❌ Failed to update system status: {e}")
    
    async def stop_controller(self):
        """Gracefully stop the controller"""
        self.logger.info("🛑 Stopping EZREC Controller...")
        self.is_running = False
        self.stop_event.set()
        
        # Stop any active recording
        if self.recording_active:
            await self.stop_booking_recording()
        
        await self.update_system_status("stopped")
        self.logger.info("✅ Controller stopped")

async def main():
    """Main entry point"""
    controller = EZRECMain()
    
    try:
        await controller.start_main_controller()
    except KeyboardInterrupt:
        await controller.stop_controller()
    except Exception as e:
        logging.error(f"❌ Fatal error: {e}")
        await controller.stop_controller()
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
