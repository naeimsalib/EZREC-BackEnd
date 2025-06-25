# 🌐 EZREC Frontend Testing Guide

## Complete End-to-End Workflow Testing

This guide will help you test the complete EZREC workflow:
**Frontend → Booking Creation → Recording → Upload → Recording Display**

---

## 🔧 Step 1: Fix Backend Dependencies

Run this on your Raspberry Pi to sync and fix the backend:

```bash
cd ~/code/EZREC-BackEnd
./sync_and_fix.sh
```

This will:

- ✅ Sync GitHub repo with service directory
- ✅ Install missing Supabase dependencies
- ✅ Test environment configuration
- ✅ Restart service with latest code

---

## 🌐 Step 2: Frontend Setup

### Frontend Requirements:

Your frontend needs to connect to the **same Supabase project** as your backend.

### Check Frontend Configuration:

Ensure your frontend `.env` or config has:

```env
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

### Frontend Booking Creation:

When creating a booking from the frontend, ensure it includes:

```javascript
{
  "id": "uuid-generated-booking-id",
  "user_id": "your-user-id-from-backend-env",
  "camera_id": "raspberry_pi_camera",  // Must match backend CAMERA_ID
  "date": "2025-06-25",                // Format: YYYY-MM-DD
  "start_time": "15:45",               // Format: HH:MM
  "end_time": "15:47",                 // Format: HH:MM
  "status": "confirmed",
  "title": "Test Recording",
  "description": "Frontend test booking"
}
```

**Critical Fields:**

- `camera_id` must match your backend `CAMERA_ID` in `.env`
- `user_id` must match your backend `USER_ID` in `.env`
- `status` must be "confirmed" for backend to pick it up

---

## 🎬 Step 3: Complete Workflow Test

### A. Monitor Backend Logs (Terminal 1):

```bash
ssh pi@your-pi-ip
sudo journalctl -u ezrec-backend -f
```

### B. Create Booking from Frontend (Browser):

1. Open your frontend application
2. Navigate to booking creation page
3. Create a booking that starts **2-3 minutes from now**
4. Ensure all required fields are filled correctly

### C. Watch the Complete Workflow:

#### 🔍 **Phase 1: Booking Detection (within 30 seconds)**

Look for logs like:

```
Found next booking: abc-123-def
Saved booking to local file
```

#### 🎬 **Phase 2: Recording Start (at booking start time)**

Look for logs like:

```
Starting recording for booking abc-123-def
Camera recording started successfully
Recording to: /opt/ezrec-backend/temp/recording_20250625_154500_abc-123-def.mp4
```

#### ⏱️ **Phase 3: Recording End (at booking end time)**

Look for logs like:

```
Booking abc-123-def has ended. Stopping recording.
Recording stopped and saved to: /opt/ezrec-backend/recordings/
Completed booking abc-123-def (local + database)
```

#### 📤 **Phase 4: Upload (if configured)**

Look for logs like:

```
Uploading recording to Supabase Storage
Upload successful: recording_20250625_154500_abc-123-def.mp4
Recording metadata saved to database
```

---

## 📋 Step 4: Verify Results

### Check Recording Files:

```bash
# On Raspberry Pi
ls -la /opt/ezrec-backend/recordings/
ls -la /opt/ezrec-backend/temp/
```

### Check Supabase Database:

1. Go to Supabase Dashboard → Table Editor
2. Check `bookings` table - booking should be removed or status updated
3. Check `recordings` table - new recording entry should appear
4. Check Storage bucket - video file should be uploaded

### Check Frontend Display:

1. Navigate to recordings/videos page in your frontend
2. Verify the new recording appears
3. Test video playback

---

## 🚨 Troubleshooting

### If Booking Not Detected:

```bash
# Check booking manually
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 -c "
import sys; sys.path.append('/opt/ezrec-backend/src')
from utils import get_next_booking
booking = get_next_booking()
print('Found booking:' if booking else 'No booking found')
print(booking)
"
```

### If Recording Doesn't Start:

```bash
# Test camera manually
sudo -u ezrec /opt/ezrec-backend/venv/bin/python3 -c "
import sys; sys.path.append('/opt/ezrec-backend/src')
from camera_interface import CameraInterface
camera = CameraInterface()
print(f'Camera ready: {camera.camera is not None}')
camera.release()
"
```

### If Upload Fails:

Check the `upload_recordings.py` script configuration and Supabase storage bucket permissions.

---

## ✅ Success Criteria

Your complete workflow is working if:

1. ✅ **Frontend creates booking** → Booking appears in Supabase `bookings` table
2. ✅ **Backend detects booking** → Logs show "Found next booking"
3. ✅ **Recording starts on time** → Logs show "Recording started successfully"
4. ✅ **Recording stops on time** → Logs show "Recording stopped and saved"
5. ✅ **Booking completed** → Booking removed from `bookings` table
6. ✅ **Recording uploaded** → File appears in Supabase storage
7. ✅ **Recording in database** → Entry appears in `recordings` table
8. ✅ **Frontend displays recording** → Video appears in recordings page

---

## 🎯 Quick Test Commands

### One-line health check:

```bash
sudo systemctl status ezrec-backend && echo "✅ Service running"
```

### Test complete pipeline manually:

```bash
cd /opt/ezrec-backend
sudo ./create_simple_test_booking.py  # Creates booking
sudo journalctl -u ezrec-backend -f   # Watch it work
```

### Reset for testing:

```bash
# Clear temp files
sudo rm -f /opt/ezrec-backend/temp/*.mp4
# Restart service
sudo systemctl restart ezrec-backend
```

---

**Now your system is ready for complete frontend-to-backend testing! 🚀**
