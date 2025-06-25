# EZREC Camera Troubleshooting Guide

## Current Issues Identified

Based on your logs, there are two critical issues:

### 1. Camera Not Ready for Recording

- **Error**: `RuntimeError: Camera not ready for recording`
- **Symptom**: Continuous failed recording attempts every second
- **Root Cause**: Camera initialization or hardware access problems

### 2. Invalid Time Format

- **Error**: `WARNING: Invalid end_time format in booking: 01:02`
- **Root Cause**: Booking data uses simple time format (HH:MM) but code expected ISO timestamps

## ✅ Fixes Applied

### Recording Loop Fix

- Added exponential backoff for failed camera initialization attempts
- Prevents continuous retry loops that spam the logs
- Implements intelligent retry delays (2s, 4s, 8s, 16s, 30s max)
- Resets failure counter on successful operations

### Time Format Fix

- Enhanced booking validation to handle both ISO and simple time formats
- Supports both `"01:02"` and `"2025-06-25T01:02:00-04:00"` formats
- Combines date + time when needed for proper datetime objects

### Camera Interface Improvements

- Enhanced camera initialization with comprehensive diagnostics
- Better health check reporting with specific failure reasons
- Test frame capture during initialization to verify camera functionality
- Graceful handling of initialization failures

## 🔧 Immediate Actions Required

### 1. Restart EZREC Service

Run the provided restart script on your Raspberry Pi:

```bash
cd /home/michomanoly14892/code/EZREC-BackEnd
./restart_ezrec.sh
```

This script will:

- Safely stop the service
- Kill any stuck processes
- Clear problematic temporary files
- Test camera access
- Restart the service with fresh state

### 2. Run Camera Diagnostics

If issues persist, run the comprehensive diagnostic:

```bash
cd /home/michomanoly14892/code/EZREC-BackEnd
python3 camera_diagnostic.py
```

This will check:

- System information and OS version
- Video device detection (/dev/video\*)
- Camera module status and drivers
- File permissions and user groups
- Configuration files
- Python camera library tests
- EZREC-specific camera interface

## 🔍 Common Camera Issues & Solutions

### No Video Devices Found

```bash
# Check for video devices
ls -la /dev/video*

# If none found, check USB connections
lsusb

# For Pi Camera, check boot config
sudo cat /boot/config.txt | grep camera
sudo raspi-config  # Enable camera if needed
```

### Permission Issues

```bash
# Add user to video group
sudo usermod -a -G video $USER

# Check permissions
ls -la /dev/video0
groups
```

### Pi Camera Not Detected

```bash
# Check Pi Camera status
vcgencmd get_camera

# Check camera cable connection
# Ensure /boot/config.txt has: camera_auto_detect=1
```

### USB Camera Issues

```bash
# Test USB camera directly
v4l2-ctl --device=/dev/video0 --list-formats
v4l2-ctl --device=/dev/video0 --list-framesizes=YUYV

# Check USB power
# Try different USB ports
# Check dmesg for USB errors
dmesg | grep -i usb | tail -10
```

## 📊 Monitoring

### Real-time Logs

```bash
# Monitor service logs
sudo journalctl -u ezrec-backend -f

# Monitor with timestamp
sudo journalctl -u ezrec-backend -f --since "now"
```

### Service Status

```bash
# Check service status
sudo systemctl status ezrec-backend

# Check if process is running
ps aux | grep orchestrator

# Check system resources
top | grep python
```

## 🚨 Emergency Recovery

If the service becomes completely unresponsive:

### 1. Force Stop Everything

```bash
sudo systemctl stop ezrec-backend
sudo pkill -f orchestrator.py
sudo pkill -f ezrec
```

### 2. Clear All State

```bash
sudo rm -f /opt/ezrec-backend/temp/*
sudo rm -f /opt/ezrec-backend/logs/*.log
```

### 3. Test Camera Manually

```bash
# Test with Python
python3 -c "
import cv2
cap = cv2.VideoCapture(0)
if cap.isOpened():
    ret, frame = cap.read()
    print('Camera OK' if ret else 'Camera Failed')
    cap.release()
else:
    print('Cannot open camera')
"
```

### 4. Restart Fresh

```bash
sudo systemctl start ezrec-backend
sudo systemctl status ezrec-backend
```

## 📈 Expected Improvements

After applying the fixes and restarting:

1. **No more spam loops**: Recording failures will be rate-limited
2. **Better error messages**: Specific reasons for camera failures
3. **Intelligent retries**: Exponential backoff prevents system overload
4. **Time format compatibility**: Handles both simple and ISO time formats
5. **Enhanced diagnostics**: Better health checks and logging

## 📞 Next Steps

1. **Run `restart_ezrec.sh`** to apply fixes immediately
2. **Monitor logs** for 5-10 minutes to ensure stability
3. **Run diagnostics** if problems persist
4. **Check camera hardware** if software tests fail
5. **Update/create new bookings** to test recording functionality

The system should now be much more stable and provide clearer error messages for any remaining issues.
