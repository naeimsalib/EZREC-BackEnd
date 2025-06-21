import os
from dotenv import load_dotenv
load_dotenv()
import psutil
import time
from supabase import create_client, Client
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# Initialize Supabase client
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = (
    os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    or os.getenv("SUPABASE_KEY")
    or os.getenv("SUPABASE_ANON_KEY")
)
if not supabase_key:
    raise Exception("No Supabase key found in environment variables! Make sure SUPABASE_SERVICE_ROLE_KEY, SUPABASE_KEY, or SUPABASE_ANON_KEY is set.")
supabase: Client = create_client(supabase_url, supabase_key)

def get_system_metrics():
    """Get current system metrics"""
    try:
        # CPU usage
        cpu_usage = psutil.cpu_percent(interval=1)
        
        # Memory usage
        memory = psutil.virtual_memory()
        memory_usage = memory.percent
        
        # Storage usage
        storage = psutil.disk_usage('/')
        storage_usage = storage.percent
        
        # Network speed (bytes per second)
        net_io_start = psutil.net_io_counters()
        time.sleep(1)
        net_io_end = psutil.net_io_counters()
        network_speed = (net_io_end.bytes_sent + net_io_end.bytes_recv - 
                        net_io_start.bytes_sent - net_io_start.bytes_recv) / 1024 / 1024  # Convert to Mbps
        
        return {
            "cpu_usage": cpu_usage,
            "memory_usage": memory_usage,
            "storage_usage": storage_usage,
            "network_speed": round(network_speed, 2)
        }
    except Exception as e:
        logging.error(f"Error getting system metrics: {e}")
        return None

def update_system_status(user_id: str):
    """Update system status in the database"""
    try:
        metrics = get_system_metrics()
        if not metrics:
            return
        
        # Check if status exists for user
        response = supabase.table("system_status").select("*").eq("user_id", user_id).execute()
        
        if response.data:
            # Update existing status
            supabase.table("system_status").update(metrics).eq("user_id", user_id).execute()
        else:
            # Create new status
            metrics["user_id"] = user_id
            supabase.table("system_status").insert(metrics).execute()
            
        logging.info(f"System status updated for user {user_id}")
    except Exception as e:
        logging.error(f"Error updating system status: {e}")

def main():
    """Main function to run the system status updater"""
    logging.info("Starting system status updater...")
    
    user_id = os.getenv("USER_ID")
    if not user_id:
        logging.error("USER_ID environment variable not set!")
        return
    while True:
        try:
            update_system_status(user_id)
            time.sleep(5)
        except Exception as e:
            logging.error(f"Error in main loop: {e}")
            time.sleep(5)  # Wait before retrying

if __name__ == "__main__":
    main() 