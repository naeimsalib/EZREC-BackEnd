# This to fi
# transition between intro video and recordings is not working

import os
import cv2
import numpy as np
import time
import datetime
import subprocess
from supabase import create_client, Client
from dotenv import load_dotenv
import threading
import queue
import json
from enum import Enum
import shutil
import socket
import signal
import sys
import queue as pyqueue
import multiprocessing
from concurrent.futures import ThreadPoolExecutor
import logging
from logging.handlers import RotatingFileHandler
from src.config import (
    CAMERA_DEVICE, PREVIEW_WIDTH, PREVIEW_HEIGHT, RECORD_WIDTH, RECORD_HEIGHT, PREVIEW_FPS, RECORD_FPS, HARDWARE_ENCODER
)
from src.camera_interface import CameraInterface
from src.utils import send_heartbeat, start_heartbeat_thread, stop_heartbeat_thread

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        RotatingFileHandler('camera.log', maxBytes=1024*1024, backupCount=3),
        logging.StreamHandler()
    ]
)

class LogLevel(Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    SUCCESS = "SUCCESS"

def log(message, level=LogLevel.INFO):
    if level == LogLevel.INFO:
        logging.info(message)
    elif level == LogLevel.WARNING:
        logging.warning(message)
    elif level == LogLevel.ERROR:
        logging.error(message)
    elif level == LogLevel.SUCCESS:
        logging.info(f"SUCCESS: {message}")

# Constants for video processing
MAX_WORKERS = 2  # Limit concurrent processes
BOOKING_GRACE_PERIOD = 120  # 2 minutes in seconds

# Global variables
load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
USER_ID = os.getenv("USER_ID")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
upload_queue = queue.Queue()
shutting_down = False

# Cache for logos and settings
logo_cache = {}
settings_cache = None
last_settings_update = 0
SETTINGS_CACHE_DURATION = 3600  # 1 hour

def get_user_settings():
    global settings_cache, last_settings_update
    current_time = time.time()
    
    if settings_cache is None or (current_time - last_settings_update) > SETTINGS_CACHE_DURATION:
        try:
            response = supabase.table("user_settings").select("*").eq("user_id", USER_ID).single().execute()
            settings_cache = response.data if response.data else {}
            last_settings_update = current_time
        except Exception as e:
            log(f"Failed to fetch settings: {str(e)}", LogLevel.ERROR)
            return settings_cache or {}
    
    return settings_cache

def overlay_logo(frame, logo_path, position):
    global logo_cache
    
    if position not in logo_cache:
        if not os.path.exists(logo_path):
            return frame
            
        logo = cv2.imread(logo_path, cv2.IMREAD_UNCHANGED)
        if logo is None:
            return frame
            
        h_frame, w_frame = frame.shape[:2]
        fixed_logo_width = min(int(w_frame * 0.15), 180)
        scale_factor = fixed_logo_width / logo.shape[1]
        logo = cv2.resize(logo, (0, 0), fx=scale_factor, fy=scale_factor, interpolation=cv2.INTER_AREA)
        logo_cache[position] = logo
    else:
        logo = logo_cache[position]

    h_logo, w_logo = logo.shape[:2]
    h_frame, w_frame = frame.shape[:2]
    x, y = {
        "top-left": (10, 10),
        "top-right": (w_frame - w_logo - 10, 10),
        "bottom-left": (10, h_frame - h_logo - 10),
        "bottom-right": (w_frame - w_logo - 10, h_frame - h_logo - 10),
    }.get(position, (10, 10))

    if x < 0 or y < 0 or x + w_logo > w_frame or y + h_logo > h_frame:
        return frame

    overlay = frame.copy()
    if logo.shape[2] == 4:
        alpha = logo[:, :, 3] / 255.0
        for c in range(3):
            overlay[y:y+h_logo, x:x+w_logo, c] = (
                alpha * logo[:, :, c] + (1 - alpha) * overlay[y:y+h_logo, x:x+w_logo, c]
            )
    else:
        overlay[y:y+h_logo, x:x+w_logo] = logo
    return overlay

def add_timestamp_overlay(frame, timestamp_str):
    """Add timestamp overlay to the frame."""
    h_frame, w_frame = frame.shape[:2]
    
    # Choose font and scale based on frame size
    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = max(0.8, min(2.0, w_frame / 1000))  # Scale font based on frame width
    thickness = max(1, int(font_scale * 2))
    
    # Get text size
    (text_width, text_height), baseline = cv2.getTextSize(timestamp_str, font, font_scale, thickness)
    
    # Position timestamp in top-left corner with padding
    x = 20
    y = text_height + 20
    
    # Add background rectangle for better readability
    padding = 10
    cv2.rectangle(frame, 
                  (x - padding, y - text_height - padding), 
                  (x + text_width + padding, y + baseline + padding), 
                  (0, 0, 0), -1)  # Black background
    
    # Add timestamp text in white
    cv2.putText(frame, timestamp_str, (x, y), font, font_scale, (255, 255, 255), thickness)
    
    return frame

def encode_video_with_fixed_fps(input_path, output_path, target_fps=30):
    """Encode video using hardware acceleration."""
    try:
        cmd = [
            "ffmpeg", "-i", input_path,
            "-filter:v", f"fps={target_fps}",
            "-c:v", HARDWARE_ENCODER,  # Use hardware encoder
            "-preset", "ultrafast",  # Faster encoding
            "-b:v", "2M",  # Bitrate
            "-c:a", "aac",
            "-b:a", "128k",
            "-y", output_path
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            log(f"Error encoding video: {result.stderr}", LogLevel.ERROR)
            return False
        return True
    except Exception as e:
        log(f"Failed to encode video: {str(e)}", LogLevel.ERROR)
        return False

def process_video_with_overlays(input_path, output_path, user_settings, booking_info):
    """Process video to add timestamp and logo overlays."""
    try:
        # Get logo path from user settings
        logo_path = user_settings.get("logo_path", "user_assets/default_logo.png")
        logo_position = user_settings.get("logo_position", "top-right")
        
        # Open input video
        cap = cv2.VideoCapture(input_path)
        if not cap.isOpened():
            log(f"Failed to open input video: {input_path}", LogLevel.ERROR)
            return False
        
        # Get video properties
        fps = int(cap.get(cv2.CAP_PROP_FPS))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        
        # Setup video writer
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
        
        frame_count = 0
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            # Calculate timestamp for this frame
            seconds_elapsed = frame_count / fps
            recording_start = datetime.datetime.fromisoformat(booking_info['start_time'].replace('Z', '+00:00'))
            current_time = recording_start + datetime.timedelta(seconds=seconds_elapsed)
            timestamp_str = current_time.strftime("%Y-%m-%d %H:%M:%S")
            
            # Add timestamp overlay
            frame = add_timestamp_overlay(frame, timestamp_str)
            
            # Add logo overlay
            if os.path.exists(logo_path):
                frame = overlay_logo(frame, logo_path, logo_position)
            
            out.write(frame)
            frame_count += 1
        
        cap.release()
        out.release()
        
        log(f"Successfully processed video with overlays: {output_path}", LogLevel.SUCCESS)
        return True
        
    except Exception as e:
        log(f"Failed to process video with overlays: {str(e)}", LogLevel.ERROR)
        return False

def prepend_intro(intro_path, main_path, output_path):
    """Optimized version using hardware acceleration."""
    temp_dir = "temp_processing"
    try:
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
        os.makedirs(temp_dir, exist_ok=True)
        
        temp_intro = os.path.join(temp_dir, "temp_intro.mp4")
        temp_main = os.path.join(temp_dir, "temp_main.mp4")
        
        # Process intro video with hardware acceleration
        intro_cmd = [
            "ffmpeg", "-i", intro_path,
            "-c:v", HARDWARE_ENCODER,
            "-preset", "ultrafast",
            "-b:v", "2M",
            "-c:a", "aac",
            "-b:a", "128k",
            "-y", temp_intro
        ]
        subprocess.run(intro_cmd, capture_output=True)
        
        # Process main video
        if not encode_video_with_fixed_fps(main_path, temp_main):
            return False
        
        # Create file list for concatenation
        list_file = os.path.join(temp_dir, "list.txt")
        with open(list_file, "w") as f:
            f.write(f"file '{os.path.abspath(temp_intro)}'\n")
            f.write(f"file '{os.path.abspath(temp_main)}'\n")
        
        # Merge videos
        merge_cmd = [
            "ffmpeg",
            "-f", "concat",
            "-safe", "0",
            "-i", list_file,
            "-c:v", HARDWARE_ENCODER,
            "-preset", "ultrafast",
            "-b:v", "2M",
            "-c:a", "aac",
            "-b:a", "128k",
            "-y", output_path
        ]
        subprocess.run(merge_cmd, capture_output=True)
        
        # Cleanup
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir)
        
        return True
    except Exception as e:
        log(f"Failed to prepend intro: {str(e)}", LogLevel.ERROR)
        return False

def detect_moving_circle(frame, prev_frame):
    """Optimized ball detection."""
    if prev_frame is None:
        return None, None
        
    # Convert to grayscale
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
    
    # Calculate absolute difference
    diff = cv2.absdiff(gray, prev_gray)
    
    # Apply threshold
    _, thresh = cv2.threshold(diff, 25, 255, cv2.THRESH_BINARY)
    
    # Find contours
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    if not contours:
        return None, None
        
    # Find the largest contour
    largest_contour = max(contours, key=cv2.contourArea)
    
    # Calculate circularity
    area = cv2.contourArea(largest_contour)
    perimeter = cv2.arcLength(largest_contour, True)
    circularity = 4 * np.pi * area / (perimeter * perimeter) if perimeter > 0 else 0
    
    if circularity > 0.7:  # More circular
        (x, y), radius = cv2.minEnclosingCircle(largest_contour)
        return (int(x), int(y)), int(radius)
    
    return None, None

def create_focused_frame(frame, center, radius, zoom_factor=1.5):
    if center is None or radius is None:
        return frame
    
    height, width = frame.shape[:2]
    
    # Calculate the region of interest with wider view
    roi_size = int(radius * zoom_factor * 3)  # Increased multiplier for wider view
    
    # Ensure ROI size is not too small
    min_roi_size = 400  # Increased minimum size for better gameplay view
    roi_size = max(roi_size, min_roi_size)
    
    # Calculate ROI boundaries with smooth transitions
    x1 = max(0, center[0] - roi_size)
    y1 = max(0, center[1] - roi_size)
    x2 = min(width, center[0] + roi_size)
    y2 = min(height, center[1] + roi_size)
    
    # Ensure ROI has valid dimensions
    if x2 <= x1 or y2 <= y1:
        return frame
    
    # Extract the region of interest
    try:
        roi = frame[y1:y2, x1:x2]
        if roi.size == 0:
            return frame
            
        # Resize the ROI to the original frame size with smooth interpolation
        focused_frame = cv2.resize(roi, (width, height), interpolation=cv2.INTER_LINEAR)
        return focused_frame
    except Exception as e:
        log(f"Error in create_focused_frame: {str(e)}", LogLevel.ERROR)
        return frame

def get_current_active_booking():
    """Get the currently active booking based on current time."""
    now = datetime.datetime.now()
    today = now.strftime("%Y-%m-%d")
    current_time = now.strftime("%H:%M")
    
    try:
        # Get today's bookings
        response = supabase.table("bookings").select("*").eq("user_id", USER_ID).eq("date", today).order("start_time").execute()
        
        if not response.data:
            return None
            
        # Find the booking that is currently active
        for booking in response.data:
            start_time = datetime.datetime.strptime(f"{booking['date']} {booking['start_time']}", "%Y-%m-%d %H:%M")
            end_time = datetime.datetime.strptime(f"{booking['date']} {booking['end_time']}", "%Y-%m-%d %H:%M")
            
            if start_time <= now <= end_time:
                log(f"Found active booking: {booking['id']} ({booking['start_time']}-{booking['end_time']})", LogLevel.INFO)
                return booking
                
        return None
    except Exception as e:
        log(f"Error fetching current booking: {str(e)}", LogLevel.ERROR)
        return None

def remove_finished_booking(booking_id):
    """Remove a finished booking from the database."""
    try:
        supabase.table("bookings").delete().eq("id", booking_id).execute()
        log(f"Removed finished booking {booking_id} from database", LogLevel.SUCCESS)
        return True
    except Exception as e:
        log(f"Error removing finished booking {booking_id}: {str(e)}", LogLevel.ERROR)
        return False

def cleanup_past_bookings():
    """Remove past bookings that have ended with grace period."""
    try:
        today = datetime.date.today().isoformat()
        response = supabase.table("bookings").select("*").eq("user_id", USER_ID).eq("date", today).execute()
        
        if not response.data:
            return
        
        current_datetime = datetime.datetime.now()
        bookings_to_remove = []
        
        for booking in response.data:
            # Parse booking end time
            booking_date = datetime.date.fromisoformat(booking["date"])
            end_time = datetime.time.fromisoformat(booking["end_time"])
            booking_end_datetime = datetime.datetime.combine(booking_date, end_time)
            
            # Check if booking ended more than grace period ago
            time_since_end = (current_datetime - booking_end_datetime).total_seconds()
            
            if time_since_end > BOOKING_GRACE_PERIOD:
                bookings_to_remove.append(booking["id"])
                log(f"Booking {booking['id']} ended {int(time_since_end/60)} minutes ago, marking for removal")
        
        # Remove expired bookings
        for booking_id in bookings_to_remove:
            remove_finished_booking(booking_id)
            
    except Exception as e:
        log(f"Error cleaning up past bookings: {str(e)}", LogLevel.ERROR)

def process_and_upload_video(video_path, booking_id):
    """Process video with overlays and intro, then add to upload queue."""
    try:
        if not os.path.exists(video_path):
            log(f"Video file not found: {video_path}", LogLevel.ERROR)
            return False
            
        # Get user settings and booking info
        user_settings = get_user_settings()
        
        # Get booking info for timestamp overlay
        booking_info = None
        try:
            response = supabase.table("bookings").select("*").eq("id", booking_id).single().execute()
            booking_info = response.data
        except Exception as e:
            log(f"Warning: Could not fetch booking info for overlays: {str(e)}", LogLevel.WARNING)
        
        # Generate processed filename
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        processed_filename = f"recording_{timestamp}_{booking_id}.mp4"
        processed_path = os.path.join("temp", f"processed_{processed_filename}")
        
        # Ensure temp directory exists
        os.makedirs("temp", exist_ok=True)
        
        # Process video with overlays if booking info is available
        if booking_info:
            log("Processing video with timestamp and logo overlays", LogLevel.INFO)
            if not process_video_with_overlays(video_path, processed_path, user_settings, booking_info):
                log("Failed to process video with overlays, using original", LogLevel.WARNING)
                processed_path = video_path
        else:
            processed_path = video_path
        
        # Add intro video if configured
        intro_path = user_settings.get("intro_video_path")
        final_path = processed_path
        
        if intro_path and os.path.exists(intro_path):
            log("Adding intro video to recording", LogLevel.INFO)
            final_processed_path = os.path.join("temp", f"final_{processed_filename}")
            if prepend_intro(intro_path, processed_path, final_processed_path):
                final_path = final_processed_path
                # Clean up intermediate file if different from original
                if processed_path != video_path:
                    cleanup_local_file(processed_path)
            else:
                log("Failed to add intro video, using processed video without intro", LogLevel.WARNING)
        
        # Add to upload queue with booking_id
        upload_queue.put((final_path, USER_ID, processed_filename, booking_id))
        log(f"Added processed video to upload queue: {processed_filename}", LogLevel.SUCCESS)
        return True
        
    except Exception as e:
        log(f"Error processing video for upload: {str(e)}", LogLevel.ERROR)
        return False

def upload_worker():
    """Optimized upload worker with retry logic."""
    while not shutting_down:
        try:
            task = upload_queue.get(timeout=1)
            if task is None or len(task) != 4:
                continue
                
            local_path, user_id, filename, booking_id = task
            
            # Check for stop signal
            if local_path is None and user_id is None:
                log("Upload worker received stop signal", LogLevel.INFO)
                break
                
            if local_path is None:
                continue
                
            max_retries = 3
            for attempt in range(max_retries):
                try:
                    with open(local_path, 'rb') as f:
                        storage_path = f"{user_id}/{filename}"
                        supabase.storage.from_("videos").upload(storage_path, f)
                        
                    insert_video_reference(user_id, filename, storage_path, booking_id)
                    cleanup_local_file(local_path)
                    log(f"Successfully uploaded and processed: {filename}", LogLevel.SUCCESS)
                    break
                except Exception as e:
                    if attempt == max_retries - 1:
                        log(f"Failed to upload after {max_retries} attempts: {str(e)}", LogLevel.ERROR)
                    else:
                        time.sleep(2 ** attempt)  # Exponential backoff
                        
        except queue.Empty:
            continue
        except Exception as e:
            log(f"Upload worker error: {str(e)}", LogLevel.ERROR)
            time.sleep(1)
    
    log("Upload worker shutting down", LogLevel.INFO)

def start_recording():
    """Start recording with hardware acceleration and robust error handling."""
    try:
        # Use libcamera-vid with hardware encoding
        cmd = [
            "libcamera-vid",
            "-t", "0",
            "--width", str(RECORD_WIDTH),
            "--height", str(RECORD_HEIGHT),
            "--framerate", str(RECORD_FPS),
            "--codec", "h264",
            "--inline",
            "--nopreview",
            "-o", "recording.h264"
        ]
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        # Wait briefly to see if process fails immediately
        time.sleep(2)
        if process.poll() is not None and process.returncode != 0:
            # Process exited with error, capture stderr
            _, stderr = process.communicate()
            log(f"libcamera-vid failed to start. Return code: {process.returncode}. Error: {stderr.decode().strip()}", LogLevel.ERROR)
            return None
        return process
    except Exception as e:
        log(f"Failed to start recording: {str(e)}", LogLevel.ERROR)
        return None

def update_camera_status(camera_on, is_recording):
    try:
        # Calculate storage usage
        storage_used = 0
        try:
            if os.path.exists("temp"):
                for filename in os.listdir("temp"):
                    filepath = os.path.join("temp", filename)
                    if os.path.isfile(filepath):
                        storage_used += os.path.getsize(filepath)
        except Exception as e:
            log(f"Error calculating storage: {e}", LogLevel.WARNING)
        
        # Get system info
        import psutil
        mem = psutil.virtual_memory()
        cpu_percent = psutil.cpu_percent(interval=0.5)
        
        # Calculate camera count - 1 if camera is active, 0 if not
        cameras_online = 1 if camera_on else 0
        total_cameras = 1  # We have 1 camera total
        
        # Update system_status table with correct column names
        system_data = {
            "user_id": USER_ID,
            "is_recording": is_recording,
            "is_streaming": False,  # Not streaming for now
            "storage_used": storage_used,
            "cpu_usage": cpu_percent,
            "memory_usage": mem.percent,
            "storage_usage": (mem.total - mem.available) / mem.total * 100,
            "pi_active": camera_on,
            "cameras_online": cameras_online,
            "total_cameras": total_cameras,
            "ip_address": get_ip_address(),
            "last_seen": datetime.datetime.now().isoformat(),
            "updated_at": datetime.datetime.now().isoformat()
        }
        
        # Try to update existing record first
        response = supabase.table("system_status").update(system_data).eq("user_id", USER_ID).execute()
        
        if not response.data:
            # If no existing record, insert new one
            system_data["created_at"] = datetime.datetime.now().isoformat()
            response = supabase.table("system_status").insert(system_data).execute()
        
        log(f"System status updated successfully", LogLevel.INFO)
        return True
        
    except Exception as e:
        log(f"Failed to update system status: {str(e)}", LogLevel.ERROR)
        return False

def get_ip_address():
    """Get the local IP address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def insert_video_reference(user_id, filename, storage_path, booking_id):
    now = datetime.datetime.now().isoformat()
    try:
        video_data = {
            "user_id": user_id,
            "filename": filename,
            "storage_path": storage_path,
            "booking_id": booking_id,  # Now include booking_id
            "created_at": now
        }
        
        supabase.table("videos").insert(video_data).execute()
        log(f"Added video reference for {filename} (associated with booking: {booking_id})", LogLevel.SUCCESS)
        return True
    except Exception as e:
        log(f"Database insert failed: {str(e)}", LogLevel.WARNING)
        # Try without booking_id if the column doesn't exist yet
        try:
            video_data_fallback = {
                "user_id": user_id,
                "filename": filename,
                "storage_path": storage_path,
                "created_at": now
            }
            supabase.table("videos").insert(video_data_fallback).execute()
            log(f"Added video reference for {filename} (booking_id column not available)", LogLevel.SUCCESS)
            return True
        except Exception as e2:
            log(f"Database insert failed even without booking_id: {str(e2)}", LogLevel.ERROR)
            return False

def cleanup_local_file(file_path):
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
            log(f"Cleaned up local file: {file_path}", LogLevel.SUCCESS)
            return True
    except Exception as e:
        log(f"Failed to cleanup local file {file_path}: {str(e)}", LogLevel.ERROR)
    return False

def handle_shutdown(signum, frame):
    """Handle shutdown signals gracefully."""
    global shutting_down
    log("Received shutdown signal, initiating graceful shutdown...", LogLevel.INFO)
    shutting_down = True

# Register signal handlers
signal.signal(signal.SIGINT, handle_shutdown)
signal.signal(signal.SIGTERM, handle_shutdown)

def main():
    """Main function with optimized video processing using CameraInterface."""
    global shutting_down

    # Start heartbeat thread
    start_heartbeat_thread()

    # Start upload worker
    upload_thread = threading.Thread(target=upload_worker, daemon=True)
    upload_thread.start()

    # Camera initialization with CameraInterface
    try:
        camera = CameraInterface(
            width=PREVIEW_WIDTH,
            height=PREVIEW_HEIGHT,
            fps=PREVIEW_FPS,
            output_dir="temp"
        )
        log(f"Camera initialized and opened with CameraInterface ({camera.camera_type})", LogLevel.SUCCESS)
        # Set pi_active to True at startup
        update_camera_status(camera_on=True, is_recording=False)
        send_heartbeat(is_recording=False)
    except Exception as e:
        log(f"Failed to initialize CameraInterface: {e}", LogLevel.ERROR)
        return

    prev_frame = None
    last_booking_check = 0
    BOOKING_CHECK_INTERVAL = 5  # check every 5 seconds for bookings - reduced from 30
    status_update_interval = 5  # Update status every 5 seconds - reduced from 60
    last_status_update = 0
    current_booking = None
    recording = False
    recording_path = None

    try:
        while not shutting_down:
            frame = camera.capture_frame()
            if frame is None:
                log("Failed to read frame from camera", LogLevel.ERROR)
                continue
                
            # Resize frame for preview
            frame = cv2.resize(frame, (PREVIEW_WIDTH, PREVIEW_HEIGHT))
            
            # Ball detection (only on preview resolution)
            center, radius = detect_moving_circle(frame, prev_frame)
            prev_frame = frame.copy()
            
            # Check bookings periodically
            current_time = time.time()
            if current_time - last_booking_check > BOOKING_CHECK_INTERVAL:
                # Clean up past bookings with grace period
                cleanup_past_bookings()
                
                new_booking = get_current_active_booking()
                
                # Handle booking changes
                if new_booking and (not current_booking or new_booking['id'] != current_booking['id']):
                    # New booking started
                    if recording and current_booking:
                        # Stop current recording
                        log(f"Stopping recording for previous booking: {current_booking['id']}", LogLevel.INFO)
                        recording_path = camera.stop_recording()
                        recording = False
                        
                        # Process and upload the video
                        if recording_path:
                            process_and_upload_video(recording_path, current_booking['id'])
                        
                        # Remove the finished booking
                        remove_finished_booking(current_booking['id'])
                    
                    # Start new recording
                    log(f"Starting recording for new booking: {new_booking['id']}", LogLevel.SUCCESS)
                    recording_path = camera.start_recording()
                    recording = True
                    current_booking = new_booking
                    # Update heartbeat immediately when recording state changes
                    send_heartbeat(is_recording=True)
                    
                elif not new_booking and recording and current_booking:
                    # Current booking ended
                    log(f"Booking {current_booking['id']} ended, stopping recording", LogLevel.INFO)
                    recording_path = camera.stop_recording()
                    recording = False
                    
                    # Process and upload the video
                    if recording_path:
                        process_and_upload_video(recording_path, current_booking['id'])
                    
                    # Remove the finished booking
                    remove_finished_booking(current_booking['id'])
                    current_booking = None
                    # Update heartbeat immediately when recording state changes
                    send_heartbeat(is_recording=False)
                
                last_booking_check = current_time
            
            # Throttle status update - only update every 5 seconds
            if current_time - last_status_update > status_update_interval:
                update_camera_status(camera_on=True, is_recording=recording)
                last_status_update = current_time
                
            # Process frame (skip if not needed)
            if center and radius:
                frame = create_focused_frame(frame, center, radius)
            
            # Overlay logos (cached)
            settings = get_user_settings()
            for position, logo_path in settings.get("logos", {}).items():
                frame = overlay_logo(frame, logo_path, position)
            
            # Show frame (only in debug mode)
            if os.getenv("DEBUG", "false").lower() == "true":
                cv2.imshow("Preview", frame)
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
                    
    except KeyboardInterrupt:
        log("Received keyboard interrupt", LogLevel.INFO)
    except Exception as e:
        log(f"Main loop error: {str(e)}", LogLevel.ERROR)
    finally:
        log("Shutting down gracefully...", LogLevel.INFO)
        if recording:
            log("Stopping recording and processing final video...", LogLevel.INFO)
            recording_path = camera.stop_recording()
            if recording_path and current_booking:
                process_and_upload_video(recording_path, current_booking['id'])
        camera.release()
        cv2.destroyAllWindows()
        update_camera_status(camera_on=False, is_recording=False)
        stop_heartbeat_thread()
        
        # Wait for upload queue to finish
        log("Waiting for upload queue to finish...", LogLevel.INFO)
        upload_queue.put((None, None, None, None))  # Signal upload worker to stop
        upload_thread.join(timeout=10)
        log("Shutdown complete", LogLevel.SUCCESS)

if __name__ == "__main__":
    main()
