#!/usr/bin/env python3
import cv2
import time
import subprocess
import os
import sys

def check_camera_config():
    """Check camera configuration"""
    print("🔧 Camera Configuration Check")
    print("=============================")
    
    # Check if camera is enabled
    try:
        result = subprocess.run(['sudo', 'raspi-config', 'nonint', 'get_camera'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ Camera interface is enabled")
        else:
            print("❌ Camera interface is disabled")
            return False
    except:
        print("⚠️  Could not check camera configuration")
    
    # Check camera info
    try:
        result = subprocess.run(['vcgencmd', 'get_camera'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"📷 Camera info: {result.stdout.strip()}")
        else:
            print("⚠️  Could not get camera info")
    except:
        print("⚠️  vcgencmd not available")
    
    return True

def test_camera_with_detailed_info(camera_index):
    """Test camera with detailed information"""
    print(f"\n📹 Detailed Camera {camera_index} Test")
    print("=" * 40)
    
    try:
        # Try to open camera
        cap = cv2.VideoCapture(camera_index)
        if not cap.isOpened():
            print(f"❌ Could not open camera {camera_index}")
            return False
        
        print(f"✅ Camera {camera_index} opened successfully")
        
        # Get camera properties
        width = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
        height = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
        fps = cap.get(cv2.CAP_PROP_FPS)
        fourcc = cap.get(cv2.CAP_PROP_FOURCC)
        
        print(f"   Default width: {width}")
        print(f"   Default height: {height}")
        print(f"   Default FPS: {fps}")
        print(f"   Default FOURCC: {fourcc}")
        
        # Set properties
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)
        
        # Get updated properties
        width = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
        height = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
        fps = cap.get(cv2.CAP_PROP_FPS)
        
        print(f"   Set width: {width}")
        print(f"   Set height: {height}")
        print(f"   Set FPS: {fps}")
        
        # Wait for camera to initialize
        print("   Waiting 5 seconds for camera initialization...")
        time.sleep(5)
        
        # Try to read frames with detailed info
        for i in range(10):
            ret, frame = cap.read()
            print(f"   Frame {i+1}: ret={ret}, frame={'None' if frame is None else f'{frame.shape} (size: {frame.size})'}")
            
            if ret and frame is not None and frame.size > 0:
                print(f"   ✅ SUCCESS! Camera {camera_index} is working!")
                print(f"   Frame shape: {frame.shape}")
                print(f"   Frame dtype: {frame.dtype}")
                print(f"   Frame min/max values: {frame.min()}/{frame.max()}")
                cap.release()
                return True
            
            time.sleep(0.5)
        
        cap.release()
        print(f"   ❌ Camera {camera_index} opened but no valid frames captured")
        return False
        
    except Exception as e:
        print(f"   ❌ Error testing camera {camera_index}: {str(e)}")
        return False

def test_camera_with_v4l2_ctl(camera_index):
    """Test camera using v4l2-ctl"""
    print(f"\n🔧 V4L2-CTL Test for Camera {camera_index}")
    print("=" * 40)
    
    try:
        # Get camera capabilities
        result = subprocess.run(['v4l2-ctl', '-d', f'/dev/video{camera_index}', '--all'], 
                              capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Camera capabilities:")
            lines = result.stdout.split('\n')
            for line in lines[:20]:  # Show first 20 lines
                if 'Driver name' in line or 'Card type' in line or 'Bus info' in line:
                    print(f"   {line.strip()}")
        else:
            print("❌ Could not get camera capabilities")
        
        # Try to set format
        result = subprocess.run([
            'v4l2-ctl', '-d', f'/dev/video{camera_index}',
            '--set-fmt-video=width=640,height=480,pixelformat=YUYV'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Set YUYV format successfully")
        else:
            print("❌ Could not set YUYV format")
        
        # Try MJPG format
        result = subprocess.run([
            'v4l2-ctl', '-d', f'/dev/video{camera_index}',
            '--set-fmt-video=width=640,height=480,pixelformat=MJPG'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ Set MJPG format successfully")
        else:
            print("❌ Could not set MJPG format")
        
        return True
        
    except Exception as e:
        print(f"❌ V4L2-CTL error: {str(e)}")
        return False

def test_camera_with_stream():
    """Test camera with streaming approach"""
    print(f"\n📺 Camera Streaming Test")
    print("=" * 40)
    
    try:
        # Try to open camera with streaming
        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            print("❌ Could not open camera for streaming")
            return False
        
        print("✅ Camera opened for streaming")
        
        # Set streaming properties
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        
        # Wait for camera to initialize
        print("   Waiting 3 seconds...")
        time.sleep(3)
        
        # Try to read frames in a loop
        frame_count = 0
        start_time = time.time()
        
        for i in range(20):
            ret, frame = cap.read()
            if ret and frame is not None:
                frame_count += 1
                if frame_count == 1:
                    print(f"   ✅ First frame captured: {frame.shape}")
                elif frame_count % 5 == 0:
                    print(f"   📸 Frame {frame_count} captured")
            
            time.sleep(0.1)
        
        elapsed_time = time.time() - start_time
        print(f"   Captured {frame_count} frames in {elapsed_time:.2f} seconds")
        
        if frame_count > 0:
            print("✅ Camera streaming is working!")
            cap.release()
            return True
        else:
            print("❌ No frames captured during streaming")
            cap.release()
            return False
            
    except Exception as e:
        print(f"❌ Streaming error: {str(e)}")
        return False

def main():
    print("🔍 Comprehensive Camera Debug")
    print("=============================")
    
    # Check camera configuration
    if not check_camera_config():
        print("\n❌ Camera configuration issue detected")
        print("Please enable camera in raspi-config and reboot")
        return
    
    # Test cameras with detailed info
    working_cameras = []
    
    for camera_index in [0, 3]:
        if test_camera_with_detailed_info(camera_index):
            working_cameras.append(camera_index)
    
    # Test with v4l2-ctl
    test_camera_with_v4l2_ctl(0)
    
    # Test streaming
    if test_camera_with_stream():
        working_cameras.append("streaming")
    
    # Results
    print(f"\n{'='*60}")
    if working_cameras:
        print(f"✅ SUCCESS: Found {len(working_cameras)} working camera method(s)")
        for method in working_cameras:
            print(f"  - {method}")
    else:
        print("❌ FAILED: No working camera method found")
        print("\nTroubleshooting suggestions:")
        print("1. Check camera connection")
        print("2. Try: sudo raspi-config > Interface Options > Camera > Enable")
        print("3. Reboot: sudo reboot")
        print("4. Check if camera is compatible with your Pi model")
        print("5. Try a different camera module")

if __name__ == "__main__":
    main() 