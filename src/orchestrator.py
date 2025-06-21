#!/usr/bin/env python3
"""
EZREC Backend - Clean Orchestrator Service (Pi-optimized)
This script is intended to be run via systemd on Raspberry Pi OS (Debian).
All paths and logging are set via config.py and default to /opt/ezrec-backend.
"""

import os
import sys
import time
import threading
import signal
from datetime import datetime
import logging
from logging.handlers import RotatingFileHandler

# Add the src directory to the Python path so we can import our modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    BOOKING_CHECK_INTERVAL, STATUS_UPDATE_INTERVAL, LOG_DIR
)
from utils import (
    logger, load_booking, update_system_status, get_next_booking, save_booking
)
from camera import CameraService

class EZRECOrchestrator:
    """
    Main orchestrator class that coordinates all EZREC backend services.
    """
    
    def __init__(self):
        self.camera_service = CameraService()
        self.stop_event = threading.Event()
        self.recording_thread = None
        self.status_thread = None
        self.scheduler_thread = None
        self.current_booking_id = None
        self.is_running = False
        
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
        logger.info("EZREC Orchestrator initialized")

    def _signal_handler(self, signum, frame):
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.stop()
        sys.exit(0)

    def recording_worker(self):
        """Background thread for managing recordings based on bookings."""
        while not self.stop_event.is_set():
            try:
                booking = load_booking()
                if not booking:
                    if self.camera_service.is_recording:
                        logger.warning("No active booking found, but recording is on. Stopping now.")
                        self.camera_service.stop_recording()
                    self.stop_event.wait(5)
                    continue

                now = datetime.now().astimezone()
                start_time = datetime.fromisoformat(booking["start_time"])
                end_time = datetime.fromisoformat(booking["end_time"])

                # Check if we are within the booking window
                if start_time <= now < end_time:
                    if not self.camera_service.is_recording:
                        logger.info(f"Inside booking window for {booking['id']}. Starting recording.")
                        self.camera_service.start_recording(booking)
                
                # Check if the booking has ended
                elif now >= end_time:
                    if self.camera_service.is_recording:
                        logger.info(f"Booking {booking['id']} has ended. Stopping recording.")
                        self.camera_service.stop_recording()

                self.stop_event.wait(1) # Check every second for precision
            except Exception as e:
                logger.error(f"Error in recording worker: {e}", exc_info=True)
                if self.stop_event.wait(5):
                    break

    def status_worker(self):
        """Background thread for updating system status."""
        while not self.stop_event.is_set():
            try:
                update_system_status(is_recording=self.camera_service.is_recording)
                if self.stop_event.wait(STATUS_UPDATE_INTERVAL):
                    break
            except Exception as e:
                logger.error(f"Error in status worker: {e}", exc_info=True)
                if self.stop_event.wait(30):
                    break

    def scheduler_worker(self):
        """Background thread for checking for the next booking from Supabase."""
        while not self.stop_event.is_set():
            try:
                # Only check for a new booking if one isn't already active
                if not load_booking():
                    booking = get_next_booking()
                    if booking:
                        logger.info(f"Found next booking: {booking['id']}. Saving locally.")
                        save_booking(booking)
                
                if self.stop_event.wait(BOOKING_CHECK_INTERVAL):
                    break
            except Exception as e:
                logger.error(f"Error in scheduler worker: {e}", exc_info=True)
                if self.stop_event.wait(60):
                    break
    
    def start(self):
        if self.is_running:
            logger.warning("Orchestrator is already running.")
            return True
            
        try:
            if not self.camera_service.start():
                logger.error("Failed to start camera service. Aborting.")
                return False

            self.is_running = True
            
            self.scheduler_thread = threading.Thread(target=self.scheduler_worker, daemon=True)
            self.scheduler_thread.start()
            
            self.recording_thread = threading.Thread(target=self.recording_worker, daemon=True)
            self.recording_thread.start()

            self.status_thread = threading.Thread(target=self.status_worker, daemon=True)
            self.status_thread.start()

            update_system_status(is_streaming=True)
            logger.info("EZREC Orchestrator service started successfully.")
            return True
        except Exception as e:
            logger.error(f"Failed to start orchestrator: {e}", exc_info=True)
            self.is_running = False
            return False

    def stop(self):
        if not self.is_running:
            return
            
        logger.info("Stopping EZREC Orchestrator...")
        self.stop_event.set()
        
        if self.camera_service.is_recording:
            self.camera_service.stop_recording()

        if self.scheduler_thread: self.scheduler_thread.join(timeout=5)
        if self.recording_thread: self.recording_thread.join(timeout=5)
        if self.status_thread: self.status_thread.join(timeout=5)

        self.camera_service.stop()
        
        update_system_status(is_streaming=False)
        self.is_running = False
        logger.info("EZREC Orchestrator stopped.")

def main():
    time.sleep(2)
    os.makedirs(LOG_DIR, exist_ok=True)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            RotatingFileHandler(
                os.path.join(LOG_DIR, 'ezrec-orchestrator.log'),
                maxBytes=10*1024*1024,
                backupCount=5
            ),
            logging.StreamHandler()
        ]
    )
    
    logger.info("Starting EZREC Backend Orchestrator...")
    orchestrator = EZRECOrchestrator()
    
    if not orchestrator.start():
        logger.error("Failed to start orchestrator. Shutting down.")
        sys.exit(1)

    try:
        while orchestrator.is_running:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received.")
    finally:
        orchestrator.stop()
        logger.info("EZREC Backend Orchestrator shutdown complete.")

if __name__ == "__main__":
    main() 