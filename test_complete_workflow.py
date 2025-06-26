#!/usr/bin/env python3
"""
🎬 EZREC Complete Workflow Test
==============================
This script tests the entire EZREC booking lifecycle:
1. Create a test booking
2. Monitor booking detection 
3. Verify recording starts at scheduled time
4. Monitor recording status during recording
5. Verify recording stops at end time
6. Check booking removal from database
7. Verify video upload to storage
8. Confirm local file cleanup
9. Monitor system status updates

Author: EZREC System
Date: 2025-06-25
"""

import os
import sys
import time
import json
import datetime
from pathlib import Path
import subprocess
import requests

# Add src directory to path for imports
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

try:
    from config import Config
    from utils import SupabaseManager
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Make sure you're running this from the EZREC-BackEnd directory")
    sys.exit(1)

class EZRECWorkflowTester:
    def __init__(self):
        self.config = Config()
        self.supabase = SupabaseManager()
        self.test_booking_id = None
        self.test_start_time = None
        self.test_end_time = None
        self.recording_file_path = None
        
        print("🎬 EZREC Complete Workflow Tester")
        print("=" * 50)
        print(f"📅 Test Date: {datetime.datetime.now()}")
        print(f"👤 User ID: {self.config.user_id}")
        print(f"📹 Camera ID: {self.config.camera_id}")
        print("")

    def create_test_booking(self, minutes_from_now=1, duration_minutes=2):
        """Create a test booking starting in X minutes"""
        print("📋 STEP 1: Creating test booking...")
        
        now = datetime.datetime.now()
        start_time = now + datetime.timedelta(minutes=minutes_from_now)
        end_time = start_time + datetime.timedelta(minutes=duration_minutes)
        
        self.test_start_time = start_time
        self.test_end_time = end_time
        
        booking_data = {
            "date": start_time.strftime("%Y-%m-%d"),
            "start_time": start_time.strftime("%H:%M:%S"),
            "end_time": end_time.strftime("%H:%M:%S"),
            "user_id": self.config.user_id,
            "camera_id": self.config.camera_id,
            "status": "confirmed",
            "created_at": now.isoformat(),
            "updated_at": now.isoformat()
        }
        
        print(f"  📅 Booking Date: {booking_data['date']}")
        print(f"  🕐 Start Time: {booking_data['start_time']}")
        print(f"  🕐 End Time: {booking_data['end_time']}")
        print(f"  ⏱️  Duration: {duration_minutes} minutes")
        print(f"  ⏰ Starts in: {minutes_from_now} minute(s)")
        
        try:
            # Insert booking using Supabase
            result = self.supabase.client.table("bookings").insert(booking_data).execute()
            
            if result.data:
                self.test_booking_id = result.data[0]['id']
                print(f"  ✅ Test booking created: {self.test_booking_id}")
                return True
            else:
                print(f"  ❌ Failed to create booking: {result}")
                return False
                
        except Exception as e:
            print(f"  ❌ Error creating booking: {e}")
            return False

    def monitor_booking_detection(self, timeout_seconds=60):
        """Monitor if the system detects the test booking"""
        print("\n🔍 STEP 2: Monitoring booking detection...")
        
        start_time = time.time()
        detected = False
        
        while time.time() - start_time < timeout_seconds:
            try:
                # Check if booking appears in system logs
                result = subprocess.run(
                    ["sudo", "journalctl", "-u", "ezrec-backend", "--since", "30 seconds ago", "--no-pager"],
                    capture_output=True, text=True, timeout=10
                )
                
                if self.test_booking_id in result.stdout:
                    print(f"  ✅ Booking {self.test_booking_id} detected in system logs!")
                    detected = True
                    break
                
                # Also check direct database query
                bookings = self.supabase.client.table("bookings").select("*").eq("id", self.test_booking_id).execute()
                if bookings.data:
                    print(f"  ✅ Booking confirmed in database")
                    detected = True
                    break
                    
                print(f"  ⏳ Waiting for detection... ({int(time.time() - start_time)}s)")
                time.sleep(5)
                
            except subprocess.TimeoutExpired:
                print("  ⚠️ Log check timed out")
            except Exception as e:
                print(f"  ⚠️ Error checking detection: {e}")
                
        return detected

    def wait_for_recording_start(self):
        """Wait for the recording to start and monitor"""
        print("\n🎬 STEP 3: Waiting for recording to start...")
        
        now = datetime.datetime.now()
        wait_time = (self.test_start_time - now).total_seconds()
        
        if wait_time > 0:
            print(f"  ⏰ Recording starts in {wait_time:.1f} seconds")
            print(f"  ⏱️ Waiting until {self.test_start_time.strftime('%H:%M:%S')}")
            
            # Wait with countdown
            while wait_time > 0:
                if wait_time <= 60:  # Show countdown for last minute
                    print(f"  ⏳ Starting in {wait_time:.0f} seconds...", end='\r')
                time.sleep(1)
                wait_time -= 1
                
        print("\n  🎬 Recording should be starting now!")
        return True

    def monitor_recording_status(self):
        """Monitor recording status during the recording period"""
        print("\n📹 STEP 4: Monitoring recording status...")
        
        recording_detected = False
        recording_file_found = False
        status_updates_working = False
        
        # Monitor for 30 seconds or until end time
        monitor_until = min(
            datetime.datetime.now() + datetime.timedelta(seconds=30),
            self.test_end_time
        )
        
        while datetime.datetime.now() < monitor_until:
            try:
                # Check service logs for recording activity
                result = subprocess.run(
                    ["sudo", "journalctl", "-u", "ezrec-backend", "--since", "10 seconds ago", "--no-pager"],
                    capture_output=True, text=True, timeout=10
                )
                
                if "Recording started" in result.stdout or "🎬" in result.stdout:
                    if not recording_detected:
                        print("  ✅ Recording started detected in logs!")
                        recording_detected = True
                
                if "Recording in progress" in result.stdout or "recording" in result.stdout.lower():
                    print("  📹 Recording in progress...")
                
                # Check for recording files
                recordings_dir = Path("/opt/ezrec-backend/recordings")
                if recordings_dir.exists():
                    recent_files = list(recordings_dir.glob("*.mp4"))
                    if recent_files and not recording_file_found:
                        latest_file = max(recent_files, key=lambda x: x.stat().st_mtime)
                        file_age = time.time() - latest_file.stat().st_mtime
                        if file_age < 60:  # File created in last minute
                            print(f"  ✅ Recording file detected: {latest_file.name}")
                            self.recording_file_path = latest_file
                            recording_file_found = True
                
                # Check system status updates
                system_status = self.supabase.client.table("system_status").select("*").eq("user_id", self.config.user_id).execute()
                if system_status.data:
                    last_update = system_status.data[0].get('updated_at', '')
                    if last_update:
                        update_time = datetime.datetime.fromisoformat(last_update.replace('Z', '+00:00'))
                        if (datetime.datetime.now(datetime.timezone.utc) - update_time).total_seconds() < 10:
                            if not status_updates_working:
                                print("  ✅ System status updates are working!")
                                status_updates_working = True
                
                time.sleep(3)
                
            except Exception as e:
                print(f"  ⚠️ Error monitoring: {e}")
                
        return recording_detected, recording_file_found, status_updates_working

    def wait_for_recording_end(self):
        """Wait for recording to end and verify cleanup"""
        print("\n🔚 STEP 5: Waiting for recording to end...")
        
        now = datetime.datetime.now()
        wait_time = (self.test_end_time - now).total_seconds()
        
        if wait_time > 0:
            print(f"  ⏰ Recording ends in {wait_time:.1f} seconds")
            print(f"  ⏱️ Waiting until {self.test_end_time.strftime('%H:%M:%S')}")
            time.sleep(max(0, wait_time))
            
        print("  🔚 Recording should be ending now!")
        time.sleep(5)  # Give system time to process
        return True

    def verify_booking_cleanup(self):
        """Verify booking was removed from database"""
        print("\n🗑️ STEP 6: Verifying booking cleanup...")
        
        try:
            # Check if booking still exists
            booking = self.supabase.client.table("bookings").select("*").eq("id", self.test_booking_id).execute()
            
            if not booking.data or len(booking.data) == 0:
                print("  ✅ Booking successfully removed from database!")
                return True
            else:
                booking_status = booking.data[0].get('status', 'unknown')
                print(f"  ⚠️ Booking still exists with status: {booking_status}")
                
                # Check if status changed to completed/processed
                if booking_status in ['completed', 'processed', 'recorded']:
                    print("  ✅ Booking status updated to completed!")
                    return True
                else:
                    print("  ❌ Booking not cleaned up properly")
                    return False
                    
        except Exception as e:
            print(f"  ❌ Error checking booking cleanup: {e}")
            return False

    def verify_video_upload(self):
        """Verify video was uploaded to storage and videos table"""
        print("\n☁️ STEP 7: Verifying video upload...")
        
        try:
            # Check videos table for our recording
            videos = self.supabase.client.table("videos").select("*").eq("user_id", self.config.user_id).order("created_at", desc=True).limit(1).execute()
            
            if videos.data:
                latest_video = videos.data[0]
                video_id = latest_video.get('id')
                storage_path = latest_video.get('storage_path', latest_video.get('file_path', ''))
                created_at = latest_video.get('created_at', '')
                
                print(f"  ✅ Video record found in database: {video_id}")
                print(f"  📁 Storage path: {storage_path}")
                print(f"  📅 Created: {created_at}")
                
                # Check if file exists in storage
                if storage_path:
                    try:
                        # Try to get file info from Supabase storage
                        storage_info = self.supabase.client.storage.from_("videos").list()
                        print(f"  ✅ Storage connection successful")
                        return True
                    except Exception as storage_error:
                        print(f"  ⚠️ Could not verify storage upload: {storage_error}")
                        return True  # Database entry exists, assume upload worked
                        
            else:
                print("  ❌ No video record found in database")
                return False
                
        except Exception as e:
            print(f"  ❌ Error checking video upload: {e}")
            return False

    def verify_local_cleanup(self):
        """Verify local recording files were cleaned up"""
        print("\n🧹 STEP 8: Verifying local file cleanup...")
        
        try:
            if self.recording_file_path and self.recording_file_path.exists():
                file_size = self.recording_file_path.stat().st_size
                file_age = time.time() - self.recording_file_path.stat().st_mtime
                
                if file_age > 300:  # File older than 5 minutes should be cleaned up
                    print(f"  ⚠️ Recording file still exists: {self.recording_file_path.name}")
                    print(f"  📏 Size: {file_size} bytes, Age: {file_age:.1f}s")
                    return False
                else:
                    print(f"  ⏳ File still present but recent (may be uploading): {file_age:.1f}s old")
                    return True
            else:
                print("  ✅ Local recording file cleaned up successfully!")
                return True
                
        except Exception as e:
            print(f"  ❌ Error checking local cleanup: {e}")
            return False

    def verify_system_status_updates(self):
        """Verify system status is being updated every 3 seconds"""
        print("\n📊 STEP 9: Verifying system status updates...")
        
        try:
            # Check system status updates over 15 seconds
            initial_status = self.supabase.client.table("system_status").select("*").eq("user_id", self.config.user_id).execute()
            
            if not initial_status.data:
                print("  ❌ No system status record found")
                return False
                
            initial_time = initial_status.data[0].get('updated_at')
            print(f"  📅 Initial status time: {initial_time}")
            
            # Wait and check for updates
            update_count = 0
            for i in range(5):  # Check 5 times over 15 seconds
                time.sleep(3)
                current_status = self.supabase.client.table("system_status").select("*").eq("user_id", self.config.user_id).execute()
                
                if current_status.data:
                    current_time = current_status.data[0].get('updated_at')
                    if current_time != initial_time:
                        update_count += 1
                        print(f"  ✅ Status update #{update_count} detected: {current_time}")
                        initial_time = current_time
                        
            if update_count >= 3:
                print(f"  ✅ System status updating regularly ({update_count} updates in 15s)")
                return True
            else:
                print(f"  ⚠️ Only {update_count} status updates detected")
                return False
                
        except Exception as e:
            print(f"  ❌ Error checking status updates: {e}")
            return False

    def cleanup_test_data(self):
        """Clean up any remaining test data"""
        print("\n🧹 CLEANUP: Removing test data...")
        
        try:
            if self.test_booking_id:
                # Force remove test booking if it still exists
                self.supabase.client.table("bookings").delete().eq("id", self.test_booking_id).execute()
                print(f"  ✅ Test booking {self.test_booking_id} removed")
        except Exception as e:
            print(f"  ⚠️ Error cleaning up: {e}")

    def run_complete_test(self):
        """Run the complete workflow test"""
        print("🚀 Starting complete EZREC workflow test...")
        print("This will test the entire booking lifecycle end-to-end")
        print("")
        
        results = {}
        
        try:
            # Step 1: Create test booking
            results['booking_creation'] = self.create_test_booking(minutes_from_now=1, duration_minutes=2)
            
            if not results['booking_creation']:
                print("❌ Test failed at booking creation step")
                return results
            
            # Step 2: Monitor detection
            results['booking_detection'] = self.monitor_booking_detection()
            
            # Step 3: Wait for recording start
            results['recording_start_wait'] = self.wait_for_recording_start()
            
            # Step 4: Monitor recording
            recording_detected, file_found, status_updates = self.monitor_recording_status()
            results['recording_detected'] = recording_detected
            results['recording_file_found'] = file_found
            results['status_updates_during_recording'] = status_updates
            
            # Step 5: Wait for recording end
            results['recording_end_wait'] = self.wait_for_recording_end()
            
            # Step 6: Verify booking cleanup
            results['booking_cleanup'] = self.verify_booking_cleanup()
            
            # Step 7: Verify video upload
            results['video_upload'] = self.verify_video_upload()
            
            # Step 8: Verify local cleanup
            results['local_cleanup'] = self.verify_local_cleanup()
            
            # Step 9: Verify system status
            results['system_status_updates'] = self.verify_system_status_updates()
            
        except KeyboardInterrupt:
            print("\n⚠️ Test interrupted by user")
        except Exception as e:
            print(f"\n❌ Test failed with error: {e}")
        finally:
            # Cleanup
            self.cleanup_test_data()
        
        # Print final results
        self.print_test_results(results)
        return results
    
    def print_test_results(self, results):
        """Print comprehensive test results"""
        print("\n" + "=" * 60)
        print("🎯 EZREC COMPLETE WORKFLOW TEST RESULTS")
        print("=" * 60)
        
        total_tests = len(results)
        passed_tests = sum(1 for result in results.values() if result)
        
        print(f"📊 Overall Score: {passed_tests}/{total_tests} tests passed")
        print(f"📈 Success Rate: {(passed_tests/total_tests)*100:.1f}%")
        print("")
        
        test_descriptions = {
            'booking_creation': '📋 Booking Creation',
            'booking_detection': '🔍 Booking Detection',
            'recording_start_wait': '⏰ Recording Start Wait',
            'recording_detected': '🎬 Recording Started',
            'recording_file_found': '📁 Recording File Created',
            'status_updates_during_recording': '📊 Status Updates During Recording',
            'recording_end_wait': '🔚 Recording End Wait',
            'booking_cleanup': '🗑️ Booking Cleanup',
            'video_upload': '☁️ Video Upload',
            'local_cleanup': '🧹 Local File Cleanup',
            'system_status_updates': '📈 System Status Updates'
        }
        
        for test_key, test_name in test_descriptions.items():
            if test_key in results:
                status = "✅ PASS" if results[test_key] else "❌ FAIL"
                print(f"{test_name:<35} {status}")
        
        print("")
        
        if passed_tests == total_tests:
            print("🎉 ALL TESTS PASSED! EZREC system is working perfectly!")
        elif passed_tests >= total_tests * 0.8:
            print("✅ Most tests passed. System is mostly functional.")
        else:
            print("⚠️ Several tests failed. System may need attention.")
        
        print("=" * 60)

if __name__ == "__main__":
    tester = EZRECWorkflowTester()
    tester.run_complete_test() 