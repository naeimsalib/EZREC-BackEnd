#!/usr/bin/env python3
"""
EZREC Backend - Clean Orchestrator Service
Consolidated version that removes redundant code and provides a single entry point
for the camera recording system.
"""

import os
import time
import threading
import signal
import sys
from datetime import datetime
from typing import Optional, Dict, Any
import logging
from logging.handlers import RotatingFileHandler

# Import our modules
from .config import (
    USER_ID, CAMERA_ID, CAMERA_NAME, CAMERA_LOCATION,
    BOOKING_CHECK_INTERVAL, STATUS_UPDATE_INTERVAL,
    LOG_DIR, TEMP_DIR, RECORDING_DIR
)
from .utils import (
    logger, supabase, load_booking, remove_booking,
    update_system_status, get_storage_used, get_ip
)
from .camera import CameraService
from .scheduler import get_next_booking

class EZRECOrchestrator:
    """
    Main orchestrator class that coordinates all EZREC backend services.
    This consolidates functionality from multiple redundant files.
    """
    
    def __init__(self):
        self.camera_service = CameraService()
        self.stop_event = threading.Event()
        self.recording_thread = None
        self.status_thread = None
        self.scheduler_thread = None
        self.current_booking_id = None
        self.is_running = False
        self.recording_errors = 0
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
        logger.info("EZREC Orchestrator initialized")

    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully."""
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.stop()
        sys.exit(0)

    def start_recording(self, booking_id: str) -> bool:
        """Start recording for a specific booking."""
        try:
            logger.info(f"Starting recording for booking {booking_id}")
            
            if not self.camera_service.start_recording(booking_id=booking_id):
                logger.error("Failed to start recording")
                self.recording_errors += 1
                return False

            self.current_booking_id = booking_id
            logger.info(f"Successfully started recording for booking {booking_id}")
            return True

        except Exception as e:
            logger.error(f"Error starting recording: {e}", exc_info=True)
            return False

    def stop_recording(self) -> bool:
        """Stop the current recording."""
        try:
            logger.info("Stopping current recording")
            if self.camera_service.stop_recording():
                logger.info("Recording stopped successfully")
                self.current_booking_id = None
                return True
            else:
                logger.error("Failed to stop recording")
                self.recording_errors += 1
                return False
        except Exception as e:
            logger.error(f"Exception in stop_recording: {e}", exc_info=True)
            return False

    def recording_worker(self):
        """Background thread for managing recordings based on bookings."""
        last_booking_id = None
        
        while not self.stop_event.is_set():
            try:
                booking = load_booking()
                now = datetime.now().astimezone()
                
                if booking:
                    # Parse booking times with local timezone
                    local_tz = now.tzinfo
                    booking_date = datetime.strptime(booking["date"], "%Y-%m-%d").date()
                    start_time = datetime.strptime(booking["start_time"], "%H:%M").time()
                    end_time = datetime.strptime(booking["end_time"], "%H:%M").time()
                    
                    # Combine date and time with local timezone
                    start_datetime = datetime.combine(booking_date, start_time).astimezone(local_tz)
                    end_datetime = datetime.combine(booking_date, end_time).astimezone(local_tz)
                    
                    time_until_start = (start_datetime - now).total_seconds()
                    time_since_end = (now - end_datetime).total_seconds()
                    
                    # Start recording if within 10 seconds of start time
                    if time_until_start <= 10 and time_since_end < 0:
                        if not self.camera_service.is_recording:
                            logger.info(f"Starting recording for booking {booking['id']}")
                            self.start_recording(booking["id"])
                            last_booking_id = booking["id"]
                    
                    # Stop recording if past end time
                    elif time_since_end >= 0 and self.camera_service.is_recording:
                        logger.info(f"Stopping recording for booking {booking['id']}")
                        self.stop_recording()
                        last_booking_id = None
                
                # Stop recording if no booking found
                elif self.camera_service.is_recording:
                    logger.info("No booking found but still recording, stopping")
                    self.stop_recording()
                    last_booking_id = None
                
                if self.stop_event.wait(5):  # Check every 5 seconds
                    break
                
            except Exception as e:
                logger.error(f"Error in recording worker: {e}", exc_info=True)
                self.recording_errors += 1
                if self.stop_event.wait(5):
                    break

    def status_worker(self):
        """Background thread for updating system status."""
        while not self.stop_event.is_set():
            try:
                update_system_status(
                    is_recording=self.camera_service.is_recording,
                    is_streaming=True,
                    storage_used=get_storage_used(),
                    recording_errors=self.recording_errors
                )
                # Use wait() instead of sleep() for graceful shutdown
                if self.stop_event.wait(STATUS_UPDATE_INTERVAL):
                    break
            except Exception as e:
                logger.error(f"Error in status worker: {e}", exc_info=True)
                if self.stop_event.wait(30): # Wait longer on error
                    break

    def scheduler_worker(self):
        """Background thread for checking upcoming bookings."""
        last_booking_id = None
        
        while not self.stop_event.is_set():
            try:
                booking = get_next_booking()
                
                if booking and booking["id"] != last_booking_id:
                    logger.info(f"New booking found: {booking}")
                    if self._save_booking(booking):
                        last_booking_id = booking["id"]
                    else:
                        logger.error("Failed to save booking information")
                
                # Use wait() instead of sleep() for graceful shutdown
                if self.stop_event.wait(BOOKING_CHECK_INTERVAL):
                    break
                
            except Exception as e:
                logger.error(f"Error in scheduler worker: {e}", exc_info=True)
                if self.stop_event.wait(30): # Wait longer on error
                    break

    def _save_booking(self, booking: Dict[str, Any]) -> bool:
        """Save booking information to local storage."""
        try:
            logger.info(f"Saving booking: {booking}")
            os.makedirs(TEMP_DIR, exist_ok=True)
            filepath = os.path.join(TEMP_DIR, "current_booking.json")
            
            with open(filepath, "w") as f:
                import json
                json.dump(booking, f)
                
            logger.info(f"Booking saved: {booking['id']}")
            return True
            
        except Exception as e:
            logger.error(f"Error saving booking: {e}", exc_info=True)
            return False

    def start(self) -> bool:
        """Start the orchestrator service."""
        if self.is_running:
            logger.warning("Orchestrator is already running")
            return True
            
        try:
            # Start camera service
            if not self.camera_service.start():
                logger.error("Failed to start camera service")
                return False

            # Start background threads
            self.recording_thread = threading.Thread(target=self.recording_worker)
            self.recording_thread.daemon = True
            self.recording_thread.start()

            self.status_thread = threading.Thread(target=self.status_worker)
            self.status_thread.daemon = True
            self.status_thread.start()

            self.scheduler_thread = threading.Thread(target=self.scheduler_worker)
            self.scheduler_thread.daemon = True
            self.scheduler_thread.start()

            self.is_running = True
            
            # Initial status update
            update_system_status(is_streaming=True)
            
            logger.info("EZREC Orchestrator service started successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to start orchestrator: {e}", exc_info=True)
            return False

    def stop(self):
        """Stop the orchestrator service."""
        if not self.is_running:
            return
            
        logger.info("Stopping EZREC Orchestrator...")
        self.stop_event.set()
        
        # Stop recording if active
        if self.camera_service.is_recording:
            self.stop_recording()

        # Wait for threads to finish
        if self.recording_thread:
            self.recording_thread.join(timeout=10)
        if self.status_thread:
            self.status_thread.join(timeout=10)
        if self.scheduler_thread:
            self.scheduler_thread.join(timeout=10)

        # Stop camera service
        self.camera_service.stop()
        
        # Final status update
        update_system_status(is_streaming=False)
        
        self.is_running = False
        logger.info("EZREC Orchestrator stopped")

    def get_status(self) -> Dict[str, Any]:
        """Get current system status."""
        return {
            "is_running": self.is_running,
            "is_recording": self.camera_service.is_recording,
            "current_booking_id": self.current_booking_id,
            "camera_status": "active" if self.camera_service.camera else "inactive",
            "ip_address": get_ip(),
            "storage_used": get_storage_used()
        }

def main():
    """Main entry point for the EZREC Backend service."""
    # Setup logging
    os.makedirs(LOG_DIR, exist_ok=True)
    
    # Configure logging with rotation
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            RotatingFileHandler(
                os.path.join(LOG_DIR, 'ezrec-orchestrator.log'),
                maxBytes=10*1024*1024,  # 10MB
                backupCount=5
            ),
            logging.StreamHandler()
        ]
    )
    
    logger.info("Starting EZREC Backend Orchestrator...")
    
    # Create and start orchestrator
    orchestrator = EZRECOrchestrator()
    
    if not orchestrator.start():
        logger.error("Failed to start orchestrator")
        sys.exit(1)

    try:
        # Keep the main thread alive
        while orchestrator.is_running:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt")
    finally:
        orchestrator.stop()
        logger.info("EZREC Backend Orchestrator shutdown complete")

if __name__ == "__main__":
    main() 