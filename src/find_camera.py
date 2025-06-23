#!/usr/bin/env python3
"""
EZREC Camera Detection Utility - Optimized for Raspberry Pi
Detects available cameras and provides detailed information about their capabilities
"""
import os
import sys
import time
import logging
import subprocess
from typing import Dict, List, Optional, Any

# Add the src directory to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from camera_interface import CameraInterface, detect_cameras

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def detect_pi_camera() -> Dict[str, Any]:
    """Detect Pi Camera using libcamera tools."""
    camera_info = {
        "available": False,
        "type": None,
        "supported_modes": [],
        "error": None
    }
    
    try:
        # Use libcamera-hello to detect Pi Camera
        result = subprocess.run(
            ["libcamera-hello", "--list-cameras", "--timeout", "100"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            output = result.stdout
            if "Available cameras" in output:
                camera_info["available"] = True
                camera_info["type"] = "Pi Camera"
                
                # Parse camera modes if available
                lines = output.split('\n')
                for line in lines:
                    if 'Modes:' in line or 'x' in line and 'fps' in line:
                        camera_info["supported_modes"].append(line.strip())
                        
                logger.info("Pi Camera detected successfully")
            else:
                camera_info["error"] = "No Pi Camera found in libcamera output"
        else:
            camera_info["error"] = f"libcamera-hello failed: {result.stderr}"
            
    except subprocess.TimeoutExpired:
        camera_info["error"] = "libcamera-hello timed out"
        logger.warning("Pi Camera detection timed out")
    except FileNotFoundError:
        camera_info["error"] = "libcamera-hello not found (install libcamera-apps)"
        logger.warning("libcamera-hello command not found")
    except Exception as e:
        camera_info["error"] = f"Unexpected error: {e}"
        logger.error(f"Pi Camera detection failed: {e}")
    
    return camera_info

def detect_usb_cameras() -> List[Dict[str, Any]]:
    """Detect USB cameras using v4l2-ctl."""
    cameras = []
    
    try:
        # List video devices
        result = subprocess.run(
            ["v4l2-ctl", "--list-devices"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            output = result.stdout
            device_blocks = output.split('\n\n')
            
            for block in device_blocks:
                if block.strip() and '/dev/video' in block:
                    lines = block.strip().split('\n')
                    if len(lines) >= 2:
                        camera_name = lines[0].strip()
                        device_path = None
                        
                        # Find the device path
                        for line in lines[1:]:
                            if '/dev/video' in line:
                                device_path = line.strip()
                                break
                        
                        if device_path:
                            camera_info = {
                                "name": camera_name,
                                "device": device_path,
                                "capabilities": [],
                                "formats": []
                            }
                            
                            # Get detailed info for this device
                            detailed_info = get_usb_camera_details(device_path)
                            camera_info.update(detailed_info)
                            
                            cameras.append(camera_info)
                            logger.info(f"USB camera detected: {camera_name} at {device_path}")
                            
    except subprocess.TimeoutExpired:
        logger.warning("USB camera detection timed out")
    except FileNotFoundError:
        logger.warning("v4l2-ctl not found (install v4l-utils)")
    except Exception as e:
        logger.error(f"USB camera detection failed: {e}")
    
    return cameras

def get_usb_camera_details(device_path: str) -> Dict[str, Any]:
    """Get detailed information about a USB camera."""
    details = {
        "capabilities": [],
        "formats": [],
        "working": False
    }
    
    try:
        # Get camera capabilities
        result = subprocess.run(
            ["v4l2-ctl", "-d", device_path, "--list-ctrls"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            # Parse capabilities (simplified)
            for line in result.stdout.split('\n'):
                if 'brightness' in line.lower():
                    details["capabilities"].append("brightness_control")
                elif 'contrast' in line.lower():
                    details["capabilities"].append("contrast_control")
                elif 'saturation' in line.lower():
                    details["capabilities"].append("saturation_control")
        
        # Get supported formats
        result = subprocess.run(
            ["v4l2-ctl", "-d", device_path, "--list-formats-ext"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            current_format = None
            for line in result.stdout.split('\n'):
                if 'Pixel Format:' in line:
                    current_format = line.split("'")[1] if "'" in line else "Unknown"
                elif 'Size:' in line and current_format:
                    size_info = line.strip()
                    details["formats"].append(f"{current_format}: {size_info}")
        
        # Test if camera is working
        details["working"] = test_camera_functionality(device_path)
        
    except Exception as e:
        logger.warning(f"Failed to get details for {device_path}: {e}")
    
    return details

def test_camera_functionality(device_path: str) -> bool:
    """Test if a camera device is actually functional."""
    try:
        import cv2
        
        # Extract device index from path
        device_index = int(device_path.split('video')[-1])
        
        cap = cv2.VideoCapture(device_index)
        if cap.isOpened():
            ret, frame = cap.read()
            cap.release()
            return ret and frame is not None
        
        return False
        
    except Exception as e:
        logger.warning(f"Camera functionality test failed for {device_path}: {e}")
        return False

def find_working_camera() -> Optional[Dict[str, Any]]:
    """Find the first working camera and return its information."""
    try:
        # Try to initialize camera interface
        camera = CameraInterface()
        info = camera.get_camera_info()
        camera.release()
        
        logger.info(f"Working camera found: {info['camera_type']}")
        return {
            "status": "success",
            "camera_info": info,
            "message": f"Camera working: type={info['camera_type']}"
        }
        
    except Exception as e:
        logger.error(f"No working camera found: {e}")
        return {
            "status": "error",
            "camera_info": None,
            "message": f"No working camera found: {e}"
        }

def comprehensive_camera_scan() -> Dict[str, Any]:
    """Perform a comprehensive scan of all available cameras."""
    scan_results = {
        "pi_camera": detect_pi_camera(),
        "usb_cameras": detect_usb_cameras(),
        "opencv_detection": detect_cameras(),
        "working_camera": find_working_camera(),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    }
    
    # Summary
    total_cameras = 0
    if scan_results["pi_camera"]["available"]:
        total_cameras += 1
    total_cameras += len(scan_results["usb_cameras"])
    
    scan_results["summary"] = {
        "total_detected": total_cameras,
        "pi_camera_available": scan_results["pi_camera"]["available"],
        "usb_cameras_count": len(scan_results["usb_cameras"]),
        "has_working_camera": scan_results["working_camera"]["status"] == "success"
    }
    
    return scan_results

def print_camera_report(scan_results: Dict[str, Any]):
    """Print a formatted report of the camera scan."""
    print("\n" + "="*60)
    print("EZREC CAMERA DETECTION REPORT")
    print("="*60)
    print(f"Scan Time: {scan_results['timestamp']}")
    print()
    
    # Summary
    summary = scan_results["summary"]
    print("SUMMARY:")
    print(f"  Total Cameras Detected: {summary['total_detected']}")
    print(f"  Pi Camera Available: {'Yes' if summary['pi_camera_available'] else 'No'}")
    print(f"  USB Cameras Found: {summary['usb_cameras_count']}")
    print(f"  Working Camera Found: {'Yes' if summary['has_working_camera'] else 'No'}")
    print()
    
    # Pi Camera Details
    pi_cam = scan_results["pi_camera"]
    print("PI CAMERA:")
    if pi_cam["available"]:
        print(f"  Status: Available ({pi_cam['type']})")
        if pi_cam["supported_modes"]:
            print("  Supported Modes:")
            for mode in pi_cam["supported_modes"][:5]:  # Limit output
                print(f"    {mode}")
    else:
        print(f"  Status: Not Available")
        if pi_cam["error"]:
            print(f"  Error: {pi_cam['error']}")
    print()
    
    # USB Cameras
    print("USB CAMERAS:")
    if scan_results["usb_cameras"]:
        for i, cam in enumerate(scan_results["usb_cameras"], 1):
            print(f"  Camera {i}: {cam['name']}")
            print(f"    Device: {cam['device']}")
            print(f"    Working: {'Yes' if cam['working'] else 'No'}")
            if cam["capabilities"]:
                print(f"    Capabilities: {', '.join(cam['capabilities'])}")
            if cam["formats"]:
                print(f"    Formats: {len(cam['formats'])} supported")
    else:
        print("  No USB cameras detected")
    print()
    
    # Working Camera
    working = scan_results["working_camera"]
    print("ACTIVE CAMERA:")
    if working["status"] == "success":
        info = working["camera_info"]
        print(f"  Type: {info['camera_type']}")
        print(f"  Resolution: {info['resolution']}")
        print(f"  FPS: {info['fps']}")
        print(f"  Status: Ready for recording")
    else:
        print(f"  Status: No working camera available")
        print(f"  Error: {working['message']}")
    
    print("="*60)

def main():
    """Main function for standalone camera detection."""
    print("EZREC Camera Detection Utility")
    print("Scanning for available cameras...")
    
    # Perform comprehensive scan
    results = comprehensive_camera_scan()
    
    # Print detailed report
    print_camera_report(results)
    
    # Return appropriate exit code
    if results["summary"]["has_working_camera"]:
        print("\n✓ Camera detection successful!")
        return 0
    else:
        print("\n✗ No working camera found!")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 