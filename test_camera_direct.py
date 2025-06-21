#!/usr/bin/env python3
import cv2
import time
import subprocess
import os

def test_camera_direct_read():
    """Test camera by directly reading from device"""
    print("🔍 Direct Camera Device Test")
    print("============================")
    
    # Check if we can read from video devices
    for i in range(5):
        device = f"/dev/video{i}"
        if os.path.exists(device):
            print(f"\n📹 Testing {device}...")
            
            try:
                # Try to open the device file directly
                with open(device, 'rb') as f:
                    # Try to read a small amount of data
                    data = f.read(1024)
                    if data:
                        print(f"  ✅ Can read from {device} (got {len(data)} bytes)")
                    else:
                        print(f"  ❌ No data from {device}")
            except Exception as e:
                print(f"  ❌ Cannot read from {device}: {str(e)}")

def test_camera_with_simple_cv2():
    """Test camera with minimal OpenCV setup"""
    print("\n📹 Simple OpenCV Test")
    print("=====================")
    
    for camera_index in [0, 3]:
        print(f"\n--- Testing Camera {camera_index} ---")
        
        try:
            # Open camera with minimal setup
            cap = cv2.VideoCapture(camera_index)
            if not cap.isOpened():
                print(f"  ❌ Cannot open camera {camera_index}")
                continue
            
            print(f"  ✅ Camera {camera_index} opened")
            
            # Don't set any properties, just try to read
            print("  📸 Trying to read frames...")
            
            for i in range(5):
                ret, frame = cap.read()
                print(f"    Frame {i+1}: ret={ret}, frame={'None' if frame is None else f'{frame.shape}'}")
                
                if ret and frame is not None:
                    print(f"  ✅ SUCCESS! Camera {camera_index} is working!")
                    print(f"    Frame shape: {frame.shape}")
                    print(f"    Frame type: {type(frame)}")
                    cap.release()
                    return True
                
                time.sleep(1)
            
            cap.release()
            print(f"  ❌ Camera {camera_index} opened but no frames")
            
        except Exception as e:
            print(f"  ❌ Error with camera {camera_index}: {str(e)}")
    
    return False

def test_camera_with_different_backends():
    """Test camera with different OpenCV backends"""
    print("\n🔧 Backend Test")
    print("===============")
    
    backends = [
        ("Default", cv2.CAP_ANY),
        ("V4L2", cv2.CAP_V4L2),
        ("V4L", cv2.CAP_V4L),
        ("GSTREAMER", cv2.CAP_GSTREAMER),
    ]
    
    for name, backend in backends:
        print(f"\n--- Testing {name} Backend ---")
        
        try:
            cap = cv2.VideoCapture(0, backend)
            if cap.isOpened():
                print(f"  ✅ Camera opened with {name} backend")
                
                # Try to read a frame
                ret, frame = cap.read()
                if ret and frame is not None:
                    print(f"  ✅ SUCCESS! {name} backend works!")
                    print(f"    Frame shape: {frame.shape}")
                    cap.release()
                    return True
                else:
                    print(f"  ❌ {name} backend opened but no frames")
                
                cap.release()
            else:
                print(f"  ❌ Cannot open camera with {name} backend")
                
        except Exception as e:
            print(f"  ❌ Error with {name} backend: {str(e)}")
    
    return False

def test_camera_with_timeout():
    """Test camera with longer timeout"""
    print("\n⏰ Timeout Test")
    print("==============")
    
    try:
        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            print("  ❌ Cannot open camera")
            return False
        
        print("  ✅ Camera opened")
        print("  ⏰ Waiting 10 seconds for camera to initialize...")
        
        # Wait longer for camera to initialize
        time.sleep(10)
        
        print("  📸 Trying to read frames after timeout...")
        
        for i in range(10):
            ret, frame = cap.read()
            print(f"    Frame {i+1}: ret={ret}, frame={'None' if frame is None else f'{frame.shape}'}")
            
            if ret and frame is not None:
                print("  ✅ SUCCESS! Camera works after timeout!")
                cap.release()
                return True
            
            time.sleep(0.5)
        
        cap.release()
        print("  ❌ Camera still not working after timeout")
        return False
        
    except Exception as e:
        print(f"  ❌ Error in timeout test: {str(e)}")
        return False

def main():
    print("🔍 Comprehensive Camera Debug")
    print("=============================")
    
    # Test 1: Direct device read
    test_camera_direct_read()
    
    # Test 2: Simple OpenCV
    if test_camera_with_simple_cv2():
        print("\n🎉 Camera is working with simple OpenCV!")
        return
    
    # Test 3: Different backends
    if test_camera_with_different_backends():
        print("\n🎉 Camera is working with specific backend!")
        return
    
    # Test 4: Timeout test
    if test_camera_with_timeout():
        print("\n🎉 Camera is working after timeout!")
        return
    
    print("\n❌ No working camera method found")
    print("\nThis suggests the camera might have a hardware issue or")
    print("needs to be enabled in raspi-config.")

if __name__ == "__main__":
    main() 