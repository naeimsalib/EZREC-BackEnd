#!/usr/bin/env python3
"""
🔄 EZREC System Status Updater
Updates system status every 3 seconds - can be run standalone or as part of main
"""

import os
import sys
import time
import logging
import asyncio
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client, Client
import psutil

# Load environment variables
load_dotenv()

class SystemStatusUpdater:
    """
    🔄 EZREC System Status Updater
    
    Monitors and updates system status every 3 seconds:
    - CPU and memory usage
    - Disk space
    - Camera status
    - Service health
    - Network connectivity
    """
    
    def __init__(self):
        """Initialize System Status Updater"""
        self.setup_logging()
        self.setup_supabase()
        
        # Configuration
        self.user_id = os.getenv("USER_ID")
        self.camera_id = os.getenv("CAMERA_ID", "raspberry_pi_camera_1")
        self.base_dir = Path(os.getenv("EZREC_BASE_DIR", "/opt/ezrec-backend"))
        
        self.logger.info("🔄 System Status Updater initialized")
    
    def setup_logging(self):
        """Setup logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[logging.StreamHandler(sys.stdout)]
        )
        self.logger = logging.getLogger("SystemStatus")
    
    def setup_supabase(self):
        """Initialize Supabase client"""
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_KEY")
        
        if not url or not key:
            raise ValueError("Missing Supabase configuration")
        
        self.supabase: Client = create_client(url, key)
        self.logger.info("✅ Supabase client connected")
    
    def get_system_metrics(self):
        """Get current system metrics"""
        try:
            # CPU and Memory
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            
            # Disk usage
            disk = psutil.disk_usage(str(self.base_dir))
            
            # Check camera availability
            camera_status = "available"
            try:
                from picamera2 import Picamera2
                test_cam = Picamera2()
                test_cam.close()
            except Exception as e:
                camera_status = f"error: {str(e)[:50]}"
            
            # Check if recording process is running
            recording_active = False
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                try:
                    cmdline = ' '.join(proc.info['cmdline'] or [])
                    if 'main.py' in cmdline or 'orchestrator.py' in cmdline:
                        recording_active = True
                        break
                except:
                    continue
            
            return {
                "timestamp": datetime.now().isoformat(),
                "cpu_percent": round(cpu_percent, 1),
                "memory_percent": round(memory.percent, 1),
                "memory_available_mb": round(memory.available / 1024 / 1024, 1),
                "disk_percent": round((disk.used / disk.total) * 100, 1),
                "disk_free_gb": round(disk.free / 1024 / 1024 / 1024, 1),
                "camera_status": camera_status,
                "recording_process_active": recording_active
            }
            
        except Exception as e:
            self.logger.error(f"❌ Error getting system metrics: {e}")
            return {}
    
    async def update_status(self):
        """Update system status in database"""
        try:
            metrics = self.get_system_metrics()
            
            if not metrics:
                return
            
            # Prepare status data
            status_data = {
                "user_id": self.user_id,
                "camera_id": self.camera_id,
                "status": "running" if metrics["recording_process_active"] else "idle",
                "last_heartbeat": metrics["timestamp"],
                "cpu_usage": metrics["cpu_percent"],
                "memory_usage": metrics["memory_percent"],
                "memory_available_mb": metrics["memory_available_mb"],
                "disk_usage": metrics["disk_percent"],
                "disk_free_gb": metrics["disk_free_gb"],
                "camera_status": metrics["camera_status"],
                "is_recording": metrics["recording_process_active"]
            }
            
            # Upsert to database
            result = self.supabase.table("system_status").upsert(
                status_data, 
                on_conflict="user_id,camera_id"
            ).execute()
            
            self.logger.info(f"✅ Status updated - CPU: {metrics['cpu_percent']}% | Memory: {metrics['memory_percent']}% | Camera: {metrics['camera_status']}")
            
        except Exception as e:
            self.logger.error(f"❌ Failed to update status: {e}")
    
    async def start_monitoring(self):
        """Start continuous status monitoring (every 3 seconds)"""
        self.logger.info("🚀 Starting system status monitoring...")
        
        while True:
            try:
                await self.update_status()
                await asyncio.sleep(3)  # Update every 3 seconds
                
            except KeyboardInterrupt:
                self.logger.info("🛑 Status monitoring stopped")
                break
            except Exception as e:
                self.logger.error(f"❌ Monitoring error: {e}")
                await asyncio.sleep(3)

async def main():
    """Main entry point for standalone usage"""
    updater = SystemStatusUpdater()
    await updater.start_monitoring()

if __name__ == "__main__":
    asyncio.run(main())
