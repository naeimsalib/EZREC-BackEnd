#!/usr/bin/env python3
import subprocess
import os
import psutil

def check_camera_usage():
    """Check what processes are using camera devices"""
    print("🔍 Camera Usage Check")
    print("====================")
    
    # Check for video devices
    video_devices = []
    for i in range(10):
        device = f"/dev/video{i}"
        if os.path.exists(device):
            video_devices.append(device)
    
    if not video_devices:
        print("❌ No video devices found")
        return
    
    print(f"✅ Found {len(video_devices)} video device(s):")
    for device in video_devices:
        print(f"  - {device}")
    
    print("\n📋 Checking processes using video devices...")
    
    # Check what processes are using video devices
    for device in video_devices:
        print(f"\n--- {device} ---")
        try:
            # Use lsof to check what's using the device
            result = subprocess.run(['sudo', 'lsof', device], 
                                  capture_output=True, text=True, timeout=5)
            
            if result.returncode == 0 and result.stdout.strip():
                print("Processes using this device:")
                lines = result.stdout.strip().split('\n')
                for line in lines[1:]:  # Skip header
                    if line.strip():
                        parts = line.split()
                        if len(parts) >= 2:
                            pid = parts[1]
                            cmd = parts[0]
                            print(f"  PID {pid}: {cmd}")
                            
                            # Get more info about the process
                            try:
                                proc = psutil.Process(int(pid))
                                print(f"    Command: {' '.join(proc.cmdline())}")
                                print(f"    User: {proc.username()}")
                                print(f"    Status: {proc.status()}")
                            except:
                                print(f"    Could not get process details")
            else:
                print("  ✅ No processes using this device")
                
        except Exception as e:
            print(f"  ❌ Error checking {device}: {str(e)}")
    
    print("\n🐍 Checking Python processes...")
    python_processes = []
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            if 'python' in proc.info['name'].lower():
                cmdline = ' '.join(proc.info['cmdline'])
                if any(keyword in cmdline.lower() for keyword in ['camera', 'smartcam', 'opencv']):
                    python_processes.append(proc)
        except:
            pass
    
    if python_processes:
        print("Python processes that might be camera-related:")
        for proc in python_processes:
            print(f"  PID {proc.info['pid']}: {' '.join(proc.info['cmdline'])}")
    else:
        print("✅ No camera-related Python processes found")
    
    print("\n🔧 Checking systemd services...")
    try:
        result = subprocess.run(['systemctl', 'list-units', '--type=service', '--state=running'], 
                              capture_output=True, text=True, timeout=5)
        
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            smartcam_services = []
            for line in lines:
                if 'smartcam' in line.lower() or 'camera' in line.lower():
                    smartcam_services.append(line.strip())
            
            if smartcam_services:
                print("Running services that might be camera-related:")
                for service in smartcam_services:
                    print(f"  - {service}")
            else:
                print("✅ No camera-related services running")
        else:
            print("❌ Could not check systemd services")
            
    except Exception as e:
        print(f"❌ Error checking systemd services: {str(e)}")
    
    print("\n💡 Recommendations:")
    if any('python' in str(proc.info['cmdline']).lower() for proc in python_processes):
        print("1. Kill Python processes: sudo pkill -f python")
    if any('smartcam' in line.lower() for line in smartcam_services if 'smartcam_services' in locals()):
        print("2. Stop SmartCam services: sudo systemctl stop smartcam-*")
    print("3. Run: ./kill_camera_processes.sh")
    print("4. Test camera: python quick_camera_test.py")

if __name__ == "__main__":
    check_camera_usage() 