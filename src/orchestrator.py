#!/usr/bin/env python3
"""
EZREC Backend Orchestrator - Optimized for Raspberry Pi
Main service that coordinates all EZREC backend components with enhanced
error handling, logging, health monitoring, and graceful shutdown.
"""

import os
import sys
import time
import threading
import signal
import json
from datetime import datetime
import logging
from logging.handlers import RotatingFileHandler
from typing import Optional, Dict, Any
import traceback

# Add the src directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import (
    BOOKING_CHECK_INTERVAL, STATUS_UPDATE_INTERVAL, LOG_DIR, 
    LOG_MAX_BYTES, LOG_BACKUP_COUNT, LOG_LEVEL, CONFIG_SUMMARY,
    DEBUG, HEARTBEAT_INTERVAL
)
from utils import (
    logger, load_booking, update_system_status, get_next_booking, 
    save_booking, setup_logging
)
from camera import CameraService

class EZRECOrchestrator:
    """
    Enhanced orchestrator class that coordinates all EZREC backend services
    with robust error handling, health monitoring, and graceful shutdown.
    """
    
    def __init__(self):
        self.camera_service = None
        self.stop_event = threading.Event()
        self.threads = {}
        self.current_booking_id = None
        self.is_running = False
        self.start_time = time.time()
        self.health_status = {"healthy": True, "last_check": time.time()}
        self.error_count = 0
        self.max_errors = 50  # Max errors before shutdown
        
        # Setup enhanced logging
        self._setup_logging()
        
        # Setup signal handlers for graceful shutdown
        self._setup_signal_handlers()
        
        # Log startup information
        self.logger.info("="*60)
        self.logger.info("EZREC Orchestrator Starting Up")
        self.logger.info("="*60)
        self.logger.info(f"Configuration: {CONFIG_SUMMARY}")
        self.logger.info(f"Process ID: {os.getpid()}")
        self.logger.info(f"Working Directory: {os.getcwd()}")

    def _setup_logging(self):
        """Setup enhanced logging with rotation and proper formatting."""
        self.logger = logging.getLogger(f"{__name__}.EZRECOrchestrator")
        
        # Don't add handlers if already configured
        if not self.logger.handlers:
            # File handler with rotation
            log_file = os.path.join(LOG_DIR, 'ezrec-orchestrator.log')
            file_handler = RotatingFileHandler(
                log_file,
                maxBytes=LOG_MAX_BYTES,
                backupCount=LOG_BACKUP_COUNT
            )
            
            # Console handler
            console_handler = logging.StreamHandler()
            
            # Formatter
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            file_handler.setFormatter(formatter)
            console_handler.setFormatter(formatter)
            
            self.logger.addHandler(file_handler)
            self.logger.addHandler(console_handler)
            self.logger.setLevel(getattr(logging, LOG_LEVEL.upper()))

    def _setup_signal_handlers(self):
        """Setup signal handlers for graceful shutdown."""
        def signal_handler(signum, frame):
            signal_name = signal.Signals(signum).name
            self.logger.info(f"Received signal {signal_name} ({signum}), initiating graceful shutdown...")
            self.stop()
            
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        # Handle SIGUSR1 for status dump (useful for debugging)
        def status_handler(signum, frame):
            self.logger.info("Status dump requested via SIGUSR1")
            self._dump_status()
            
        signal.signal(signal.SIGUSR1, status_handler)

    def _dump_status(self):
        """Dump current status for debugging."""
        status = {
            "uptime": time.time() - self.start_time,
            "is_running": self.is_running,
            "error_count": self.error_count,
            "health_status": self.health_status,
            "active_threads": [name for name, thread in self.threads.items() if thread.is_alive()],
            "current_booking": self.current_booking_id,
            "camera_status": self.camera_service.is_recording if self.camera_service else None,
        }
        self.logger.info(f"Status Dump: {json.dumps(status, indent=2)}")

    def _handle_error(self, error_msg: str, exception: Exception = None):
        """Centralized error handling with counting and logging."""
        self.error_count += 1
        
        if exception:
            self.logger.error(f"{error_msg}: {exception}", exc_info=True)
        else:
            self.logger.error(error_msg)
        
        # Check if we've exceeded error threshold
        if self.error_count >= self.max_errors:
            self.logger.critical(f"Error threshold exceeded ({self.max_errors}), shutting down")
            self.stop()
            sys.exit(1)

    def recording_worker(self):
        """Enhanced recording worker with better error handling and logging."""
        self.logger.info("Recording worker thread started")
        consecutive_failures = 0
        max_consecutive_failures = 5
        
        while not self.stop_event.is_set():
            try:
                booking = load_booking()
                
                if not booking:
                    if self.camera_service and self.camera_service.is_recording:
                        self.logger.warning("No active booking found, but recording is active. Stopping recording.")
                        self.camera_service.stop_recording()
                    
                    # Reset failure counter when no booking
                    consecutive_failures = 0
                    if self.stop_event.wait(5):
                        break
                    continue

                now = datetime.now().astimezone()
                
                # Parse booking date and time (format: date="2025-06-25", start_time="00:30")
                booking_date = booking["date"]
                booking_start = booking["start_time"] 
                booking_end = booking["end_time"]
                
                # Combine date and time to create full datetime objects
                start_time = datetime.strptime(f"{booking_date} {booking_start}", "%Y-%m-%d %H:%M").replace(tzinfo=now.tzinfo)
                end_time = datetime.strptime(f"{booking_date} {booking_end}", "%Y-%m-%d %H:%M").replace(tzinfo=now.tzinfo)

                # Check if we're within the booking window
                if start_time <= now < end_time:
                    if not self.camera_service.is_recording:
                        self.logger.info(f"Starting recording for booking {booking['id']} ({start_time} - {end_time})")
                        try:
                            success = self.camera_service.start_recording(booking)
                            if success:
                                self.current_booking_id = booking['id']
                                consecutive_failures = 0  # Reset failure counter on success
                            else:
                                consecutive_failures += 1
                                self.logger.error(f"Failed to start recording for booking {booking['id']} (attempt {consecutive_failures})")
                                
                                # If we've failed too many times, wait longer before retrying
                                if consecutive_failures >= max_consecutive_failures:
                                    self.logger.warning(f"Too many consecutive recording failures ({consecutive_failures}). Waiting 30 seconds before retry.")
                                    if self.stop_event.wait(30):
                                        break
                                    continue
                                    
                        except Exception as e:
                            consecutive_failures += 1
                            self._handle_error(f"Error starting recording for booking {booking['id']}", e)
                            
                            # Implement exponential backoff for failures
                            backoff_time = min(30, 2 ** min(consecutive_failures, 5))
                            self.logger.warning(f"Recording failed {consecutive_failures} times. Waiting {backoff_time}s before retry.")
                            if self.stop_event.wait(backoff_time):
                                break
                            continue
                
                # Check if the booking has ended
                elif now >= end_time:
                    if self.camera_service and self.camera_service.is_recording:
                        self.logger.info(f"Booking {booking['id']} has ended. Stopping recording.")
                        try:
                            self.camera_service.stop_recording()
                            self.current_booking_id = None
                            consecutive_failures = 0  # Reset counter after successful completion
                        except Exception as e:
                            self._handle_error(f"Error stopping recording for booking {booking['id']}", e)
                    
                    # Complete the booking (remove locally + update database)
                    try:
                        from utils import complete_booking
                        success = complete_booking(booking['id'])
                        if success:
                            self.logger.info(f"Completed booking {booking['id']} (local + database)")
                        else:
                            self.logger.warning(f"Failed to complete booking {booking['id']}")
                    except Exception as e:
                        self.logger.error(f"Error completing booking {booking['id']}: {e}")
                        # Fallback to local removal only
                        try:
                            from utils import remove_booking
                            remove_booking()
                            self.logger.info(f"Fallback: Removed local booking file for {booking['id']}")
                        except Exception as fallback_e:
                            self.logger.error(f"Fallback removal also failed: {fallback_e}")

                # Sleep for 1 second for precision, but check stop event
                if self.stop_event.wait(1):
                    break
                    
            except Exception as e:
                self._handle_error("Error in recording worker", e)
                if self.stop_event.wait(10):  # Wait longer on error
                    break

        self.logger.info("Recording worker thread stopped")

    def status_worker(self):
        """Enhanced status worker with health monitoring."""
        self.logger.info("Status worker thread started")
        
        while not self.stop_event.is_set():
            try:
                # Update system status
                is_recording = self.camera_service.is_recording if self.camera_service else False
                success = update_system_status(
                    is_recording=is_recording,
                    is_streaming=self.is_running,
                    recording_errors=self.error_count
                )
                
                if not success:
                    self.logger.warning("Failed to update system status")
                
                # Update health status
                self.health_status = {
                    "healthy": self._perform_health_check(),
                    "last_check": time.time(),
                    "uptime": time.time() - self.start_time,
                    "error_count": self.error_count
                }
                
                if self.stop_event.wait(STATUS_UPDATE_INTERVAL):
                    break
                    
            except Exception as e:
                self._handle_error("Error in status worker", e)
                if self.stop_event.wait(30):  # Wait longer on error
                    break

        self.logger.info("Status worker thread stopped")

    def scheduler_worker(self):
        """Enhanced scheduler worker with better booking management."""
        self.logger.info("Scheduler worker thread started")
        
        while not self.stop_event.is_set():
            try:
                # Only check for new booking if one isn't already active
                current_booking = load_booking()
                
                if not current_booking:
                    self.logger.debug("No current booking, checking for next booking")
                    next_booking = get_next_booking()
                    
                    if next_booking:
                        self.logger.info(f"Found next booking: {next_booking['id']} "
                                       f"({next_booking.get('start_time', 'N/A')} - {next_booking.get('end_time', 'N/A')})")
                        success = save_booking(next_booking)
                        if not success:
                            self.logger.error(f"Failed to save booking {next_booking['id']}")
                    else:
                        self.logger.debug("No upcoming bookings found")
                
                if self.stop_event.wait(BOOKING_CHECK_INTERVAL):
                    break
                    
            except Exception as e:
                self._handle_error("Error in scheduler worker", e)
                if self.stop_event.wait(60):  # Wait longer on error
                    break

        self.logger.info("Scheduler worker thread stopped")

    def heartbeat_worker(self):
        """Heartbeat worker for monitoring service health."""
        self.logger.info("Heartbeat worker thread started")
        
        while not self.stop_event.is_set():
            try:
                # Log heartbeat with key metrics
                uptime = time.time() - self.start_time
                active_threads = sum(1 for t in self.threads.values() if t.is_alive())
                
                self.logger.debug(f"Heartbeat - Uptime: {uptime:.1f}s, "
                                f"Threads: {active_threads}, "
                                f"Errors: {self.error_count}, "
                                f"Recording: {self.camera_service.is_recording if self.camera_service else False}")
                
                if self.stop_event.wait(HEARTBEAT_INTERVAL):
                    break
                    
            except Exception as e:
                self._handle_error("Error in heartbeat worker", e)
                if self.stop_event.wait(HEARTBEAT_INTERVAL):
                    break

        self.logger.info("Heartbeat worker thread stopped")

    def _perform_health_check(self) -> bool:
        """Perform comprehensive health check."""
        try:
            # Check if all threads are alive
            dead_threads = [name for name, thread in self.threads.items() if not thread.is_alive()]
            if dead_threads:
                self.logger.warning(f"Dead threads detected: {dead_threads}")
                return False
            
            # Check camera service health
            if self.camera_service:
                try:
                    camera_healthy = self.camera_service.camera.health_check() if hasattr(self.camera_service, 'camera') else True
                    if not camera_healthy:
                        self.logger.warning("Camera health check failed")
                        return False
                except Exception as e:
                    self.logger.warning(f"Camera health check error: {e}")
                    return False
            
            # Check error rate
            if self.error_count > self.max_errors * 0.8:  # 80% of max errors
                self.logger.warning(f"High error count: {self.error_count}")
                return False
            
            return True
            
        except Exception as e:
            self.logger.error(f"Health check failed: {e}")
            return False

    def start(self) -> bool:
        """Start orchestrator with enhanced initialization and error handling."""
        if self.is_running:
            self.logger.warning("Orchestrator is already running")
            return True
            
        try:
            self.logger.info("Starting EZREC Orchestrator...")
            
            # Initialize camera service
            self.logger.info("Initializing camera service...")
            self.camera_service = CameraService()
            
            if not self.camera_service.start_camera():
                self.logger.error("Failed to start camera service")
                return False
            
            self.logger.info("Camera service started successfully")
            
            # Start worker threads
            self.logger.info("Starting worker threads...")
            
            thread_configs = [
                ("scheduler", self.scheduler_worker),
                ("recording", self.recording_worker),
                ("status", self.status_worker),
                ("heartbeat", self.heartbeat_worker),
            ]
            
            for name, target in thread_configs:
                thread = threading.Thread(target=target, name=f"EZREC-{name}", daemon=True)
                thread.start()
                self.threads[name] = thread
                self.logger.info(f"Started {name} worker thread")
            
            # Mark as running
            self.is_running = True
            
            # Update system status to indicate streaming
            update_system_status(is_streaming=True)
            
            self.logger.info("EZREC Orchestrator started successfully")
            self.logger.info(f"Active threads: {list(self.threads.keys())}")
            
            return True
            
        except Exception as e:
            self._handle_error("Failed to start orchestrator", e)
            self.is_running = False
            return False

    def stop(self):
        """Enhanced graceful shutdown with proper cleanup."""
        if not self.is_running:
            self.logger.info("Orchestrator is not running")
            return
            
        self.logger.info("Stopping EZREC Orchestrator...")
        
        try:
            # Set stop event to signal all threads to stop
            self.stop_event.set()
            
            # Stop camera recording if active
            if self.camera_service and self.camera_service.is_recording:
                self.logger.info("Stopping active recording...")
                try:
                    self.camera_service.stop_recording()
                except Exception as e:
                    self.logger.error(f"Error stopping recording: {e}")
            
            # Wait for all threads to finish
            self.logger.info("Waiting for threads to stop...")
            for name, thread in self.threads.items():
                if thread.is_alive():
                    self.logger.info(f"Waiting for {name} thread to stop...")
                    thread.join(timeout=10)
                    if thread.is_alive():
                        self.logger.warning(f"{name} thread did not stop gracefully")
                    else:
                        self.logger.info(f"{name} thread stopped")
            
            # Stop camera service
            if self.camera_service:
                self.logger.info("Stopping camera service...")
                try:
                    self.camera_service.stop()
                except Exception as e:
                    self.logger.error(f"Error stopping camera service: {e}")
            
            # Update system status
            try:
                update_system_status(is_streaming=False, is_recording=False)
            except Exception as e:
                self.logger.error(f"Error updating final system status: {e}")
            
            # Mark as not running
            self.is_running = False
            
            # Log shutdown stats
            uptime = time.time() - self.start_time
            self.logger.info(f"EZREC Orchestrator stopped gracefully")
            self.logger.info(f"Session stats - Uptime: {uptime:.1f}s, Errors: {self.error_count}")
            
        except Exception as e:
            self.logger.error(f"Error during shutdown: {e}", exc_info=True)

    def get_status(self) -> Dict[str, Any]:
        """Get current orchestrator status."""
        return {
            "running": self.is_running,
            "uptime": time.time() - self.start_time,
            "error_count": self.error_count,
            "health_status": self.health_status,
            "current_booking": self.current_booking_id,
            "threads": {name: thread.is_alive() for name, thread in self.threads.items()},
            "camera_recording": self.camera_service.is_recording if self.camera_service else False,
        }

def main():
    """Main function with enhanced startup and monitoring."""
    # Ensure log directory exists
    os.makedirs(LOG_DIR, exist_ok=True)
    
    # Wait a moment for system to stabilize
    time.sleep(2)
    
    # Setup global logging
    setup_logging()
    
    logger.info("="*60)
    logger.info("EZREC Backend Orchestrator Starting")
    logger.info("="*60)
    logger.info(f"Python: {sys.version}")
    logger.info(f"Platform: {sys.platform}")
    logger.info(f"Debug Mode: {DEBUG}")
    
    # Create and start orchestrator
    orchestrator = EZRECOrchestrator()
    
    if not orchestrator.start():
        logger.error("Failed to start orchestrator. Shutting down.")
        sys.exit(1)

    try:
        # Main loop - keep service running
        logger.info("Orchestrator running. Press Ctrl+C to stop.")
        
        while orchestrator.is_running:
            time.sleep(1)
            
            # Periodically log status if in debug mode
            if DEBUG:
                status = orchestrator.get_status()
                if int(status["uptime"]) % 300 == 0:  # Every 5 minutes
                    logger.debug(f"Status: {status}")
                    
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    except Exception as e:
        logger.error(f"Unexpected error in main loop: {e}", exc_info=True)
    finally:
        orchestrator.stop()
        logger.info("EZREC Backend Orchestrator shutdown complete")

if __name__ == "__main__":
    main() 