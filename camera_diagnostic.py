#!/usr/bin/env python3
"""
EZREC Camera Diagnostic Tool
Run this script on the Raspberry Pi to diagnose camera issues.
"""

import os
import sys
import subprocess
import json
from datetime import datetime

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

def run_command(cmd, description=""):
    """Run a system command and return output."""
    print(f"\n{'='*60}")
    print(f"CHECKING: {description}")
    print(f"COMMAND: {cmd}")
    print(f"{'='*60}")
    
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        print(f"Exit Code: {result.returncode}")
        
        if result.stdout:
            print(f"STDOUT:\n{result.stdout}")
        if result.stderr:
            print(f"STDERR:\n{result.stderr}")
            
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        print("TIMEOUT: Command took too long")
        return False, "", "Command timeout"
    except Exception as e:
        print(f"ERROR: {e}")
        return False, "", str(e)

def check_system_info():
    """Check basic system information."""
    print("\n" + "="*80)
    print("SYSTEM INFORMATION")
    print("="*80)
    
    run_command("uname -a", "System information")
    run_command("cat /etc/os-release", "OS version")
    run_command("python3 --version", "Python version")
    run_command("vcgencmd version", "VideoCore version (Pi-specific)")
    run_command("vcgencmd get_camera", "Pi Camera detection")

def check_video_devices():
    """Check for video devices."""
    print("\n" + "="*80)
    print("VIDEO DEVICE DETECTION")
    print("="*80)
    
    run_command("ls -la /dev/video*", "Video devices")
    run_command("lsusb", "USB devices")
    run_command("v4l2-ctl --list-devices", "V4L2 devices")
    
    # Check each video device
    for i in range(8):
        success, stdout, stderr = run_command(f"v4l2-ctl --device=/dev/video{i} --list-formats", f"Video{i} formats")
        if success:
            run_command(f"v4l2-ctl --device=/dev/video{i} --list-framesizes=YUYV", f"Video{i} frame sizes")

def check_camera_modules():
    """Check if camera modules are loaded."""
    print("\n" + "="*80)
    print("CAMERA MODULE STATUS")
    print("="*80)
    
    run_command("lsmod | grep -i camera", "Camera modules")
    run_command("lsmod | grep -i video", "Video modules")
    run_command("lsmod | grep -i uvc", "UVC modules")
    run_command("dmesg | grep -i camera | tail -10", "Recent camera messages")
    run_command("dmesg | grep -i usb | grep -i video | tail -5", "Recent USB video messages")

def check_permissions():
    """Check file permissions and user groups."""
    print("\n" + "="*80)
    print("PERMISSIONS AND GROUPS")
    print("="*80)
    
    run_command("whoami", "Current user")
    run_command("groups", "User groups")
    run_command("ls -la /dev/video*", "Video device permissions")
    run_command("getfacl /dev/video0 2>/dev/null || echo 'No ACL or device not found'", "Video0 ACL")

def check_config_files():
    """Check camera configuration files."""
    print("\n" + "="*80)
    print("CONFIGURATION FILES")
    print("="*80)
    
    run_command("cat /boot/config.txt | grep -i camera", "Boot config camera settings")
    run_command("raspi-config nonint get_camera", "Pi camera enable status")

def test_python_camera():
    """Test camera access through Python."""
    print("\n" + "="*80)
    print("PYTHON CAMERA TESTS")
    print("="*80)
    
    # Test OpenCV
    print("\nTesting OpenCV camera access...")
    opencv_test = """
import cv2
import sys

try:
    print("Testing OpenCV camera access...")
    for i in range(4):
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            ret, frame = cap.read()
            if ret and frame is not None:
                print(f"✓ Camera {i}: Working - Frame shape: {frame.shape}")
            else:
                print(f"✗ Camera {i}: Opened but no frame")
            cap.release()
        else:
            print(f"✗ Camera {i}: Cannot open")
except Exception as e:
    print(f"OpenCV test failed: {e}")
"""
    
    success, stdout, stderr = run_command(f"python3 -c '{opencv_test}'", "OpenCV camera test")
    
    # Test picamera2 if available
    print("\nTesting picamera2...")
    picamera_test = """
try:
    from picamera2 import Picamera2
    print("✓ picamera2 imported successfully")
    
    try:
        picam = Picamera2()
        camera_config = picam.create_preview_configuration()
        picam.configure(camera_config)
        picam.start()
        frame = picam.capture_array()
        print(f"✓ Pi Camera: Working - Frame shape: {frame.shape}")
        picam.stop()
        picam.close()
    except Exception as e:
        print(f"✗ Pi Camera test failed: {e}")
        
except ImportError:
    print("✗ picamera2 not available")
except Exception as e:
    print(f"✗ picamera2 test failed: {e}")
"""
    
    run_command(f"python3 -c '{picamera_test}'", "Picamera2 test")

def test_ezrec_camera():
    """Test EZREC camera interface specifically."""
    print("\n" + "="*80)
    print("EZREC CAMERA INTERFACE TEST")
    print("="*80)
    
    try:
        from src.camera_interface import CameraInterface, detect_cameras, test_camera_interface
        
        print("Testing camera detection...")
        cameras = detect_cameras()
        print(f"Detected cameras: {json.dumps(cameras, indent=2)}")
        
        print("\nTesting camera interface...")
        success = test_camera_interface()
        print(f"Camera interface test: {'PASSED' if success else 'FAILED'}")
        
    except Exception as e:
        print(f"EZREC camera test failed: {e}")

def generate_report():
    """Generate a comprehensive diagnostic report."""
    print("\n" + "="*80)
    print("DIAGNOSTIC REPORT SUMMARY")
    print("="*80)
    
    report = {
        "timestamp": datetime.now().isoformat(),
        "recommendations": []
    }
    
    # Check for common issues and provide recommendations
    success, stdout, stderr = run_command("ls /dev/video*", "")
    if not success:
        report["recommendations"].append("No video devices found. Check camera connection and drivers.")
    
    success, stdout, stderr = run_command("groups | grep video", "")
    if not success:
        report["recommendations"].append("User not in 'video' group. Run: sudo usermod -a -G video $USER")
    
    success, stdout, stderr = run_command("vcgencmd get_camera", "")
    if "detected=0" in stdout:
        report["recommendations"].append("Pi Camera not detected. Check cable connection and /boot/config.txt")
    
    if not report["recommendations"]:
        report["recommendations"].append("All basic checks passed. Issue may be software-related.")
    
    print("\nRECOMMENDATIONS:")
    for i, rec in enumerate(report["recommendations"], 1):
        print(f"{i}. {rec}")
    
    # Save report
    try:
        with open("camera_diagnostic_report.json", "w") as f:
            json.dump(report, f, indent=2)
        print(f"\nFull report saved to: camera_diagnostic_report.json")
    except Exception as e:
        print(f"Could not save report: {e}")

def main():
    """Run complete camera diagnostic."""
    print("EZREC Camera Diagnostic Tool")
    print(f"Started at: {datetime.now()}")
    print("This will check camera hardware, drivers, and software configuration.")
    
    try:
        check_system_info()
        check_video_devices()
        check_camera_modules()
        check_permissions()
        check_config_files()
        test_python_camera()
        test_ezrec_camera()
        generate_report()
        
    except KeyboardInterrupt:
        print("\n\nDiagnostic interrupted by user.")
    except Exception as e:
        print(f"\n\nDiagnostic failed with error: {e}")
    
    print(f"\nDiagnostic completed at: {datetime.now()}")
    print("\nTo run this diagnostic on your Raspberry Pi:")
    print("1. Copy this script to your Pi")
    print("2. Run: python3 camera_diagnostic.py")
    print("3. Send the output to help diagnose camera issues")

if __name__ == "__main__":
    main() 