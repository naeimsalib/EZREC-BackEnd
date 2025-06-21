#!/usr/bin/env python3
import cv2
import time
import subprocess
import os

def test_libcamera():
    """Quick libcamera test"""
    print("📸 Testing libcamera-still...")
    try:
        result = subprocess.run(['libcamera-still', '--timeout', '2000', '--output', '/tmp/test.jpg', '--nopreview'], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0 and os.path.exists('/tmp/test.jpg'):
            print("✅ libcamera-still works!")
            return True
        else:
            print("❌ libcamera-still failed")
            return False
    except:
        print("❌ libcamera-still not available")
        return False

def test_raspistill():
    """Quick raspistill test"""
    print("📸 Testing raspistill...")
    try:
        result = subprocess.run(['raspistill', '-t', '2000', '-o', '/tmp/test2.jpg', '-n'], 
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0 and os.path.exists('/tmp/test2.jpg'):
            print("✅ raspistill works!")
            return True
        else:
            print("❌ raspistill failed")
            return False
    except:
        print("❌ raspistill not available")
        return False

def test_opencv_manual(camera_index):
    """Manual OpenCV test with different approaches"""
    print(f"📹 Testing OpenCV camera {camera_index}...")
    
    # Try different approaches
    approaches = [
        ("Basic", lambda: cv2.VideoCapture(camera_index)),
        ("V4L2", lambda: cv2.VideoCapture(camera_index, cv2.CAP_V4L2)),
        ("V4L", lambda: cv2.VideoCapture(camera_index, cv2.CAP_V4L)),
    ]
    
    for name, create_cap in approaches:
        print(f"  Trying {name} approach...")
        try:
            cap = create_cap()
            if cap.isOpened():
                print(f"    ✅ Camera {camera_index} opened with {name}")
                
                # Set properties
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                cap.set(cv2.CAP_PROP_FPS, 30)
                
                # Wait longer
                print("    Waiting 3 seconds...")
                time.sleep(3)
                
                # Try to read frames
                for i in range(5):
                    ret, frame = cap.read()
                    if ret and frame is not None and frame.size > 0:
                        print(f"    ✅ SUCCESS! Frame {i+1}: {frame.shape}")
                        cap.release()
                        return True
                    time.sleep(0.5)
                
                print(f"    ❌ Camera {camera_index} opened but no frames with {name}")
                cap.release()
            else:
                print(f"    ❌ Camera {camera_index} not accessible with {name}")
        except Exception as e:
            print(f"    ❌ Error with {name}: {str(e)}")
    
    return False

def main():
    print("🔧 Quick Camera Test")
    print("====================")
    
    # Test 1: libcamera
    if test_libcamera():
        print("\n🎉 Camera is working with libcamera!")
        return
    
    # Test 2: raspistill
    if test_raspistill():
        print("\n🎉 Camera is working with raspistill!")
        return
    
    # Test 3: OpenCV
    print("\n📹 Testing OpenCV...")
    for camera_index in [0, 3]:
        if test_opencv_manual(camera_index):
            print(f"\n🎉 Camera {camera_index} is working with OpenCV!")
            return
    
    print("\n❌ No working camera method found")
    print("\nTry these steps:")
    print("1. sudo raspi-config > Interface Options > Camera > Enable")
    print("2. sudo reboot")
    print("3. Run this test again")

if __name__ == "__main__":
    main() 