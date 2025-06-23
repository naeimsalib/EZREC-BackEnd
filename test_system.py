#!/usr/bin/env python3
"""
EZREC Backend System Test Suite
Comprehensive testing for camera functionality, configuration, and system health
"""
import os
import sys
import time
import json
import subprocess
import logging
from datetime import datetime
from typing import Dict, Any, List, Tuple

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

# Colors for output
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    PURPLE = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    END = '\033[0m'

class TestResult:
    def __init__(self, name: str, passed: bool, message: str, details: Dict = None):
        self.name = name
        self.passed = passed
        self.message = message
        self.details = details or {}
        self.timestamp = datetime.now()

class SystemTester:
    def __init__(self):
        self.results: List[TestResult] = []
        self.setup_logging()
    
    def setup_logging(self):
        """Setup logging for test results."""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def log_test(self, name: str, passed: bool, message: str, details: Dict = None):
        """Log a test result."""
        result = TestResult(name, passed, message, details)
        self.results.append(result)
        
        status_icon = f"{Colors.GREEN}✓{Colors.END}" if passed else f"{Colors.RED}✗{Colors.END}"
        status_color = Colors.GREEN if passed else Colors.RED
        
        print(f"{status_icon} {Colors.BOLD}{name}{Colors.END}: {status_color}{message}{Colors.END}")
        
        if details and not passed:
            for key, value in details.items():
                print(f"    {Colors.YELLOW}{key}:{Colors.END} {value}")
    
    def test_python_environment(self) -> bool:
        """Test Python environment and dependencies."""
        print(f"\n{Colors.BLUE}Testing Python Environment...{Colors.END}")
        
        # Test Python version
        python_version = sys.version_info
        if python_version.major >= 3 and python_version.minor >= 8:
            self.log_test("Python Version", True, f"Python {python_version.major}.{python_version.minor}.{python_version.micro}")
        else:
            self.log_test("Python Version", False, f"Python {python_version.major}.{python_version.minor} (requires 3.8+)")
            return False
        
        # Test required modules
        required_modules = [
            ('cv2', 'OpenCV'),
            ('numpy', 'NumPy'),
            ('psutil', 'PSUtil'),
            ('dotenv', 'Python-dotenv'),
        ]
        
        all_modules_ok = True
        for module, name in required_modules:
            try:
                __import__(module)
                self.log_test(f"{name} Import", True, "Available")
            except ImportError as e:
                self.log_test(f"{name} Import", False, "Not available", {"error": str(e)})
                all_modules_ok = False
        
        # Test optional Pi-specific modules
        optional_modules = [
            ('picamera2', 'Picamera2'),
        ]
        
        for module, name in optional_modules:
            try:
                __import__(module)
                self.log_test(f"{name} Import", True, "Available (Pi Camera support)")
            except ImportError:
                self.log_test(f"{name} Import", False, "Not available (Pi Camera not supported)")
        
        return all_modules_ok
    
    def test_configuration(self) -> bool:
        """Test configuration loading and validation."""
        print(f"\n{Colors.BLUE}Testing Configuration...{Colors.END}")
        
        try:
            from config import (
                SUPABASE_URL, SUPABASE_KEY, USER_ID, CAMERA_ID,
                RECORD_WIDTH, RECORD_HEIGHT, RECORD_FPS,
                BASE_DIR, TEMP_DIR, LOG_DIR, CONFIG_SUMMARY
            )
            
            self.log_test("Config Import", True, "Configuration loaded successfully")
            
            # Test required configuration
            config_tests = [
                ("SUPABASE_URL", SUPABASE_URL, lambda x: x and x.startswith('https')),
                ("SUPABASE_KEY", SUPABASE_KEY, lambda x: x and len(x) > 50),
                ("USER_ID", USER_ID, lambda x: x and len(x) > 0),
                ("CAMERA_ID", CAMERA_ID, lambda x: x and len(x) > 0),
                ("RECORD_WIDTH", RECORD_WIDTH, lambda x: x > 0),
                ("RECORD_HEIGHT", RECORD_HEIGHT, lambda x: x > 0),
                ("RECORD_FPS", RECORD_FPS, lambda x: 1 <= x <= 60),
            ]
            
            config_ok = True
            for name, value, validator in config_tests:
                try:
                    if validator(value):
                        self.log_test(f"Config {name}", True, f"Valid: {value}")
                    else:
                        self.log_test(f"Config {name}", False, f"Invalid: {value}")
                        config_ok = False
                except Exception as e:
                    self.log_test(f"Config {name}", False, f"Error: {e}")
                    config_ok = False
            
            # Test directory creation
            for dir_name, dir_path in [("TEMP_DIR", TEMP_DIR), ("LOG_DIR", LOG_DIR)]:
                if os.path.exists(dir_path):
                    self.log_test(f"Directory {dir_name}", True, f"Exists: {dir_path}")
                else:
                    self.log_test(f"Directory {dir_name}", False, f"Missing: {dir_path}")
                    config_ok = False
            
            return config_ok
            
        except Exception as e:
            self.log_test("Config Import", False, "Failed to import configuration", {"error": str(e)})
            return False
    
    def test_camera_detection(self) -> bool:
        """Test camera detection and functionality."""
        print(f"\n{Colors.BLUE}Testing Camera Detection...{Colors.END}")
        
        try:
            from find_camera import comprehensive_camera_scan, find_working_camera
            
            # Run comprehensive scan
            scan_results = comprehensive_camera_scan()
            summary = scan_results["summary"]
            
            self.log_test("Camera Scan", True, "Scan completed", scan_results)
            
            # Test Pi Camera
            pi_cam = scan_results["pi_camera"]
            if pi_cam["available"]:
                self.log_test("Pi Camera", True, f"Detected: {pi_cam['type']}")
            else:
                self.log_test("Pi Camera", False, "Not detected", {"error": pi_cam.get("error")})
            
            # Test USB Cameras
            usb_cameras = scan_results["usb_cameras"]
            if usb_cameras:
                working_usb = sum(1 for cam in usb_cameras if cam.get("working", False))
                self.log_test("USB Cameras", True, f"Found {len(usb_cameras)}, {working_usb} working")
            else:
                self.log_test("USB Cameras", False, "No USB cameras detected")
            
            # Test working camera
            working_camera = scan_results["working_camera"]
            if working_camera["status"] == "success":
                info = working_camera["camera_info"]
                self.log_test("Working Camera", True, 
                            f"Type: {info['camera_type']}, Resolution: {info['resolution']}")
                return True
            else:
                self.log_test("Working Camera", False, working_camera["message"])
                return False
                
        except Exception as e:
            self.log_test("Camera Detection", False, "Failed to test camera", {"error": str(e)})
            return False
    
    def test_camera_interface(self) -> bool:
        """Test camera interface functionality."""
        print(f"\n{Colors.BLUE}Testing Camera Interface...{Colors.END}")
        
        try:
            from camera_interface import CameraInterface
            
            # Initialize camera
            camera = CameraInterface()
            self.log_test("Camera Init", True, f"Camera type: {camera.camera_type}")
            
            # Test frame capture
            frame = camera.capture_frame()
            if frame is not None:
                self.log_test("Frame Capture", True, f"Frame shape: {frame.shape}")
            else:
                self.log_test("Frame Capture", False, "Failed to capture frame")
                camera.release()
                return False
            
            # Test camera info
            info = camera.get_camera_info()
            self.log_test("Camera Info", True, "Retrieved camera information", info)
            
            # Test health check
            health = camera.health_check()
            self.log_test("Camera Health", health, "Health check passed" if health else "Health check failed")
            
            # Test short recording (5 seconds)
            try:
                recording_path = camera.start_recording("test_recording.mp4")
                self.log_test("Recording Start", True, f"Started: {recording_path}")
                
                time.sleep(5)  # Record for 5 seconds
                
                final_path = camera.stop_recording()
                if final_path and os.path.exists(final_path):
                    file_size = os.path.getsize(final_path)
                    self.log_test("Recording Stop", True, f"Stopped: {file_size} bytes")
                    
                    # Clean up test file
                    try:
                        os.remove(final_path)
                    except:
                        pass
                else:
                    self.log_test("Recording Stop", False, "No recording file created")
                    
            except Exception as e:
                self.log_test("Recording Test", False, f"Recording failed: {e}")
            
            camera.release()
            return True
            
        except Exception as e:
            self.log_test("Camera Interface", False, "Failed to test interface", {"error": str(e)})
            return False
    
    def test_system_utilities(self) -> bool:
        """Test system utility functions."""
        print(f"\n{Colors.BLUE}Testing System Utilities...{Colors.END}")
        
        try:
            from utils import (
                get_system_metrics, get_cpu_temperature, get_ip_address,
                local_now, get_storage_used, validate_camera_access,
                get_system_info
            )
            
            # Test system metrics
            metrics = get_system_metrics()
            if metrics:
                self.log_test("System Metrics", True, f"Collected {len(metrics)} metrics")
            else:
                self.log_test("System Metrics", False, "No metrics collected")
            
            # Test temperature reading
            temp = get_cpu_temperature()
            if temp is not None:
                self.log_test("CPU Temperature", True, f"{temp}°C")
            else:
                self.log_test("CPU Temperature", False, "Temperature sensor not available")
            
            # Test IP address
            ip = get_ip_address()
            self.log_test("IP Address", True, f"Local IP: {ip}")
            
            # Test local time
            now = local_now()
            self.log_test("Local Time", True, f"Current time: {now}")
            
            # Test storage calculation
            storage = get_storage_used()
            self.log_test("Storage Calculation", True, f"Used: {storage} bytes")
            
            # Test camera validation
            camera_valid = validate_camera_access()
            self.log_test("Camera Validation", camera_valid, 
                         "Camera accessible" if camera_valid else "Camera not accessible")
            
            # Test system info
            sys_info = get_system_info()
            if "error" not in sys_info:
                self.log_test("System Info", True, f"Platform: {sys_info.get('platform', 'Unknown')}")
            else:
                self.log_test("System Info", False, "Failed to get system info")
            
            return True
            
        except Exception as e:
            self.log_test("System Utilities", False, "Failed to test utilities", {"error": str(e)})
            return False
    
    def test_supabase_connection(self) -> bool:
        """Test Supabase database connection."""
        print(f"\n{Colors.BLUE}Testing Supabase Connection...{Colors.END}")
        
        try:
            from utils import supabase, update_system_status
            
            if supabase is None:
                self.log_test("Supabase Client", False, "Client not initialized")
                return False
            
            self.log_test("Supabase Client", True, "Client initialized")
            
            # Test system status update
            try:
                success = update_system_status(
                    is_recording=False,
                    is_streaming=False,
                    storage_used=0
                )
                if success:
                    self.log_test("Status Update", True, "Successfully updated system status")
                else:
                    self.log_test("Status Update", False, "Failed to update system status")
                
                return success
                
            except Exception as e:
                self.log_test("Status Update", False, f"Error updating status: {e}")
                return False
                
        except Exception as e:
            self.log_test("Supabase Connection", False, "Failed to test connection", {"error": str(e)})
            return False
    
    def test_system_commands(self) -> bool:
        """Test system commands and tools."""
        print(f"\n{Colors.BLUE}Testing System Commands...{Colors.END}")
        
        commands = [
            ("libcamera-hello", ["libcamera-hello", "--version"], "Pi Camera tools"),
            ("v4l2-ctl", ["v4l2-ctl", "--version"], "Video4Linux tools"),
            ("ffmpeg", ["ffmpeg", "-version"], "FFmpeg"),
            ("python3", ["python3", "--version"], "Python3"),
        ]
        
        all_ok = True
        for name, cmd, description in commands:
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    version_line = result.stdout.split('\n')[0] if result.stdout else "Available"
                    self.log_test(f"Command {name}", True, f"{description}: {version_line}")
                else:
                    self.log_test(f"Command {name}", False, f"{description}: Command failed")
                    all_ok = False
            except subprocess.TimeoutExpired:
                self.log_test(f"Command {name}", False, f"{description}: Command timed out")
                all_ok = False
            except FileNotFoundError:
                self.log_test(f"Command {name}", False, f"{description}: Command not found")
                all_ok = False
            except Exception as e:
                self.log_test(f"Command {name}", False, f"{description}: Error - {e}")
                all_ok = False
        
        return all_ok
    
    def test_permissions(self) -> bool:
        """Test file and directory permissions."""
        print(f"\n{Colors.BLUE}Testing Permissions...{Colors.END}")
        
        try:
            from config import BASE_DIR, TEMP_DIR, LOG_DIR, RECORDING_DIR
            
            test_dirs = [
                ("BASE_DIR", BASE_DIR),
                ("TEMP_DIR", TEMP_DIR),
                ("LOG_DIR", LOG_DIR),
                ("RECORDING_DIR", RECORDING_DIR),
            ]
            
            all_ok = True
            for name, dir_path in test_dirs:
                try:
                    # Test write permission
                    test_file = os.path.join(dir_path, "test_write.tmp")
                    with open(test_file, "w") as f:
                        f.write("test")
                    os.remove(test_file)
                    
                    self.log_test(f"Permissions {name}", True, f"Read/Write OK: {dir_path}")
                    
                except Exception as e:
                    self.log_test(f"Permissions {name}", False, f"No write access: {dir_path}", {"error": str(e)})
                    all_ok = False
            
            return all_ok
            
        except Exception as e:
            self.log_test("Permissions Test", False, "Failed to test permissions", {"error": str(e)})
            return False
    
    def generate_report(self) -> Dict[str, Any]:
        """Generate comprehensive test report."""
        total_tests = len(self.results)
        passed_tests = sum(1 for r in self.results if r.passed)
        failed_tests = total_tests - passed_tests
        
        success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        
        report = {
            "timestamp": datetime.now().isoformat(),
            "total_tests": total_tests,
            "passed": passed_tests,
            "failed": failed_tests,
            "success_rate": round(success_rate, 2),
            "overall_status": "PASS" if failed_tests == 0 else "FAIL",
            "tests": [
                {
                    "name": r.name,
                    "passed": r.passed,
                    "message": r.message,
                    "details": r.details,
                    "timestamp": r.timestamp.isoformat()
                }
                for r in self.results
            ]
        }
        
        return report
    
    def print_summary(self):
        """Print test summary."""
        report = self.generate_report()
        
        print(f"\n{Colors.BOLD}{'='*60}{Colors.END}")
        print(f"{Colors.BOLD}EZREC BACKEND TEST SUMMARY{Colors.END}")
        print(f"{Colors.BOLD}{'='*60}{Colors.END}")
        
        status_color = Colors.GREEN if report["overall_status"] == "PASS" else Colors.RED
        print(f"Overall Status: {status_color}{Colors.BOLD}{report['overall_status']}{Colors.END}")
        print(f"Tests Run: {report['total_tests']}")
        print(f"Passed: {Colors.GREEN}{report['passed']}{Colors.END}")
        print(f"Failed: {Colors.RED}{report['failed']}{Colors.END}")
        print(f"Success Rate: {report['success_rate']:.1f}%")
        
        if report["failed"] > 0:
            print(f"\n{Colors.RED}Failed Tests:{Colors.END}")
            for test in report["tests"]:
                if not test["passed"]:
                    print(f"  • {test['name']}: {test['message']}")
        
        print(f"\n{Colors.BLUE}Recommendations:{Colors.END}")
        if report["overall_status"] == "PASS":
            print("  ✓ System is ready for deployment")
            print("  ✓ All core functionality is working")
            print("  ✓ Run 'sudo systemctl start ezrec-backend' to start the service")
        else:
            print("  ✗ Fix the failed tests before deployment")
            print("  ✗ Check configuration and dependencies")
            print("  ✗ Review installation logs for errors")
        
        print(f"{Colors.BOLD}{'='*60}{Colors.END}")
    
    def save_report(self, filename: str = None):
        """Save test report to file."""
        if filename is None:
            filename = f"ezrec_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        report = self.generate_report()
        
        try:
            with open(filename, "w") as f:
                json.dump(report, f, indent=2)
            print(f"Test report saved to: {filename}")
        except Exception as e:
            print(f"Failed to save report: {e}")
    
    def run_all_tests(self) -> bool:
        """Run all system tests."""
        print(f"{Colors.BOLD}EZREC Backend System Test Suite{Colors.END}")
        print(f"Starting comprehensive system validation...\n")
        
        test_functions = [
            self.test_python_environment,
            self.test_configuration,
            self.test_system_commands,
            self.test_permissions,
            self.test_system_utilities,
            self.test_camera_detection,
            self.test_camera_interface,
            self.test_supabase_connection,
        ]
        
        overall_success = True
        for test_func in test_functions:
            try:
                success = test_func()
                if not success:
                    overall_success = False
            except Exception as e:
                self.log_test(test_func.__name__, False, f"Test crashed: {e}")
                overall_success = False
            
            time.sleep(1)  # Brief pause between tests
        
        return overall_success

def main():
    """Main test function."""
    import argparse
    
    parser = argparse.ArgumentParser(description="EZREC Backend System Test Suite")
    parser.add_argument("--save-report", action="store_true", help="Save test report to file")
    parser.add_argument("--report-file", help="Custom report filename")
    parser.add_argument("--quick", action="store_true", help="Skip camera tests (faster)")
    
    args = parser.parse_args()
    
    tester = SystemTester()
    
    if args.quick:
        print("Running quick tests (skipping camera tests)...")
        # Run subset of tests
        test_functions = [
            tester.test_python_environment,
            tester.test_configuration,
            tester.test_system_commands,
            tester.test_permissions,
            tester.test_system_utilities,
        ]
        
        overall_success = True
        for test_func in test_functions:
            try:
                success = test_func()
                if not success:
                    overall_success = False
            except Exception as e:
                tester.log_test(test_func.__name__, False, f"Test crashed: {e}")
                overall_success = False
    else:
        overall_success = tester.run_all_tests()
    
    tester.print_summary()
    
    if args.save_report:
        tester.save_report(args.report_file)
    
    # Exit with appropriate code
    sys.exit(0 if overall_success else 1)

if __name__ == "__main__":
    main() 