#!/usr/bin/env python3
import time
import threading
from datetime import datetime
from typing import Optional

from .utils import (
    logger,
    load_booking,
    remove_booking,
    update_system_status,
    remove_booking_from_supabase,
    get_upload_queue
)
from .config import BOOKING_CHECK_INTERVAL
from .camera import CameraService

class Orchestrator:
    def __init__(self):
        self.camera_service = CameraService()
        self.stop_event = threading.Event()
        self.recording_thread = None
        self.current_booking_id = None

    def start_recording(self, booking_id: str) -> bool:
        """Start recording for a specific booking."""
        try:
            logger.info(f"Attempting to start recording for booking {booking_id}")
            booking = load_booking()
            if not booking or booking["id"] != booking_id:
                logger.error(f"Invalid booking ID: {booking_id}")
                return False

            if not self.camera_service.start_recording(booking_id=booking_id):
                logger.error("Failed to start recording")
                return False

            self.current_booking_id = booking_id
            logger.info(f"Started recording for booking {booking_id}")
            return True

        except Exception as e:
            logger.error(f"Error starting recording: {e}", exc_info=True)
            return False

    def stop_recording(self) -> bool:
        """Stop the current recording."""
        try:
            logger.info("Attempting to stop recording")
            if self.camera_service.stop_recording():
                logger.info("Recording stopped successfully")
                logger.info(f"Upload queue after stop_recording: {self.camera_service.upload_queue}")
                # Do not remove booking here; let upload worker handle it after successful upload
                return True
            else:
                logger.error("Failed to stop recording")
                return False
        except Exception as e:
            logger.error(f"Exception in stop_recording: {e}", exc_info=True)
            return False

    def manual_trigger_upload_worker(self):
        logger.info("[Orchestrator] Manual trigger for upload worker.")
        self.camera_service.manual_trigger_upload_queue()

    def recording_worker(self):
        """Background thread for managing recordings."""
        last_booking_id = None
        while not self.stop_event.is_set():
            try:
                booking = load_booking()
                # Use local time
                now = datetime.now().astimezone()
                if booking:
                    # Parse the time correctly with local timezone
                    local_tz = now.tzinfo
                    booking_date = datetime.strptime(booking["date"], "%Y-%m-%d").date()
                    start_time = datetime.strptime(booking["start_time"], "%H:%M").time()
                    end_time = datetime.strptime(booking["end_time"], "%H:%M").time()
                    
                    # Combine date and time with local timezone
                    start_datetime = datetime.combine(booking_date, start_time).astimezone(local_tz)
                    end_datetime = datetime.combine(booking_date, end_time).astimezone(local_tz)
                    
                    logger.info(f"[Time Check] Current: {now.strftime('%Y-%m-%d %H:%M:%S %Z')}")
                    logger.info(f"[Time Check] Start: {start_datetime.strftime('%Y-%m-%d %H:%M:%S %Z')}")
                    logger.info(f"[Time Check] End: {end_datetime.strftime('%Y-%m-%d %H:%M:%S %Z')}")
                    
                    time_until_start = (start_datetime - now).total_seconds()
                    time_since_end = (now - end_datetime).total_seconds()
                    
                    logger.info(f"[Time Check] Seconds until start: {time_until_start}")
                    logger.info(f"[Time Check] Seconds since end: {time_since_end}")
                    
                    # Only start if we're within 10 seconds of start time or already in the booking window
                    if time_until_start <= 10 and time_since_end < 0:
                        if not self.camera_service.is_recording:
                            logger.info(f"Starting recording for booking {booking['id']} (start in {time_until_start} seconds)")
                            self.start_recording(booking["id"])
                            last_booking_id = booking["id"]
                    elif time_since_end >= 0 and self.camera_service.is_recording:
                        logger.info(f"Stopping recording for booking {booking['id']} as end time reached ({time_since_end} seconds ago)")
                        self.stop_recording()
                        last_booking_id = None
                elif self.camera_service.is_recording:
                    logger.info("No booking found but still recording, stopping recording")
                    self.stop_recording()
                    last_booking_id = None
                time.sleep(5)
            except Exception as e:
                logger.error(f"Error in recording worker: {e}", exc_info=True)
                time.sleep(5)

    def start(self):
        """Start the orchestrator service."""
        if not self.camera_service.start():
            logger.error("Failed to start camera service")
            return False

        self.recording_thread = threading.Thread(target=self.recording_worker)
        self.recording_thread.daemon = True
        self.recording_thread.start()

        # Update system status
        update_system_status(is_streaming=True)
        
        logger.info("Orchestrator service started")
        return True

    def stop(self):
        """Stop the orchestrator service."""
        self.stop_event.set()
        if self.recording_thread:
            self.recording_thread.join()

        if self.camera_service.is_recording:
            self.stop_recording()

        self.camera_service.stop()
        
        # Update system status
        update_system_status(is_streaming=False)
        
        logger.info("Orchestrator service stopped")

def main():
    """Main orchestrator service loop."""
    orchestrator = Orchestrator()
    if not orchestrator.start():
        return

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Received shutdown signal")
    finally:
        orchestrator.stop()

if __name__ == "__main__":
    main() 