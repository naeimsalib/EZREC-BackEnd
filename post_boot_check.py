import os
from src.camera_interface import CameraInterface
from supabase import create_client
from dotenv import load_dotenv
import sys
import multiprocessing
from src.utils import send_heartbeat

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_KEY")
USER_ID = os.getenv("USER_ID")

print("[Post Boot Check] Starting health checks...")

# Camera check with timeout

def check_device(device, result_queue):
    try:
        cap = cv2.VideoCapture(device)
        if cap.isOpened():
            ret, frame = cap.read()
            cap.release()
            if ret:
                result_queue.put((device, True, None))
            else:
                result_queue.put((device, False, "Opened but failed to read frame"))
        else:
            result_queue.put((device, False, "Failed to open"))
    except Exception as e:
        result_queue.put((device, False, f"Exception: {e}"))

def check_camera():
    try:
        cam = CameraInterface()
        print(f"Camera health check passed: type={cam.camera_type}")
        cam.release()
        return True
    except Exception as e:
        print(f"Camera health check failed: {e}")
        return False

# Supabase check
def check_supabase():
    print("Checking Supabase connection...")
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        response = supabase.table('system_status').select('*').limit(1).execute()
        print("Supabase test passed")
        return True
    except Exception as e:
        print(f"Supabase test failed: {e}")
        return False

# Permissions check
def check_permissions():
    print("Checking directory permissions...")
    dirs = [
        "temp",
        "recordings",
        "logs"
    ]
    all_good = True
    for d in dirs:
        path = os.path.join(os.path.dirname(__file__), d)
        if not os.path.exists(path):
            print(f"Directory {path} does not exist!")
            all_good = False
        elif not os.access(path, os.W_OK):
            print(f"Directory {path} is not writable!")
            all_good = False
        else:
            print(f"Directory {path} is writable.")
    return all_good

if __name__ == "__main__":
    cam_ok = check_camera()
    supa_ok = check_supabase()
    perm_ok = check_permissions()
    if cam_ok and supa_ok and perm_ok:
        print("[Post Boot Check] All checks passed!")
        send_heartbeat(is_recording=False, is_streaming=False)
        sys.exit(0)
    else:
        print("[Post Boot Check] One or more checks failed!")
        sys.exit(1) 