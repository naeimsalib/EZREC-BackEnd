#!/bin/bash

# Start system status updater
python3 update_system_status.py &
SYSTEM_STATUS_PID=$!

# Start camera manager
python3 manage_cameras.py &
CAMERA_MANAGER_PID=$!

# Function to handle script termination
cleanup() {
    echo "Stopping services..."
    kill $SYSTEM_STATUS_PID
    kill $CAMERA_MANAGER_PID
    exit 0
}

# Register the cleanup function for when script receives SIGINT (Ctrl+C)
trap cleanup SIGINT

# Keep script running
while true; do
    sleep 1
done 