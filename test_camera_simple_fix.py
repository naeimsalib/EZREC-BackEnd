#!/usr/bin/env python3
import cv2
import time
import os

def test_camera_with_delay(camera_index, delay=3):
    """Test camera with longer initialization delay"""
    print(f"Testing camera {camera_index} with {delay}s delay...")
    
    try:
        cap = cv2.VideoCapture(camera_index)
        if not cap.isOpened():
            print(f"  ❌ Camera {camera_index} not accessible")
            return False
        
        print(f"  ✅ Camera {camera_index} opened, waiting {delay} seconds...")
        time.sleep(delay)
        
        # Set basic properties
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)
        
        # Try to read multiple frames with delays
        for i in range(10):
            ret, frame = cap.read()
            if ret and frame is not None and frame.size > 0:
                print(f"  ✅ Camera {camera_index} working! Frame {i+1}: {frame.shape}")
                cap.release()
                return True
            time.sleep(0.3)
        
        cap.release()
        print(f"  ❌ Camera {camera_index} still not capturing frames")
        return False
        
    except Exception as e:
        print(f"  ❌ Camera {camera_index} error: {str(e)}")
        return False

def test_camera_with_backend(camera_index, backend):
    """Test camera with specific backend"""
    print(f"Testing camera {camera_index} with backend {backend}...")
    
    try:
        cap = cv2.VideoCapture(camera_index, backend)
        if not cap.isOpened():
            print(f"  ❌ Camera {camera_index} not accessible with backend {backend}")
            return False
        
        print(f"  ✅ Camera {camera_index} opened with backend {backend}")
        
        # Set properties
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)
        
        # Wait and try to read frames
        time.sleep(1)
        for i in range(5):
            ret, frame = cap.read()
            if ret and frame is not None and frame.size > 0:
                print(f"  ✅ Camera {camera_index} works with backend {backend}! Frame: {frame.shape}")
                cap.release()
                return True
            time.sleep(0.2)
        
        cap.release()
        print(f"  ❌ Camera {camera_index} opened but no frames with backend {backend}")
        return False
        
    except Exception as e:
        print(f"  ❌ Camera {camera_index} error with backend {backend}: {str(e)}")
        return False

def main():
    print("🔧 Simple Camera Fix Test")
    print("=========================")
    
    # Test cameras 0 and 3 (which opened successfully before)
    working_cameras = []
    
    for camera_index in [0, 3]:
        print(f"\n--- Testing Camera {camera_index} ---")
        
        # Method 1: Test with longer delay
        if test_camera_with_delay(camera_index, 3):
            working_cameras.append(camera_index)
            continue
        
        # Method 2: Test with different backends
        backends = [cv2.CAP_V4L2, cv2.CAP_V4L, cv2.CAP_ANY]
        for backend in backends:
            if test_camera_with_backend(camera_index, backend):
                working_cameras.append(camera_index)
                break
        
        # Method 3: Test with even longer delay
        if camera_index not in working_cameras:
            if test_camera_with_delay(camera_index, 5):
                working_cameras.append(camera_index)
    
    # Results
    print(f"\n{'='*50}")
    if working_cameras:
        print(f"✅ SUCCESS: Found {len(working_cameras)} working camera(s)")
        for camera in working_cameras:
            print(f"  - Camera index: {camera}")
        
        # Save the first working camera
        with open('/tmp/working_camera_index.txt', 'w') as f:
            f.write(str(working_cameras[0]))
        
        print(f"\nCamera index {working_cameras[0]} saved to /tmp/working_camera_index.txt")
        print("You can now use this camera index in your application!")
        
    else:
        print("❌ FAILED: No working camera found")
        print("\nTroubleshooting suggestions:")
        print("1. Try rebooting: sudo reboot")
        print("2. Check camera connection")
        print("3. Try different camera cable")
        print("4. Check if camera is enabled in raspi-config")

if __name__ == "__main__":
    main() 