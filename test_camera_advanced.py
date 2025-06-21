#!/usr/bin/env python3
import cv2
import time
import os
import subprocess
import sys

def test_libcamera():
    """Test camera with libcamera-still"""
    print("Testing with libcamera-still...")
    
    try:
        # Check if libcamera-still is available
        result = subprocess.run(['which', 'libcamera-still'], capture_output=True, text=True)
        if result.returncode != 0:
            print("  ❌ libcamera-still not found")
            return False
        
        # Try to take a photo
        result = subprocess.run([
            'libcamera-still', 
            '--timeout', '3000',
            '--output', '/tmp/libcamera_test.jpg',
            '--nopreview'
        ], capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0 and os.path.exists('/tmp/libcamera_test.jpg'):
            print("  ✅ libcamera-still works!")
            print(f"  📸 Photo saved: /tmp/libcamera_test.jpg")
            return True
        else:
            print(f"  ❌ libcamera-still failed: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"  ❌ libcamera-still error: {str(e)}")
        return False

def test_camera_with_formats(camera_index):
    """Test camera with different pixel formats"""
    print(f"Testing camera {camera_index} with different formats...")
    
    # Common formats for Raspberry Pi camera
    formats = [
        ('YUYV', cv2.CAP_V4L2),
        ('MJPG', cv2.CAP_V4L2),
        ('RGB3', cv2.CAP_V4L2),
        ('BGR3', cv2.CAP_V4L2),
        ('GREY', cv2.CAP_V4L2),
    ]
    
    for format_name, backend in formats:
        print(f"  Testing format: {format_name}")
        try:
            cap = cv2.VideoCapture(camera_index, backend)
            if not cap.isOpened():
                print(f"    ❌ Could not open camera {camera_index}")
                continue
            
            # Set format-specific properties
            if format_name == 'MJPG':
                cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc('M', 'J', 'P', 'G'))
            elif format_name == 'YUYV':
                cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc('Y', 'U', 'Y', 'V'))
            
            # Set basic properties
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            cap.set(cv2.CAP_PROP_FPS, 30)
            
            # Wait for camera to initialize
            time.sleep(2)
            
            # Try to read frames
            for i in range(10):
                ret, frame = cap.read()
                if ret and frame is not None and frame.size > 0:
                    print(f"    ✅ Camera {camera_index} works with {format_name}! Frame: {frame.shape}")
                    cap.release()
                    return True, format_name
                time.sleep(0.2)
            
            cap.release()
            print(f"    ❌ Camera {camera_index} failed with {format_name}")
            
        except Exception as e:
            print(f"    ❌ Camera {camera_index} error with {format_name}: {str(e)}")
    
    return False, None

def test_camera_with_v4l2_ctl(camera_index):
    """Test camera using v4l2-ctl to set format"""
    print(f"Testing camera {camera_index} with v4l2-ctl...")
    
    try:
        # Check available formats
        result = subprocess.run([
            'v4l2-ctl', '-d', f'/dev/video{camera_index}', '--list-formats-ext'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f"  Available formats for camera {camera_index}:")
            print(result.stdout)
        
        # Try to set format to MJPG
        result = subprocess.run([
            'v4l2-ctl', '-d', f'/dev/video{camera_index}', 
            '--set-fmt-video=width=640,height=480,pixelformat=MJPG'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f"  ✅ Set MJPG format for camera {camera_index}")
            
            # Now test with OpenCV
            cap = cv2.VideoCapture(camera_index)
            if cap.isOpened():
                time.sleep(2)
                ret, frame = cap.read()
                if ret and frame is not None:
                    print(f"  ✅ Camera {camera_index} works after v4l2-ctl setup! Frame: {frame.shape}")
                    cap.release()
                    return True
                cap.release()
        
        print(f"  ❌ v4l2-ctl setup failed for camera {camera_index}")
        return False
        
    except Exception as e:
        print(f"  ❌ v4l2-ctl error: {str(e)}")
        return False

def test_camera_with_raspistill():
    """Test camera with raspistill (legacy camera stack)"""
    print("Testing with raspistill...")
    
    try:
        result = subprocess.run(['which', 'raspistill'], capture_output=True, text=True)
        if result.returncode != 0:
            print("  ❌ raspistill not found")
            return False
        
        result = subprocess.run([
            'raspistill', 
            '-t', '3000',
            '-o', '/tmp/raspistill_test.jpg',
            '-n'
        ], capture_output=True, text=True, timeout=10)
        
        if result.returncode == 0 and os.path.exists('/tmp/raspistill_test.jpg'):
            print("  ✅ raspistill works!")
            print(f"  📸 Photo saved: /tmp/raspistill_test.jpg")
            return True
        else:
            print(f"  ❌ raspistill failed: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"  ❌ raspistill error: {str(e)}")
        return False

def test_camera_with_different_resolutions(camera_index):
    """Test camera with different resolutions"""
    print(f"Testing camera {camera_index} with different resolutions...")
    
    resolutions = [
        (320, 240),
        (640, 480),
        (1280, 720),
        (1920, 1080)
    ]
    
    for width, height in resolutions:
        print(f"  Testing {width}x{height}...")
        try:
            cap = cv2.VideoCapture(camera_index)
            if cap.isOpened():
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
                cap.set(cv2.CAP_PROP_FPS, 30)
                
                time.sleep(2)
                
                ret, frame = cap.read()
                if ret and frame is not None and frame.size > 0:
                    print(f"    ✅ Camera {camera_index} works at {width}x{height}! Frame: {frame.shape}")
                    cap.release()
                    return True, (width, height)
                
                cap.release()
                print(f"    ❌ Camera {camera_index} failed at {width}x{height}")
            
        except Exception as e:
            print(f"    ❌ Camera {camera_index} error at {width}x{height}: {str(e)}")
    
    return False, None

def main():
    print("🔧 Advanced Camera Test")
    print("=======================")
    
    working_cameras = []
    
    # Test 1: Try libcamera first
    print("\n--- Test 1: libcamera ---")
    if test_libcamera():
        print("✅ libcamera works! Camera is functional")
        working_cameras.append("libcamera")
    
    # Test 2: Try raspistill
    print("\n--- Test 2: raspistill ---")
    if test_raspistill():
        print("✅ raspistill works! Camera is functional")
        working_cameras.append("raspistill")
    
    # Test 3: Test OpenCV with different formats
    print("\n--- Test 3: OpenCV with different formats ---")
    for camera_index in [0, 3]:
        success, format_name = test_camera_with_formats(camera_index)
        if success:
            working_cameras.append(f"opencv_{camera_index}_{format_name}")
    
    # Test 4: Test with v4l2-ctl setup
    print("\n--- Test 4: v4l2-ctl setup ---")
    for camera_index in [0, 3]:
        if test_camera_with_v4l2_ctl(camera_index):
            working_cameras.append(f"v4l2_{camera_index}")
    
    # Test 5: Test different resolutions
    print("\n--- Test 5: Different resolutions ---")
    for camera_index in [0, 3]:
        success, resolution = test_camera_with_different_resolutions(camera_index)
        if success:
            working_cameras.append(f"res_{camera_index}_{resolution[0]}x{resolution[1]}")
    
    # Results
    print(f"\n{'='*60}")
    if working_cameras:
        print(f"✅ SUCCESS: Found {len(working_cameras)} working camera method(s)")
        for method in working_cameras:
            print(f"  - {method}")
        
        # Save the first working method
        with open('/tmp/working_camera_method.txt', 'w') as f:
            f.write(working_cameras[0])
        
        print(f"\nWorking method saved to /tmp/working_camera_method.txt")
        print("You can now use this method in your application!")
        
    else:
        print("❌ FAILED: No working camera method found")
        print("\nTroubleshooting suggestions:")
        print("1. Check if camera is properly connected")
        print("2. Try: sudo raspi-config > Interface Options > Camera > Enable")
        print("3. Reboot: sudo reboot")
        print("4. Check camera cable connection")
        print("5. Try a different camera module")

if __name__ == "__main__":
    main() 