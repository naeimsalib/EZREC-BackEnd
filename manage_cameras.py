import os
from dotenv import load_dotenv
load_dotenv()
import time
from supabase import create_client, Client
import logging
from datetime import datetime
import subprocess
import json
from src.camera_interface import CameraInterface

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# Initialize Supabase client
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY")
supabase: Client = create_client(supabase_url, supabase_key)

def check_camera_status(camera_id: str) -> bool:
    """Check if camera is online by attempting to connect using CameraInterface"""
    try:
        cam = CameraInterface()
        cam.release()
        return True
    except Exception as e:
        logging.error(f"Error checking camera status: {e}")
        return False

def start_recording(camera_id: str, user_id: str):
    """Start recording from a camera"""
    try:
        # Update camera status
        supabase.table("cameras").update({
            "is_recording": True,
            "status": "recording"
        }).eq("id", camera_id).execute()
        
        # Create new recording entry
        recording = {
            "user_id": user_id,
            "camera_id": camera_id,
            "title": f"Recording {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "duration": 0,
            "size": 0
        }
        
        response = supabase.table("recordings").insert(recording).execute()
        recording_id = response.data[0]["id"]
        
        # Start recording process (placeholder)
        # Implement actual recording logic here
        
        logging.info(f"Started recording for camera {camera_id}")
        return recording_id
    except Exception as e:
        logging.error(f"Error starting recording: {e}")
        return None

def stop_recording(camera_id: str, recording_id: str):
    """Stop recording from a camera"""
    try:
        # Update camera status
        supabase.table("cameras").update({
            "is_recording": False,
            "status": "online"
        }).eq("id", camera_id).execute()
        
        # Update recording entry with final duration and size
        # This is a placeholder - implement actual recording stats
        supabase.table("recordings").update({
            "duration": 300,  # 5 minutes example
            "size": 1024000,  # 1MB example
            "video_url": f"recordings/{recording_id}.mp4"
        }).eq("id", recording_id).execute()
        
        logging.info(f"Stopped recording for camera {camera_id}")
    except Exception as e:
        logging.error(f"Error stopping recording: {e}")

def update_camera_status():
    """Update status of all cameras"""
    try:
        # Get all cameras
        response = supabase.table("cameras").select("*").execute()
        cameras = response.data
        
        for camera in cameras:
            is_online = check_camera_status(camera["id"])
            status = "online" if is_online else "offline"
            
            # Update camera status
            supabase.table("cameras").update({
                "status": status,
                "last_seen": datetime.now().isoformat()
            }).eq("id", camera["id"]).execute()
            
            logging.info(f"Updated status for camera {camera['id']}: {status}")
    except Exception as e:
        logging.error(f"Error updating camera status: {e}")

def main():
    """Main function to run the camera manager"""
    logging.info("Starting camera manager...")
    
    while True:
        try:
            update_camera_status()
            time.sleep(30)  # Check every 30 seconds
        except Exception as e:
            logging.error(f"Error in main loop: {e}")
            time.sleep(5)  # Wait before retrying

if __name__ == "__main__":
    main() 