#!/usr/bin/env python3
"""
🎬 EZREC Backend Orchestrator - Production Version
Complete booking lifecycle: Read bookings → Record → Upload → Cleanup
Raspberry Pi optimized with Picamera2 and 3-second status updates
"""

import os
import sys
import time
import logging
import asyncio
import threading
import signal
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
import json
from pathlib import Path
import psutil
import subprocess

# Add project paths
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import Config
from utils import SupabaseManager

class EZRECOrchestrator:
    """
    🎬 EZREC Production Orchestrator
    
    Complete Workflow:
    1. Monitor bookings table for active bookings
    2. Start recording at booking start time using Picamera2
    3. Update system status every 3 seconds
    4. Stop recording at booking end time
    5. Remove booking from bookings table
    6. Upload video to videos table + storage bucket
    7. Delete local file after confirmed upload
    8. Maintain exclusive camera access
    """
    
    def __init__(self):
        """Initialize EZREC Orchestrator"""
        self.config = Config()
        self.is_running = False
        self.current_booking: Optional[Dict] = None
        self.recording_active = False
        self.camera_process: Optional[subprocess.Popen] = None
        self.stop_event = threading.Event()
        
        # Directories
        self.base_dir = Path("/opt/ezrec-backend")
        self.recordings_dir = self.base_dir / "recordings"
        self.temp_dir = self.base_dir / "temp"
        self.logs_dir = self.base_dir / "logs"
        
        # Ensure directories exist
        for directory in [self.recordings_dir, self.temp_dir, self.logs_dir]:
            directory.mkdir(parents=True, exist_ok=True)
        
        # Setup logging
        self.setup_logging()
        
        # Initialize Supabase
        self.db = SupabaseManager()
        
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
        
        self.logger.info("🎬 EZREC Orchestrator initialized - Production Version")
    
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
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        self.logger.info(f"🛑 Received signal {signum}, shutting down...")
        self.stop_event.set()
        self.is_running = False
    
    async def start_orchestrator(self):
        """Start the main orchestrator process"""
        try:
            self.logger.info("🚀 Starting EZREC Orchestrator...")
            self.is_running = True
            self.stop_event.clear()
            
            # Protect camera from other processes
            await self.protect_camera_resources()
            
            # Update initial system status
            await self.update_system_status("running")
            
            # Start background threads
            self.start_background_threads()
            
            # Main orchestrator loop
            await self.main_orchestrator_loop()
            
        except Exception as e:
            self.logger.error(f"❌ Orchestrator startup failed: {e}")
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
    
    def start_background_threads(self):
        """Start background monitoring threads"""
        # Status update thread (every 3 seconds)
        status_thread = threading.Thread(
            target=self.status_update_loop, 
            name="StatusUpdater",
            daemon=True
        )
        status_thread.start()
        
        self.logger.info("✅ Background threads started")
    
    async def main_orchestrator_loop(self):
        """Main orchestration loop"""
        self.logger.info("🔄 Starting main orchestrator loop...")
        
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
    
    async def get_upcoming_bookings(self) -> List[Dict]:
        """Get bookings that should start recording soon"""
        try:
            now = datetime.now()
            today = now.date()
            current_time = now.time()
            
            # Get bookings for today that haven't started yet or are currently active
            query = f"""
            SELECT * FROM bookings 
            WHERE date = '{today}' 
            AND user_id = '{self.config.USER_ID}'
            ORDER BY start_time ASC
            """
            
            response = await self.db.execute_query(query)
            # FIXED: execute_query returns data directly, not wrapped in success/data
            if response and isinstance(response, list):
                return response
            return []
            
        except Exception as e:
            self.logger.error(f"❌ Failed to get bookings: {e}")
            return []
    
    def should_start_recording(self, booking: Dict) -> bool:
        """Check if recording should start for this booking"""
        try:
            now = datetime.now()
            booking_date = datetime.strptime(booking['date'], '%Y-%m-%d').date()
            
            # Handle both HH:MM and HH:MM:SS time formats
            start_time_str = booking['start_time']
            if len(start_time_str.split(':')) == 3:  # HH:MM:SS format
                booking_start = datetime.strptime(start_time_str, '%H:%M:%S').time()
            else:  # HH:MM format
                booking_start = datetime.strptime(start_time_str, '%H:%M').time()
            
            booking_datetime = datetime.combine(booking_date, booking_start)
            
            # Start recording if we're within 30 seconds of start time
            time_diff = (booking_datetime - now).total_seconds()
            
            self.logger.info(f"🕐 Booking {booking['id']}: {booking_datetime}, Time diff: {time_diff}s")
            
            return (-30 <= time_diff <= 30) and not self.recording_active
            
        except Exception as e:
            self.logger.error(f"❌ Error checking start time: {e}")
            return False
    
    def should_stop_recording(self, booking: Dict) -> bool:
        """Check if recording should stop for this booking"""
        try:
            now = datetime.now()
            booking_date = datetime.strptime(booking['date'], '%Y-%m-%d').date()
            
            # Handle both HH:MM and HH:MM:SS time formats
            end_time_str = booking['end_time']
            if len(end_time_str.split(':')) == 3:  # HH:MM:SS format
                booking_end = datetime.strptime(end_time_str, '%H:%M:%S').time()
            else:  # HH:MM format
                booking_end = datetime.strptime(end_time_str, '%H:%M').time()
            
            booking_end_datetime = datetime.combine(booking_date, booking_end)
            
            return now >= booking_end_datetime
            
        except Exception as e:
            self.logger.error(f"❌ Error checking end time: {e}")
            return False
    
    async def start_booking_recording(self, booking: Dict):
        """Start recording for a booking using Picamera2"""
        try:
            self.logger.info(f"🎬 Starting recording for booking: {booking['id']}")
            
            # Set current booking
            self.current_booking = booking
            self.recording_active = True
            self.system_status["current_booking"] = booking['id']
            self.system_status["recording_active"] = True
            
            # Create recording filename
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"recording_{booking['id']}_{timestamp}.mp4"
            recording_path = self.recordings_dir / filename
            
            # Start Picamera2 recording
            await self.start_picamera2_recording(str(recording_path))
            
            self.logger.info(f"✅ Recording started: {filename}")
            self.system_status["total_recordings"] += 1
            
        except Exception as e:
            self.logger.error(f"❌ Failed to start recording: {e}")
            await self.handle_recording_error(booking, str(e))
    
    async def start_picamera2_recording(self, output_path: str):
        """Start Picamera2 recording process"""
        try:
            # Python script for Picamera2 recording
            recording_script = f"""
import time
from picamera2 import Picamera2
from picamera2.encoders import H264Encoder
from picamera2.outputs import FileOutput

picam2 = Picamera2()
picam2.configure(picam2.create_video_configuration())
encoder = H264Encoder(bitrate=10000000)
output = FileOutput('{output_path}')

picam2.start_recording(encoder, output)

# Keep recording until stopped
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    pass
finally:
    picam2.stop_recording()
    picam2.close()
"""
            
            # Write recording script
            script_path = self.temp_dir / "record.py"
            with open(script_path, 'w') as f:
                f.write(recording_script)
            
            # Start recording process
            self.camera_process = subprocess.Popen([
                "python3", str(script_path)
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            self.logger.info(f"📹 Picamera2 recording started: PID {self.camera_process.pid}")
            
        except Exception as e:
            self.logger.error(f"❌ Picamera2 recording failed: {e}")
            raise
    
    async def stop_booking_recording(self):
        """Stop current recording and process the video"""
        try:
            if not self.current_booking or not self.recording_active:
                return
            
            self.logger.info(f"🛑 Stopping recording for booking: {self.current_booking['id']}")
            
            # Stop camera process
            if self.camera_process:
                self.camera_process.terminate()
                self.camera_process.wait(timeout=10)
                self.camera_process = None
            
            # Find the recording file
            recording_files = list(self.recordings_dir.glob(f"recording_{self.current_booking['id']}_*.mp4"))
            
            if recording_files:
                recording_path = recording_files[0]
                await self.process_completed_recording(self.current_booking, str(recording_path))
            else:
                self.logger.error("❌ No recording file found")
            
            # Reset state
            self.recording_active = False
            self.system_status["recording_active"] = False
            self.system_status["current_booking"] = None
            self.current_booking = None
            
            self.logger.info("✅ Recording stopped and processed")
            
        except Exception as e:
            self.logger.error(f"❌ Error stopping recording: {e}")
            await self.handle_recording_error(self.current_booking, str(e))
    
    async def process_completed_recording(self, booking: Dict, recording_path: str):
        """Process completed recording: upload and cleanup"""
        try:
            self.logger.info(f"📤 Processing recording: {recording_path}")
            
            # Upload video to Supabase storage and videos table
            upload_success = await self.upload_video_to_storage(booking, recording_path)
            
            if upload_success:
                self.logger.info("✅ Video uploaded successfully")
                self.system_status["successful_uploads"] += 1
                
                # Remove booking from database
                await self.remove_booking(booking['id'])
                
                # Clean up local file
                await self.cleanup_local_recording(recording_path)
                
                self.logger.info("🧹 Booking completed and cleaned up")
            else:
                self.logger.error("❌ Video upload failed")
                self.system_status["errors_count"] += 1
                
        except Exception as e:
            self.logger.error(f"❌ Error processing recording: {e}")
            await self.handle_recording_error(booking, str(e))
    
    async def upload_video_to_storage(self, booking: Dict, recording_path: str) -> bool:
        """Upload video to Supabase storage and create videos table entry"""
        try:
            filename = Path(recording_path).name
            storage_path = f"recordings/{self.config.USER_ID}/{filename}"
            
            # Upload to storage bucket
            with open(recording_path, 'rb') as f:
                upload_response = self.db.supabase.storage.from_("videos").upload(
                    storage_path, f, file_options={"content-type": "video/mp4"}
                )
            
            if upload_response:
                # Create entry in videos table
                video_data = {
                    "user_id": self.config.USER_ID,
                    "filename": filename,
                    "storage_path": storage_path,
                    "booking_id": booking['id']
                }
                
                insert_response = self.db.supabase.table("videos").insert(video_data).execute()
                
                if insert_response.data:
                    self.logger.info(f"✅ Video uploaded: {storage_path}")
                    return True
            
            return False
            
        except Exception as e:
            self.logger.error(f"❌ Upload failed: {e}")
            return False
    
    async def remove_booking(self, booking_id: str):
        """Remove booking from database after completion"""
        try:
            response = self.db.supabase.table("bookings").delete().eq("id", booking_id).execute()
            if response.data:
                self.logger.info(f"🗑️ Booking removed: {booking_id}")
            else:
                self.logger.error(f"❌ Failed to remove booking: {booking_id}")
                
        except Exception as e:
            self.logger.error(f"❌ Error removing booking: {e}")
    
    async def cleanup_local_recording(self, recording_path: str):
        """Delete local recording file after successful upload"""
        try:
            Path(recording_path).unlink()
            self.logger.info(f"🧹 Local file deleted: {recording_path}")
        except Exception as e:
            self.logger.error(f"❌ Failed to delete local file: {e}")
    
    async def handle_recording_error(self, booking: Dict, error_msg: str):
        """Handle recording errors"""
        self.logger.error(f"❌ Recording error for {booking['id']}: {error_msg}")
        self.system_status["errors_count"] += 1
        self.recording_active = False
        self.system_status["recording_active"] = False
        self.current_booking = None
        self.system_status["current_booking"] = None
    
    def status_update_loop(self):
        """Update system status every 3 seconds"""
        while self.is_running and not self.stop_event.is_set():
            try:
                asyncio.run(self.update_system_status_in_db())
                time.sleep(3)  # Update every 3 seconds
            except Exception as e:
                self.logger.error(f"❌ Status update error: {e}")
                time.sleep(3)
    
    async def update_system_status(self, status: str, error: Optional[str] = None):
        """Update orchestrator status"""
        self.system_status["orchestrator_status"] = status
        self.system_status["last_update"] = datetime.now().isoformat()
        if error:
            self.system_status["last_error"] = error
    
    async def update_system_status_in_db(self):
        """Update system status in database"""
        try:
            # Get system metrics
            cpu_percent = psutil.cpu_percent()
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            # Prepare status data
            status_data = {
                "user_id": self.config.USER_ID,
                "is_recording": self.recording_active,
                "pi_active": True,
                "last_heartbeat": datetime.now().isoformat(),
                "cpu_usage_percent": cpu_percent,
                "memory_usage_percent": memory.percent,
                "disk_usage_percent": disk.percent,
                "cameras_online": 1 if self.system_status["camera_status"] == "available" else 0,
                "total_cameras": 1,
                "current_booking_id": self.system_status["current_booking"],
                "last_seen": datetime.now().isoformat()
            }
            
            # Update or insert system status
            response = self.db.supabase.table("system_status").upsert(
                status_data, on_conflict="user_id"
            ).execute()
            
        except Exception as e:
            self.logger.error(f"❌ Failed to update system status: {e}")
    
    async def stop_orchestrator(self):
        """Stop orchestrator gracefully"""
        self.logger.info("🛑 Stopping EZREC Orchestrator...")
        self.is_running = False
        self.stop_event.set()
        
        # Stop any active recording
        if self.camera_process:
            self.camera_process.terminate()
            self.camera_process.wait(timeout=10)
        
        await self.update_system_status("stopped")
        self.logger.info("✅ Orchestrator stopped")

async def main():
    """Main entry point"""
    orchestrator = EZRECOrchestrator()
    
    try:
        await orchestrator.start_orchestrator()
    except KeyboardInterrupt:
        await orchestrator.stop_orchestrator()
    except Exception as e:
        logging.error(f"❌ Fatal error: {e}")
        await orchestrator.stop_orchestrator()

if __name__ == "__main__":
    asyncio.run(main()) 