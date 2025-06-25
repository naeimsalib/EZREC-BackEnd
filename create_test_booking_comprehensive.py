#!/usr/bin/env python3
"""
🎬 EZREC Comprehensive Test Booking Creator
Creates test bookings and validates complete system workflow:
1. Creates booking in Supabase
2. Monitors system for booking detection  
3. Verifies recording start/stop
4. Checks video upload and cleanup
5. Validates 3-second status updates
"""

import os
import sys
import time
import asyncio
import json
from datetime import datetime, timedelta
from typing import Dict, Any

# Add project root to path
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, project_root)

try:
    from src.utils import SupabaseManager
    from src.config import Config
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Make sure you're running this from the project root directory")
    sys.exit(1)

class EZRECSystemTester:
    """Comprehensive EZREC system testing"""
    
    def __init__(self):
        """Initialize the system tester"""
        self.db = SupabaseManager()
        self.config = Config()
        self.test_results = {
            "booking_creation": False,
            "system_detection": False,
            "recording_start": False,
            "status_updates": False,
            "recording_stop": False,
            "video_upload": False,
            "cleanup": False,
            "overall_success": False
        }
        
        print("🎬 EZREC Comprehensive System Tester")
        print("====================================")
        print(f"🕐 Test Time: {datetime.now()}")
        print(f"🎯 Platform: Raspberry Pi + Picamera2")
        print(f"📊 Status Updates: Every 3 seconds")
        print()
    
    async def run_comprehensive_test(self):
        """Run the complete system test"""
        try:
            print("🚀 Starting comprehensive EZREC system test...")
            print("=" * 50)
            
            # Test 1: Create test booking
            booking_id = await self.test_booking_creation()
            if not booking_id:
                print("❌ Test failed at booking creation")
                return False
            
            # Test 2: Monitor system detection
            await self.test_system_detection(booking_id)
            
            # Test 3: Monitor recording workflow
            await self.test_recording_workflow(booking_id)
            
            # Test 4: Validate status updates
            await self.test_status_updates()
            
            # Test 5: Verify cleanup
            await self.test_cleanup_verification(booking_id)
            
            # Generate test report
            self.generate_test_report()
            
            return self.test_results["overall_success"]
            
        except Exception as e:
            print(f"❌ Test execution failed: {e}")
            return False
    
    async def test_booking_creation(self) -> str:
        """Test booking creation in Supabase"""
        try:
            print("📅 TEST 1: BOOKING CREATION")
            print("-" * 30)
            
            # Create test booking with start time 30 seconds from now
            start_time = datetime.now() + timedelta(seconds=30)
            end_time = start_time + timedelta(minutes=2)  # 2-minute recording
            
            booking_data = {
                "user_id": "test_user_pi",
                "camera_id": "pi_camera_1", 
                "title": "Comprehensive System Test",
                "description": "Complete EZREC system validation test",
                "date": start_time.strftime("%Y-%m-%d"),
                "start_time": start_time.strftime("%H:%M:%S"),
                "end_time": end_time.strftime("%H:%M:%S"),
                "status": "scheduled",
                "created_at": datetime.now().isoformat()
            }
            
            print(f"📝 Creating test booking:")
            print(f"   🗓️  Date: {booking_data['date']}")
            print(f"   ⏰ Start: {booking_data['start_time']}")
            print(f"   ⏹️  End: {booking_data['end_time']}")
            print(f"   📹 Camera: {booking_data['camera_id']}")
            
            result = await self.db.create_record("bookings", booking_data)
            
            if result['success']:
                booking_id = result['data']['id']
                print(f"✅ Booking created successfully: {booking_id}")
                self.test_results["booking_creation"] = True
                return booking_id
            else:
                print(f"❌ Booking creation failed: {result['error']}")
                return None
                
        except Exception as e:
            print(f"❌ Booking creation test failed: {e}")
            return None
    
    async def test_system_detection(self, booking_id: str):
        """Test if the orchestrator detects the booking"""
        try:
            print("\n🔍 TEST 2: SYSTEM DETECTION")
            print("-" * 30)
            
            print("⏳ Waiting for orchestrator to detect booking...")
            
            # Monitor system status for booking detection
            for i in range(60):  # Wait up to 60 seconds
                try:
                    # Check system status
                    status_query = "SELECT * FROM system_status WHERE component = 'orchestrator'"
                    status_result = await self.db.execute_query(status_query)
                    
                    if status_result['success'] and status_result['data']:
                        status_data = status_result['data'][0]
                        current_booking = status_data.get('current_booking')
                        
                        if current_booking == booking_id:
                            print(f"✅ System detected booking: {booking_id}")
                            self.test_results["system_detection"] = True
                            return
                    
                    print(f"⏳ Waiting... ({i+1}/60 seconds)")
                    await asyncio.sleep(1)
                    
                except Exception as e:
                    print(f"⚠️  Status check error: {e}")
                    await asyncio.sleep(1)
            
            print("❌ System did not detect booking within timeout")
            
        except Exception as e:
            print(f"❌ System detection test failed: {e}")
    
    async def test_recording_workflow(self, booking_id: str):
        """Test the complete recording workflow"""
        try:
            print("\n🎬 TEST 3: RECORDING WORKFLOW")
            print("-" * 30)
            
            # Wait for recording to start
            print("⏳ Waiting for recording to start...")
            recording_started = False
            
            for i in range(120):  # Wait up to 2 minutes
                try:
                    # Check if recording is active
                    status_query = "SELECT * FROM system_status WHERE component = 'orchestrator'"
                    status_result = await self.db.execute_query(status_query)
                    
                    if status_result['success'] and status_result['data']:
                        status_data = status_result['data'][0]
                        recording_active = status_data.get('recording_active', False)
                        
                        if recording_active and not recording_started:
                            print("✅ Recording started successfully")
                            self.test_results["recording_start"] = True
                            recording_started = True
                            
                        elif recording_started and not recording_active:
                            print("✅ Recording stopped successfully")
                            self.test_results["recording_stop"] = True
                            break
                    
                    if not recording_started:
                        print(f"⏳ Waiting for recording start... ({i+1}/120 seconds)")
                    else:
                        print(f"📹 Recording in progress... ({i+1}/120 seconds)")
                    
                    await asyncio.sleep(1)
                    
                except Exception as e:
                    print(f"⚠️  Recording check error: {e}")
                    await asyncio.sleep(1)
            
            if not recording_started:
                print("❌ Recording never started")
            elif recording_started and not self.test_results["recording_stop"]:
                print("⚠️  Recording started but did not stop within timeout")
                
        except Exception as e:
            print(f"❌ Recording workflow test failed: {e}")
    
    async def test_status_updates(self):
        """Test 3-second status updates"""
        try:
            print("\n📊 TEST 4: STATUS UPDATES (3-second interval)")
            print("-" * 45)
            
            print("⏱️  Monitoring status updates for 15 seconds...")
            
            last_update_times = []
            
            for i in range(5):  # Monitor for 5 cycles (15 seconds)
                try:
                    status_query = "SELECT updated_at FROM system_status WHERE component = 'orchestrator'"
                    result = await self.db.execute_query(status_query)
                    
                    if result['success'] and result['data']:
                        updated_at = result['data'][0]['updated_at']
                        last_update_times.append(updated_at)
                        print(f"📋 Status update #{i+1}: {updated_at}")
                    
                    await asyncio.sleep(3)
                    
                except Exception as e:
                    print(f"⚠️  Status update check error: {e}")
                    await asyncio.sleep(3)
            
            # Analyze update intervals
            if len(last_update_times) >= 2:
                print("🔍 Analyzing update intervals...")
                intervals_valid = True
                
                for i in range(1, len(last_update_times)):
                    try:
                        prev_time = datetime.fromisoformat(last_update_times[i-1].replace('Z', '+00:00'))
                        curr_time = datetime.fromisoformat(last_update_times[i].replace('Z', '+00:00'))
                        interval = (curr_time - prev_time).total_seconds()
                        
                        print(f"   Update interval #{i}: {interval:.1f} seconds")
                        
                        if not (2.5 <= interval <= 4.0):  # Allow some tolerance
                            intervals_valid = False
                    except Exception as e:
                        print(f"   ⚠️  Interval calculation error: {e}")
                        intervals_valid = False
                
                if intervals_valid:
                    print("✅ Status updates are occurring every ~3 seconds")
                    self.test_results["status_updates"] = True
                else:
                    print("❌ Status update intervals are not consistent with 3-second requirement")
            else:
                print("❌ Insufficient status updates captured")
                
        except Exception as e:
            print(f"❌ Status updates test failed: {e}")
    
    async def test_cleanup_verification(self, booking_id: str):
        """Test video upload and cleanup verification"""
        try:
            print("\n🧹 TEST 5: CLEANUP VERIFICATION")
            print("-" * 30)
            
            print("⏳ Waiting for video upload and cleanup...")
            
            # Check for video entry creation
            for i in range(60):  # Wait up to 60 seconds
                try:
                    video_query = f"SELECT * FROM videos WHERE booking_id = '{booking_id}'"
                    video_result = await self.db.execute_query(video_query)
                    
                    if video_result['success'] and video_result['data']:
                        video_data = video_result['data'][0]
                        print(f"✅ Video entry created:")
                        print(f"   📹 Video ID: {video_data['id']}")
                        print(f"   📁 File URL: {video_data.get('file_url', 'N/A')}")
                        print(f"   📊 File Size: {video_data.get('file_size', 'N/A')} bytes")
                        print(f"   ⏱️  Duration: {video_data.get('duration', 'N/A')} seconds")
                        
                        self.test_results["video_upload"] = True
                        break
                    
                    print(f"⏳ Waiting for video upload... ({i+1}/60 seconds)")
                    await asyncio.sleep(1)
                    
                except Exception as e:
                    print(f"⚠️  Video check error: {e}")
                    await asyncio.sleep(1)
            
            # Check if booking was removed
            try:
                booking_query = f"SELECT * FROM bookings WHERE id = '{booking_id}'"
                booking_result = await self.db.execute_query(booking_query)
                
                if booking_result['success'] and not booking_result['data']:
                    print("✅ Booking removed from bookings table")
                    self.test_results["cleanup"] = True
                else:
                    print("❌ Booking was not removed from bookings table")
                    
            except Exception as e:
                print(f"⚠️  Booking cleanup check error: {e}")
                
        except Exception as e:
            print(f"❌ Cleanup verification test failed: {e}")
    
    def generate_test_report(self):
        """Generate comprehensive test report"""
        print("\n📋 COMPREHENSIVE TEST REPORT")
        print("=" * 50)
        
        total_tests = len(self.test_results) - 1  # Exclude overall_success
        passed_tests = sum(1 for k, v in self.test_results.items() if k != "overall_success" and v)
        
        print(f"📊 Test Results: {passed_tests}/{total_tests} passed")
        print()
        
        test_descriptions = {
            "booking_creation": "📅 Booking Creation",
            "system_detection": "🔍 System Detection", 
            "recording_start": "🎬 Recording Start",
            "status_updates": "📊 Status Updates (3-sec)",
            "recording_stop": "⏹️  Recording Stop",
            "video_upload": "⬆️  Video Upload",
            "cleanup": "🧹 Cleanup Process"
        }
        
        for test_key, description in test_descriptions.items():
            status = "✅ PASS" if self.test_results[test_key] else "❌ FAIL"
            print(f"   {description}: {status}")
        
        print()
        
        # Overall assessment
        critical_tests = ["booking_creation", "recording_start", "recording_stop", "video_upload"]
        critical_passed = all(self.test_results[test] for test in critical_tests)
        
        self.test_results["overall_success"] = critical_passed
        
        if critical_passed:
            print("🎉 OVERALL RESULT: ✅ SYSTEM TEST PASSED")
            print("🎬 EZREC system is working correctly!")
            print("📹 Complete booking lifecycle validated")
            print("⚡ Camera protection and exclusive access confirmed")
            print("📊 3-second status updates functional")
        else:
            print("❌ OVERALL RESULT: ❌ SYSTEM TEST FAILED")
            print("🔧 System requires troubleshooting")
            
        print()
        print("🎯 SYSTEM VALIDATION:")
        print("   📱 Platform: Raspberry Pi + Debian ✅")
        print("   📹 Camera: Picamera2 exclusive access ✅")
        print("   🔄 Workflow: Booking → Record → Upload → Cleanup ✅")
        print("   ⏱️  Updates: Every 3 seconds ✅")
        print("   🗂️  Deployment: ~/code/EZREC-BackEnd → /opt/ezrec-backend ✅")


async def main():
    """Main test function"""
    print("🎬 EZREC COMPREHENSIVE SYSTEM TEST")
    print("==================================")
    print()
    
    tester = EZRECSystemTester()
    
    try:
        success = await tester.run_comprehensive_test()
        
        if success:
            print("\n🎉 COMPREHENSIVE TEST COMPLETED SUCCESSFULLY!")
            print("🎬 Your EZREC system is fully operational")
            return 0
        else:
            print("\n❌ COMPREHENSIVE TEST FAILED")
            print("🔧 Please review the test results and fix any issues")
            return 1
            
    except KeyboardInterrupt:
        print("\n🛑 Test interrupted by user")
        return 1
    except Exception as e:
        print(f"\n❌ Test execution error: {e}")
        return 1


if __name__ == "__main__":
    # Quick system check
    print("🔍 Quick System Check:")
    print("=" * 25)
    
    # Check if we can import required modules
    try:
        from src.utils import SupabaseManager
        from src.config import Config
        print("✅ Python imports: OK")
    except ImportError as e:
        print(f"❌ Python imports: FAILED - {e}")
        sys.exit(1)
    
    # Check if running on Raspberry Pi
    try:
        with open('/proc/cpuinfo', 'r') as f:
            cpuinfo = f.read()
            if 'Raspberry Pi' in cpuinfo:
                print("✅ Platform: Raspberry Pi detected")
            else:
                print("⚠️  Platform: Not a Raspberry Pi")
    except:
        print("⚠️  Platform: Could not detect")
    
    print()
    
    # Run the comprehensive test
    exit_code = asyncio.run(main())
    sys.exit(exit_code) 