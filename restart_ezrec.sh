#!/bin/bash

# EZREC Service Restart Script
# Use this to safely restart the EZREC service and clear any stuck states

echo "EZREC Service Restart and Recovery"
echo "=================================="
echo "$(date): Starting EZREC service restart procedure"

# Stop the service
echo "Stopping EZREC service..."
sudo systemctl stop ezrec-backend

# Wait for service to fully stop
echo "Waiting for service to stop completely..."
sleep 5

# Check if any EZREC processes are still running
echo "Checking for remaining EZREC processes..."
EZREC_PIDS=$(pgrep -f "orchestrator.py")
if [ ! -z "$EZREC_PIDS" ]; then
    echo "Found remaining EZREC processes: $EZREC_PIDS"
    echo "Terminating them..."
    sudo kill -TERM $EZREC_PIDS
    sleep 3
    
    # Force kill if still running
    EZREC_PIDS=$(pgrep -f "orchestrator.py")
    if [ ! -z "$EZREC_PIDS" ]; then
        echo "Force killing remaining processes..."
        sudo kill -KILL $EZREC_PIDS
    fi
fi

# Clear any temp booking files that might be causing issues
echo "Cleaning up temporary files..."
sudo rm -f /opt/ezrec-backend/temp/current_booking.json
sudo rm -f /opt/ezrec-backend/temp/*.tmp

# Check camera availability
echo "Checking camera availability..."
if [ -e /dev/video0 ]; then
    echo "Camera device /dev/video0 found"
    # Test camera access
    timeout 5 python3 -c "
import cv2
try:
    cap = cv2.VideoCapture(0)
    if cap.isOpened():
        ret, frame = cap.read()
        cap.release()
        print('Camera test: PASSED' if ret else 'Camera test: FAILED - No frame')
    else:
        print('Camera test: FAILED - Cannot open')
except Exception as e:
    print(f'Camera test: ERROR - {e}')
" 2>/dev/null || echo "Camera test: TIMEOUT or ERROR"
else
    echo "WARNING: No camera device found at /dev/video0"
fi

# Start the service
echo "Starting EZREC service..."
sudo systemctl start ezrec-backend

# Wait for startup
echo "Waiting for service to start..."
sleep 3

# Check service status
echo "Checking service status..."
sudo systemctl status ezrec-backend --no-pager -l

# Monitor logs for a few seconds
echo ""
echo "Recent logs (last 10 lines):"
sudo journalctl -u ezrec-backend -n 10 --no-pager

echo ""
echo "Service restart completed at $(date)"
echo ""
echo "To monitor logs in real-time, run:"
echo "sudo journalctl -u ezrec-backend -f" 