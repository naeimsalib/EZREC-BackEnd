#!/usr/bin/env python3
"""
🎬 EZREC Orchestrator - Complete Booking Lifecycle Manager
Handles: Bookings → Recording → Upload → Cleanup
Optimized for Raspberry Pi with Picamera2 and 3-second status updates
"""

import os
import sys
import time
import logging
import asyncio
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
import json
from pathlib import Path

# Add project root to path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

from src.config import Config
from src.camera_interface import get_camera_instance, cleanup_camera_instance
from src.utils import SupabaseManager

class EZRECOrchestrator:
    """
    🎬 EZREC Main Orchestrator - Complete Booking Management
    
    Workflow:
    1. Reads bookings from Supabase (start/end times)
    2. Starts recording at booking start time
    3. Updates status every 3 seconds during recording
    4. Stops recording at booking end time
    5. Removes booking from bookings table
    6. Uploads video to videos table + storage bucket
    7. Removes local file after confirmed upload
    8. Updates all system status every 3 seconds
    """
    
    def __init__(self):
        """Initialize EZREC Orchestrator"""
        self.config = Config()
        self.is_running = False
        self.current_booking: Optional[Dict] = None
        self.recording_active = False
        self.status_update_thread: Optional[threading.Thread] = None
        self.booking_monitor_thread: Optional[threading.Thread] = None
        self.stop_event = threading.Event()
        
        # Directories
        self.recordings_dir = Path("/opt/ezrec-backend/recordings")
        self.temp_dir = Path("/opt/ezrec-backend/temp")
        self.logs_dir = Path("/opt/ezrec-backend/logs")
        
        # Ensure directories exist
        for directory in [self.recordings_dir, self.temp_dir, self.logs_dir]:
            directory.mkdir(parents=True, exist_ok=True)
        
        # Setup logging
        self.setup_logging()
        
        # Initialize components
        self.db = SupabaseManager()
        self.camera = get_camera_instance("pi_camera_1")
        
        # System status
        self.system_status = {
            "orchestrator_status": "initializing",
            "camera_status": "unknown",
            "current_booking": None,
            "recording_active": False,
            "last_update": datetime.now().isoformat(),
            "uptime_start": datetime.now().isoformat(),
            "total_recordings": 0,
            "successful_uploads": 0,
            "errors_count": 0
        }
        
        self.logger.info("🎬 EZREC Orchestrator initialized")
    
    def setup_logging(self):
        """Setup comprehensive logging"""
        log_file = self.logs_dir / f"ezrec_orchestrator_{datetime.now().strftime('%Y%m%d')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        
        self.logger = logging.getLogger("EZREC.Orchestrator")
    
    async def start_orchestrator(self):
        """Start the main orchestrator process"""
        try:
            self.logger.info("🚀 Starting EZREC Orchestrator...")
            self.is_running = True
            self.stop_event.clear()
            
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
    
    def start_background_threads(self):
        """Start background monitoring threads"""
        # Status update thread (every 3 seconds)
        self.status_update_thread = threading.Thread(
            target=self.status_update_loop, 
            name="StatusUpdater",
            daemon=True
        )
        self.status_update_thread.start()
        
        # Booking monitor thread
        self.booking_monitor_thread = threading.Thread(
            target=self.booking_monitor_loop,
            name="BookingMonitor", 
            daemon=True
        )
        self.booking_monitor_thread.start()
        
        self.logger.info("✅ Background threads started")
    
    async def main_orchestrator_loop(self):
        """Main orchestration loop"""
        self.logger.info("🔄 Starting main orchestrator loop...")
        
        while self.is_running and not self.stop_event.is_set():
            try:
                # Check for active bookings
                active_bookings = await self.get_active_bookings()
                
                if active_bookings:
                    for booking in active_bookings:
                        await self.process_booking(booking)
                
                # Process any scheduled bookings
                upcoming_bookings = await self.get_upcoming_bookings()
                
                for booking in upcoming_bookings:
                    if self.should_start_recording(booking):
                        await self.start_booking_recording(booking)
                
                # Check if current recording should stop
                if self.current_booking and self.recording_active:
                    if self.should_stop_recording(self.current_booking):
                        await self.stop_booking_recording()
                
                # Brief pause to prevent excessive CPU usage
                await asyncio.sleep(1)
                
            except Exception as e:
                self.logger.error(f"❌ Error in main orchestrator loop: {e}")
                self.system_status["errors_count"] += 1
                await asyncio.sleep(5)  # Longer pause on error
    
    async def get_active_bookings(self) -> List[Dict]:
        """Get currently active bookings"""
        try:
            now = datetime.now()
            
            # Query for bookings that are currently active
            query = f"""
            SELECT * FROM bookings 
            WHERE date = '{now.date()}' 
            AND start_time <= '{now.time()}' 
            AND end_time > '{now.time()}'
            ORDER BY start_time ASC
            """
            
            result = await self.db.execute_query(query)
            return result.get('data', []) if result['success'] else []
            
        except Exception as e:
            self.logger.error(f"❌ Failed to get active bookings: {e}")
            return []
    
    async def get_upcoming_bookings(self) -> List[Dict]:
        """Get upcoming bookings that should start soon"""
        try:
            now = datetime.now()
            soon = now + timedelta(minutes=1)  # Look ahead 1 minute
            
            query = f"""
            SELECT * FROM bookings 
            WHERE date = '{now.date()}' 
            AND start_time > '{now.time()}' 
            AND start_time <= '{soon.time()}'
            ORDER BY start_time ASC
            """
            
            result = await self.db.execute_query(query)
            return result.get('data', []) if result['success'] else []
            
        except Exception as e:
            self.logger.error(f"❌ Failed to get upcoming bookings: {e}")
            return []
    
    def should_start_recording(self, booking: Dict) -> bool:
        """Check if recording should start for a booking"""
        try:
            now = datetime.now()
            booking_date = datetime.strptime(booking['date'], '%Y-%m-%d').date()
            booking_start = datetime.strptime(booking['start_time'], '%H:%M:%S').time()
            
            booking_start_datetime = datetime.combine(booking_date, booking_start)
            
            # Start recording if it's time (within 30 seconds)
            time_diff = (booking_start_datetime - now).total_seconds()
            return -30 <= time_diff <= 30 and not self.recording_active
            
        except Exception as e:
            self.logger.error(f"❌ Error checking recording start: {e}")
            return False
    
    def should_stop_recording(self, booking: Dict) -> bool:
        """Check if recording should stop for current booking"""
        try:
            now = datetime.now()
            booking_date = datetime.strptime(booking['date'], '%Y-%m-%d').date()
            booking_end = datetime.strptime(booking['end_time'], '%H:%M:%S').time()
            
            booking_end_datetime = datetime.combine(booking_date, booking_end)
            
            # Stop recording if end time has passed
            return now >= booking_end_datetime
            
        except Exception as e:
            self.logger.error(f"❌ Error checking recording stop: {e}")
            return True  # Stop on error to be safe
    
    async def start_booking_recording(self, booking: Dict):
        """Start recording for a booking"""
        try:
            self.logger.info(f"🎬 Starting recording for booking {booking['id']}")
            
            # Set current booking
            self.current_booking = booking
            
            # Generate recording filename
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"booking_{booking['id']}_{timestamp}.mp4"
            recording_path = self.recordings_dir / filename
            
            # Start camera recording
            success = self.camera.start_recording(booking['id'], str(recording_path))
            
            if success:
                self.recording_active = True
                self.system_status["recording_active"] = True
                self.system_status["current_booking"] = booking['id']
                
                # Create recording entry in database
                await self.create_recording_entry(booking, str(recording_path))
                
                self.logger.info(f"✅ Recording started successfully: {filename}")
            else:
                self.logger.error(f"❌ Failed to start camera recording for booking {booking['id']}")
                await self.handle_recording_error(booking, "Camera start failed")
                
        except Exception as e:
            self.logger.error(f"❌ Error starting booking recording: {e}")
            await self.handle_recording_error(booking, str(e))
    
    async def stop_booking_recording(self):
        """Stop current booking recording and process video"""
        try:
            if not self.current_booking or not self.recording_active:
                return
            
            booking = self.current_booking
            self.logger.info(f"🛑 Stopping recording for booking {booking['id']}")
            
            # Stop camera recording
            success, recording_path = self.camera.stop_recording()
            
            if success and recording_path:
                self.logger.info(f"✅ Recording stopped: {recording_path}")
                
                # Process the completed recording
                await self.process_completed_recording(booking, recording_path)
                
            else:
                self.logger.error(f"❌ Failed to stop recording for booking {booking['id']}")
                
            # Clear current booking state
            self.recording_active = False
            self.system_status["recording_active"] = False
            self.system_status["current_booking"] = None
            self.current_booking = None
            
        except Exception as e:
            self.logger.error(f"❌ Error stopping booking recording: {e}")
            self.recording_active = False
            self.current_booking = None
    
    async def process_completed_recording(self, booking: Dict, recording_path: str):
        """Process completed recording through full lifecycle"""
        try:
            self.logger.info(f"📹 Processing completed recording for booking {booking['id']}")
            
            # Verify recording file exists and has content
            if not os.path.exists(recording_path) or os.path.getsize(recording_path) == 0:
                self.logger.error(f"❌ Recording file missing or empty: {recording_path}")
                return
            
            file_size = os.path.getsize(recording_path)
            self.logger.info(f"📊 Recording file size: {file_size} bytes")
            
            # Step 1: Remove booking from bookings table
            await self.remove_booking(booking['id'])
            
            # Step 2: Upload video to storage and create video entry
            upload_success = await self.upload_video_to_storage(booking, recording_path)
            
            if upload_success:
                # Step 3: Remove local file after confirmed upload
                await self.cleanup_local_recording(recording_path)
                self.system_status["successful_uploads"] += 1
                self.system_status["total_recordings"] += 1
                
                self.logger.info(f"✅ Successfully processed recording for booking {booking['id']}")
            else:
                self.logger.error(f"❌ Failed to upload recording for booking {booking['id']}")
                self.system_status["errors_count"] += 1
                
        except Exception as e:
            self.logger.error(f"❌ Error processing completed recording: {e}")
            self.system_status["errors_count"] += 1
    
    async def create_recording_entry(self, booking: Dict, recording_path: str):
        """Create recording entry in database"""
        try:
            recording_data = {
                "booking_id": booking['id'],
                "camera_id": booking.get('camera_id', 'pi_camera_1'),
                "user_id": booking['user_id'],
                "file_path": recording_path,
                "start_time": datetime.now().isoformat(),
                "status": "recording",
                "file_size": 0  # Will be updated when recording completes
            }
            
            result = await self.db.create_record("recordings", recording_data)
            if result['success']:
                self.logger.info(f"✅ Recording entry created: {result['data']['id']}")
            else:
                self.logger.error(f"❌ Failed to create recording entry: {result['error']}")
                
        except Exception as e:
            self.logger.error(f"❌ Error creating recording entry: {e}")
    
    async def remove_booking(self, booking_id: str):
        """Remove booking from bookings table"""
        try:
            result = await self.db.delete_record("bookings", booking_id)
            if result['success']:
                self.logger.info(f"✅ Booking {booking_id} removed from bookings table")
            else:
                self.logger.error(f"❌ Failed to remove booking {booking_id}: {result['error']}")
                
        except Exception as e:
            self.logger.error(f"❌ Error removing booking: {e}")
    
    async def upload_video_to_storage(self, booking: Dict, recording_path: str) -> bool:
        """Upload video to Supabase storage and create video entry"""
        try:
            self.logger.info(f"⬆️  Uploading video to storage: {recording_path}")
            
            # Generate storage path
            filename = os.path.basename(recording_path)
            storage_path = f"recordings/{booking['user_id']}/{filename}"
            
            # Upload to storage bucket
            upload_result = await self.db.upload_file_to_storage(
                bucket_name="videos",
                file_path=recording_path,
                storage_path=storage_path
            )
            
            if not upload_result['success']:
                self.logger.error(f"❌ Storage upload failed: {upload_result['error']}")
                return False
            
            storage_url = upload_result.get('public_url')
            self.logger.info(f"✅ Video uploaded to storage: {storage_url}")
            
            # Create video entry in videos table
            video_data = {
                "booking_id": booking['id'],
                "user_id": booking['user_id'],
                "camera_id": booking.get('camera_id', 'pi_camera_1'),
                "title": f"Recording - {booking.get('title', 'Untitled')}",
                "description": f"Recorded on {booking['date']} from {booking['start_time']} to {booking['end_time']}",
                "file_url": storage_url,
                "file_size": os.path.getsize(recording_path),
                "duration": await self.get_video_duration(recording_path),
                "recorded_at": datetime.now().isoformat(),
                "status": "completed"
            }
            
            video_result = await self.db.create_record("videos", video_data)
            if video_result['success']:
                self.logger.info(f"✅ Video entry created: {video_result['data']['id']}")
                return True
            else:
                self.logger.error(f"❌ Failed to create video entry: {video_result['error']}")
                return False
                
        except Exception as e:
            self.logger.error(f"❌ Error uploading video: {e}")
            return False
    
    async def get_video_duration(self, video_path: str) -> Optional[float]:
        """Get video duration in seconds"""
        try:
            # Try to get duration using ffprobe if available
            import subprocess
            result = subprocess.run([
                'ffprobe', '-v', 'quiet', '-show_entries', 'format=duration',
                '-of', 'default=noprint_wrappers=1:nokey=1', video_path
            ], capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                duration = float(result.stdout.strip())
                return duration
            else:
                return None
                
        except Exception:
            # Fallback: estimate based on file timestamps if ffprobe not available
            return None
    
    async def cleanup_local_recording(self, recording_path: str):
        """Remove local recording file after successful upload"""
        try:
            if os.path.exists(recording_path):
                os.remove(recording_path)
                self.logger.info(f"🧹 Local recording file removed: {recording_path}")
            else:
                self.logger.warning(f"⚠️  Local recording file not found: {recording_path}")
                
        except Exception as e:
            self.logger.error(f"❌ Error removing local recording file: {e}")
    
    async def handle_recording_error(self, booking: Dict, error_msg: str):
        """Handle recording errors"""
        try:
            self.logger.error(f"❌ Recording error for booking {booking['id']}: {error_msg}")
            
            # Update booking status to error
            await self.db.update_record("bookings", booking['id'], {
                "status": "error",
                "error_message": error_msg
            })
            
            self.system_status["errors_count"] += 1
            
        except Exception as e:
            self.logger.error(f"❌ Error handling recording error: {e}")
    
    def status_update_loop(self):
        """Background thread for status updates every 3 seconds"""
        self.logger.info("📊 Starting status update loop (3-second interval)")
        
        while self.is_running and not self.stop_event.is_set():
            try:
                # Update system status in database
                asyncio.run(self.update_system_status_in_db())
                
                # Update camera status
                self.update_camera_status()
                
                # Sleep for 3 seconds
                self.stop_event.wait(3)
                
            except Exception as e:
                self.logger.error(f"❌ Error in status update loop: {e}")
                time.sleep(3)
    
    def booking_monitor_loop(self):
        """Background thread for monitoring booking changes"""
        self.logger.info("📅 Starting booking monitor loop")
        
        while self.is_running and not self.stop_event.is_set():
            try:
                # This could be expanded to listen for real-time booking changes
                # For now, just ensure we're checking regularly
                self.stop_event.wait(10)  # Check every 10 seconds
                
            except Exception as e:
                self.logger.error(f"❌ Error in booking monitor loop: {e}")
                time.sleep(10)
    
    async def update_system_status(self, status: str, error: Optional[str] = None):
        """Update orchestrator system status"""
        self.system_status.update({
            "orchestrator_status": status,
            "last_update": datetime.now().isoformat(),
            "error": error
        })
    
    async def update_system_status_in_db(self):
        """Update system status in database"""
        try:
            # Get camera status
            camera_status = self.camera.get_status() if self.camera.is_available() else {"status": "unavailable"}
            
            # Prepare status data
            status_data = {
                **self.system_status,
                "camera_status": camera_status,
                "updated_at": datetime.now().isoformat()
            }
            
            # Update in database
            await self.db.upsert_system_status("orchestrator", status_data)
            
        except Exception as e:
            self.logger.error(f"❌ Failed to update system status in DB: {e}")
    
    def update_camera_status(self):
        """Update camera status in system status"""
        try:
            if self.camera.is_available():
                camera_status = self.camera.get_status()
                self.system_status["camera_status"] = camera_status.get("status", "unknown")
            else:
                self.system_status["camera_status"] = "unavailable"
                
        except Exception as e:
            self.logger.error(f"❌ Error updating camera status: {e}")
            self.system_status["camera_status"] = "error"
    
    async def process_booking(self, booking: Dict):
        """Process an individual booking"""
        # This method can be expanded for more complex booking processing
        pass
    
    async def stop_orchestrator(self):
        """Stop the orchestrator gracefully"""
        try:
            self.logger.info("🛑 Stopping EZREC Orchestrator...")
            self.is_running = False
            self.stop_event.set()
            
            # Stop any active recording
            if self.recording_active:
                await self.stop_booking_recording()
            
            # Update system status
            await self.update_system_status("stopped")
            
            # Cleanup camera
            cleanup_camera_instance()
            
            self.logger.info("✅ EZREC Orchestrator stopped")
            
        except Exception as e:
            self.logger.error(f"❌ Error stopping orchestrator: {e}")


# Global orchestrator instance
_orchestrator_instance: Optional[EZRECOrchestrator] = None

def get_orchestrator_instance() -> EZRECOrchestrator:
    """Get or create global orchestrator instance"""
    global _orchestrator_instance
    if _orchestrator_instance is None:
        _orchestrator_instance = EZRECOrchestrator()
    return _orchestrator_instance

async def main():
    """Main function to run the orchestrator"""
    orchestrator = get_orchestrator_instance()
    
    try:
        await orchestrator.start_orchestrator()
    except KeyboardInterrupt:
        print("\n🛑 Keyboard interrupt received")
    except Exception as e:
        print(f"❌ Orchestrator error: {e}")
    finally:
        await orchestrator.stop_orchestrator()

if __name__ == "__main__":
    print("🎬 EZREC Orchestrator - Complete Booking Lifecycle Manager")
    print("==========================================================")
    print("📅 Booking Management: ✅")
    print("🎬 Recording Control: ✅") 
    print("⬆️  Video Upload: ✅")
    print("🧹 Cleanup: ✅")
    print("📊 Status Updates: Every 3 seconds ✅")
    print("🎯 Platform: Raspberry Pi + Picamera2 ✅")
    print()
    
    # Run the orchestrator
    asyncio.run(main()) 