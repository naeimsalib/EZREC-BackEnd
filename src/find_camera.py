import os
from src.camera_interface import CameraInterface

def find_working_camera():
    try:
        cam = CameraInterface()
        print(f"Camera working: type={cam.camera_type}")
        cam.release()
        return True
    except Exception as e:
        print(f"No working camera found: {e}")
        return False

if __name__ == "__main__":
    find_working_camera() 