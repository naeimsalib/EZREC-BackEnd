#!/usr/bin/env python3
"""
EZREC Backend Orchestrator - FIXED VERSION
Main orchestration module that coordinates booking detection, recording, and upload
with corrected database connections and video upload functionality
"""
import time
import threading
import queue
import os
import sys
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import signal

# Add the src directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from utils import (
    setup_logging, logger, get_next_booking, upload_video_to_supabase,
    update_system_status, save_booking, load_booking, complete_booking
)
from camera_interface import CameraInterface
from config import (
    BOOKING_CHECK_INTERVAL, STATUS_UPDATE_INTERVAL, HEARTBEAT_INTERVAL,
    USER_ID, CAMERA_ID, RECORDING_DIR
)

class EZRECOrchestrator:
    """
    FIXED EZREC Backend Orchestrator with corrected database connections
    """
    
    def __init__(self):
        """Initialize the orchestrator with fixed configuration."""
        self.logger = setup_logging()
        self.logger.info("=" * 60)
        self.logger.info("🚀 EZREC Orchestrator Starting - FIXED VERSION")
        self.logger.info("=" * 60)
        
        # Core state
        self.running = False
        self.recording = False
        self.current_booking = None
        
        # Threading infrastructure
        self.shutdown_event = threading.Event()
        self.booking_queue = queue.Queue()
        
        # Thread references
        self.booking_thread = None
        self.recording_thread = None
        self.status_thread = None
        self.heartbeat_thread = None
        
        # Recording management
        self.recording_errors = 0
        
        # Camera interface
        self.camera = None
        self._init_camera()
        
        # Signal handling
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
        
        self.logger.info(f"📊 Configuration:")
        self.logger.info(f"   User ID: {USER_ID}")
        self.logger.info(f"   Camera ID: {CAMERA_ID}")
        self.logger.info(f"   Booking Check Interval: {BOOKING_CHECK_INTERVAL}s")
        self.logger.info(f"   Status Update Interval: {STATUS_UPDATE_INTERVAL}s")
        self.logger.info("=" * 60)
    
    def _init_camera(self):
        """Initialize camera interface with error handling."""
        try:
            self.camera = CameraInterface()
            self.logger.info("✅ Camera interface initialized")
        except Exception as e:
            self.logger.error(f"❌ Camera initialization failed: {e}")
            self.camera = None
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully."""
        self.logger.info(f"🛑 Received signal {signum}, shutting down...")
        self.stop()
    
    def start(self):
        """Start all orchestrator threads with fixed booking detection."""
        if self.running:
            self.logger.warning("⚠️ Orchestrator already running")
            return
        
        self.running = True
        self.shutdown_event.clear()
        
        self.logger.info("🚀 Starting EZREC Orchestrator threads...")
        
        try:
            # Start booking monitoring thread (FIXED)
            self.booking_thread = threading.Thread(
                target=self._booking_monitor_loop,
                name="BookingMonitor",
                daemon=True
            )
            self.booking_thread.start()
            self.logger.info("✅ Booking monitor thread started")
            
            # Start recording management thread
            self.recording_thread = threading.Thread(
                target=self._recording_loop,
                name="RecordingManager",
                daemon=True
            )
            self.recording_thread.start()
            self.logger.info("✅ Recording manager thread started")
            
            # Start system status update thread (FIXED)
            self.status_thread = threading.Thread(
                target=self._status_update_loop,
                name="StatusUpdater",
                daemon=True
            )
            self.status_thread.start()
            self.logger.info("✅ Status updater thread started")
            
            # Start heartbeat thread
            self.heartbeat_thread = threading.Thread(
                target=self._heartbeat_loop,
                name="Heartbeat",
                daemon=True
            )
            self.heartbeat_thread.start()
            self.logger.info("✅ Heartbeat thread started")
            
            self.logger.info("🎯 All threads started successfully")
            self.logger.info("🔍 Monitoring for bookings...")
            
        except Exception as e:
            self.logger.error(f"❌ Error starting threads: {e}")
            self.stop()
    
    def _booking_monitor_loop(self):
        """
        FIXED: Monitor for new bookings with proper database queries.
        """
        self.logger.info("🔍 Booking monitor started")
        
        while not self.shutdown_event.is_set():
            try:
                # FIXED: Use corrected booking detection
                booking = get_next_booking()
                
                if booking:
                    if not self.current_booking or booking['id'] != self.current_booking.get('id'):
                        self.logger.info(f"📋 New booking detected: {booking['id']}")
                        self.logger.info(f"   Date: {booking['date']}")
                        self.logger.info(f"   Time: {booking['start_time']} - {booking['end_time']}")
                        self.logger.info(f"   User: {booking['user_id']}")
                        
                        # Queue the booking for processing
                        self.booking_queue.put(booking)
                        save_booking(booking)
                        self.current_booking = booking
                else:
                    if self.current_booking:
                        self.logger.debug("📭 No active bookings")
                        self.current_booking = None
                
                # Wait before next check
                self.shutdown_event.wait(BOOKING_CHECK_INTERVAL)
                
            except Exception as e:
                self.logger.error(f"❌ Error in booking monitor: {e}")
                self.shutdown_event.wait(BOOKING_CHECK_INTERVAL)
    
    def _recording_loop(self):
        """Handle recording scheduling and execution with FIXED upload."""
        self.logger.info("📹 Recording manager started")
        
        while not self.shutdown_event.is_set():
            try:
                # Check for new bookings
                try:
                    booking = self.booking_queue.get(timeout=1.0)
                    self.logger.info(f"📋 Processing booking: {booking['id']}")
                    
                    # Schedule recording
                    success = self._schedule_and_record(booking)
                    
                    if success:
                        self.logger.info(f"✅ Booking {booking['id']} completed successfully")
                        complete_booking(booking['id'])
                    else:
                        self.logger.error(f"❌ Booking {booking['id']} failed")
                        self.recording_errors += 1
                        
                except queue.Empty:
                    continue
                    
            except Exception as e:
                self.logger.error(f"❌ Error in recording loop: {e}")
                self.recording_errors += 1
    
    def _schedule_and_record(self, booking: Dict[str, Any]) -> bool:
        """
        Schedule and execute recording for a booking with FIXED upload.
        """
        try:
            booking_date = booking['date']
            start_time = booking['start_time']
            end_time = booking['end_time']
            booking_id = booking['id']
            
            # Parse times
            start_datetime = datetime.strptime(f"{booking_date} {start_time}", "%Y-%m-%d %H:%M")
            end_datetime = datetime.strptime(f"{booking_date} {end_time}", "%Y-%m-%d %H:%M")
            
            now = datetime.now()
            
            # Wait until start time
            if start_datetime > now:
                wait_seconds = (start_datetime - now).total_seconds()
                self.logger.info(f"⏰ Waiting {wait_seconds:.0f} seconds until recording start...")
                
                if self.shutdown_event.wait(wait_seconds):
                    return False  # Shutdown requested
            
            # Calculate recording duration
            duration_seconds = (end_datetime - start_datetime).total_seconds()
            self.logger.info(f"🎬 Starting recording for {duration_seconds:.0f} seconds")
            
            # Start recording
            if not self.camera:
                self.logger.error("❌ Camera not available for recording")
                return False
            
            self.recording = True
            
            # Generate filename with booking ID
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"rec_{booking_id}_{timestamp}.mp4"
            video_path = os.path.join(RECORDING_DIR, filename)
            
            # Ensure recording directory exists
            os.makedirs(RECORDING_DIR, exist_ok=True)
            
            try:
                # Start recording
                self.logger.info(f"📹 Starting recording to: {video_path}")
                actual_path = self.camera.start_recording(filename)
                
                if actual_path:
                    self.logger.info(f"✅ Recording started successfully")
                    
                    # Wait for recording duration
                    self.logger.info(f"⏰ Recording for {duration_seconds:.0f} seconds...")
                    if self.shutdown_event.wait(duration_seconds):
                        # Shutdown requested during recording
                        self.logger.info("🛑 Shutdown requested, stopping recording...")
                        self.camera.stop_recording()
                        return False
                    
                    # Stop recording
                    self.logger.info("🛑 Stopping recording...")
                    final_path = self.camera.stop_recording()
                    
                    if final_path and os.path.exists(final_path):
                        self.logger.info(f"✅ Recording completed: {os.path.basename(final_path)}")
                        
                        # FIXED: Upload to Supabase Storage and videos table
                        self.logger.info("📤 Uploading video to Supabase...")
                        upload_result = upload_video_to_supabase(final_path, booking_id)
                        
                        if upload_result.get('success'):
                            self.logger.info(f"✅ Video uploaded successfully")
                            self.logger.info(f"   Storage Path: {upload_result.get('storage_path')}")
                            self.logger.info(f"   Video ID: {upload_result.get('video_id')}")
                            self.logger.info(f"   Table: {upload_result.get('table', 'videos')}")
                            
                            # Optionally delete local file after successful upload
                            if os.getenv("DELETE_AFTER_UPLOAD", "false").lower() == "true":
                                try:
                                    os.remove(final_path)
                                    self.logger.info(f"🗑️ Deleted local file: {os.path.basename(final_path)}")
                                except Exception as e:
                                    self.logger.warning(f"⚠️ Could not delete local file: {e}")
                        else:
                            self.logger.warning(f"⚠️ Video upload failed: {upload_result.get('error')}")
                            self.logger.info(f"📁 Video saved locally: {final_path}")
                        
                        return True
                    else:
                        self.logger.error(f"❌ Recording failed or file not created")
                        return False
                else:
                    self.logger.error(f"❌ Failed to start recording")
                    return False
                    
            finally:
                self.recording = False
                
        except Exception as e:
            self.logger.error(f"❌ Error in recording: {e}")
            self.recording = False
            return False
    
    def _status_update_loop(self):
        """
        FIXED: Update system status with proper database connection.
        """
        self.logger.info("📊 Status updater started")
        
        while not self.shutdown_event.is_set():
            try:
                # FIXED: Use corrected status update function
                update_system_status(
                    is_recording=self.recording,
                    recording_errors=self.recording_errors,
                    current_booking_id=self.current_booking['id'] if self.current_booking else None
                )
                
                self.shutdown_event.wait(STATUS_UPDATE_INTERVAL)
                
            except Exception as e:
                self.logger.error(f"❌ Error updating status: {e}")
                self.shutdown_event.wait(STATUS_UPDATE_INTERVAL)
    
    def _heartbeat_loop(self):
        """Send periodic heartbeat signals."""
        self.logger.info("💓 Heartbeat thread started")
        
        while not self.shutdown_event.is_set():
            try:
                # Send heartbeat
                update_system_status(last_heartbeat=datetime.now().isoformat())
                self.logger.debug("💓 Heartbeat sent")
                
                self.shutdown_event.wait(HEARTBEAT_INTERVAL)
                
            except Exception as e:
                self.logger.error(f"❌ Error in heartbeat: {e}")
                self.shutdown_event.wait(HEARTBEAT_INTERVAL)
    
    def stop(self):
        """Stop all threads gracefully."""
        if not self.running:
            return
        
        self.logger.info("🛑 Stopping EZREC Orchestrator...")
        
        self.running = False
        self.shutdown_event.set()
        
        # Stop recording if active
        if self.recording and self.camera:
            try:
                self.camera.stop_recording()
                self.recording = False
                self.logger.info("🛑 Recording stopped")
            except Exception as e:
                self.logger.error(f"❌ Error stopping recording: {e}")
        
        # Wait for threads to finish
        threads = [
            ('Booking Monitor', self.booking_thread),
            ('Recording Manager', self.recording_thread),
            ('Status Updater', self.status_thread),
            ('Heartbeat', self.heartbeat_thread)
        ]
        
        for name, thread in threads:
            if thread and thread.is_alive():
                try:
                    thread.join(timeout=5.0)
                    if thread.is_alive():
                        self.logger.warning(f"⚠️ {name} thread did not stop gracefully")
                    else:
                        self.logger.info(f"✅ {name} thread stopped")
                except Exception as e:
                    self.logger.error(f"❌ Error stopping {name} thread: {e}")
        
        # Final status update
        try:
            update_system_status(is_recording=False, pi_active=False)
            self.logger.info("📊 Final status update sent")
        except Exception as e:
            self.logger.error(f"❌ Error sending final status: {e}")
        
        self.logger.info("🛑 EZREC Orchestrator stopped")
    
    def run(self):
        """Main run loop."""
        try:
            self.start()
            
            # Keep main thread alive
            while self.running:
                time.sleep(1)
                
        except KeyboardInterrupt:
            self.logger.info("⌨️ Keyboard interrupt received")
        except Exception as e:
            self.logger.error(f"❌ Fatal error: {e}")
        finally:
            self.stop()

def main():
    """Main entry point."""
    try:
        orchestrator = EZRECOrchestrator()
        orchestrator.run()
    except Exception as e:
        logger.error(f"❌ Failed to start orchestrator: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 