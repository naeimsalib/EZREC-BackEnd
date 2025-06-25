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

### 3. Missing OpenCV (CRITICAL)

- **Error**: `ModuleNotFoundError: No module named 'cv2'`
- **Root Cause**: OpenCV not installed in system or virtual environment
- **Impact**: Camera interface cannot initialize properly

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

### OpenCV Installation Fix

- Added system-level OpenCV installation (`python3-opencv`)
- Added virtual environment OpenCV installation (`opencv-python`)
- Ensures camera interface can use both Pi Camera and USB cameras

## 🔧 Manual Installation Steps

If you need to install OpenCV manually:

```bash
# Install system-level OpenCV
sudo apt update
sudo apt install python3-opencv -y

# Install in virtual environment (if using one)
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install opencv-python

# Restart the service
sudo systemctl restart ezrec-backend
```

## 🔧 Quick Recovery Steps

### 1. Use the Restart Script

```bash
chmod +x restart_ezrec.sh
sudo ./restart_ezrec.sh
```

### 2. Run Camera Diagnostics

```bash
chmod +x camera_diagnostic.py
python3 camera_diagnostic.py
```

### 3. Check Service Status

```bash
sudo systemctl status ezrec-backend
sudo journalctl -u ezrec-backend -f
```

## 📋 Verification Steps

After applying fixes, verify everything is working:

### 1. Check OpenCV Installation

```bash
# Test system OpenCV
python3 -c "import cv2; print(f'OpenCV {cv2.__version__} installed')"

# Test virtual environment OpenCV
sudo -u ezrec /opt/ezrec-backend/venv/bin/python -c "import cv2; print(f'OpenCV {cv2.__version__} in venv')"
```

### 2. Check Camera Detection

```bash
# Test camera hardware
libcamera-hello --list-cameras

# Test camera access
python3 camera_diagnostic.py
```

### 3. Monitor Service Logs

```bash
# Check for errors
sudo journalctl -u ezrec-backend --since "5 minutes ago"

# Look for success messages
sudo journalctl -u ezrec-backend | grep -E "(Camera.*initialized|Recording.*started|started successfully)"
```

## 🐛 Debugging Commands

### Camera Hardware Debugging

```bash
# List video devices
ls -la /dev/video*

# Check user permissions
groups | grep video

# Test Pi Camera specifically
vcgencmd get_camera
```

### Service Debugging

```bash
# Check service status
sudo systemctl status ezrec-backend --no-pager -l

# View recent logs
sudo journalctl -u ezrec-backend --lines=50 --no-pager

# Check configuration
sudo -u ezrec cat /opt/ezrec-backend/.env
```

### Python Environment Debugging

```bash
# Test imports
sudo -u ezrec /opt/ezrec-backend/venv/bin/python -c "
import cv2, numpy, picamera2
print('All camera modules imported successfully')
"

# Check package versions
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip list | grep -E "(opencv|numpy|picamera)"
```

## 📊 Expected Results After Fixes

### Successful Service Startup

```
✓ Camera initialized successfully
✓ All worker threads started
✓ No health check failures
✓ Clean log output without retry loops
```

### Successful Camera Test

```
✓ Pi Camera: Working - Frame shape: (480, 640, 4)
✓ OpenCV version: 4.8.1.78
✓ Camera health check passed
```

### Successful Recording

```
✓ Recording started successfully
✓ No "Camera not ready" errors
✓ Time format validation passes
```

## 🆘 Emergency Recovery

If the service is completely broken:

```bash
# Stop everything
sudo systemctl stop ezrec-backend

# Clean restart
sudo ./restart_ezrec.sh

# If still broken, reinstall OpenCV
sudo apt install --reinstall python3-opencv
sudo -u ezrec /opt/ezrec-backend/venv/bin/pip install --force-reinstall opencv-python

# Restart service
sudo systemctl restart ezrec-backend
```

## 📞 Getting Help

When reporting issues, include:

1. **System Information**:

   ```bash
   uname -a
   python3 --version
   ```

2. **Camera Diagnostic Output**:

   ```bash
   python3 camera_diagnostic.py
   ```

3. **Service Logs**:

   ```bash
   sudo journalctl -u ezrec-backend --lines=100 --no-pager
   ```

4. **OpenCV Status**:
   ```bash
   python3 -c "import cv2; print(cv2.__version__)"
   sudo -u ezrec /opt/ezrec-backend/venv/bin/python -c "import cv2; print(cv2.__version__)"
   ```

## 📝 Notes

- The Pi Camera works with picamera2 library (primary method)
- OpenCV provides USB camera fallback support
- Both system and virtual environment installations are needed for full compatibility
- Camera permissions require user to be in 'video' group
- Service runs as 'ezrec' user with restricted permissions

---

**Updated**: 2025-06-25 - Added OpenCV installation requirements and verification steps
