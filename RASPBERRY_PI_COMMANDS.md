# Raspberry Pi - EZREC Backend Commands Reference

This guide provides all the commands you need to check your current systemd services and update them without creating redundancies.

## 🔍 **Step 1: Check Current System Status**

### **Copy the analysis script to your Raspberry Pi:**
```bash
# On your development machine, copy the script
scp check_current_services.sh pi@your-raspberry-pi-ip:/home/pi/
```

### **Run the analysis on Raspberry Pi:**
```bash
# SSH into your Raspberry Pi
ssh pi@your-raspberry-pi-ip

# Make the script executable and run it
chmod +x check_current_services.sh
sudo ./check_current_services.sh
```

### **Manual commands to check current services:**
```bash
# Check all systemd services
sudo systemctl list-units --type=service --all | grep -i "smartcam\|ezrec\|camera"

# Check specific service status
sudo systemctl status smartcam.service
sudo systemctl status smartcam-manager.service
sudo systemctl status smartcam-status.service

# Check if services are enabled
sudo systemctl is-enabled smartcam.service
sudo systemctl is-enabled smartcam-manager.service
sudo systemctl is-enabled smartcam-status.service

# Check running processes
ps aux | grep -E "(python|smartcam|ezrec|camera)" | grep -v grep

# Check for existing installations
ls -la /opt/ezrec-backend
ls -la /opt/smartcam
ls -la /home/michomanoly14892/code/SmartCam-Soccer
ls -la /home/pi/code/EZREC-BackEnd
```

## 🛠️ **Step 2: Update Existing Services**

### **Copy the update script to your Raspberry Pi:**
```bash
# On your development machine, copy the script
scp update_existing_services.sh pi@your-raspberry-pi-ip:/home/pi/
```

### **Run the update on Raspberry Pi:**
```bash
# SSH into your Raspberry Pi
ssh pi@your-raspberry-pi-ip

# Make the script executable and run it
chmod +x update_existing_services.sh
sudo ./update_existing_services.sh
```

### **Manual update commands (if needed):**
```bash
# Stop existing services
sudo systemctl stop smartcam.service
sudo systemctl stop smartcam-manager.service
sudo systemctl stop smartcam-status.service

# Disable existing services
sudo systemctl disable smartcam.service
sudo systemctl disable smartcam-manager.service
sudo systemctl disable smartcam-status.service

# Remove old service files
sudo rm /etc/systemd/system/smartcam.service
sudo rm /etc/systemd/system/smartcam-manager.service
sudo rm /etc/systemd/system/smartcam-status.service

# Reload systemd
sudo systemctl daemon-reload
```

## 📋 **Step 3: Service Management Commands**

### **After updating, use these commands:**

```bash
# Start all services
sudo /opt/ezrec-backend/manage.sh start

# Stop all services
sudo /opt/ezrec-backend/manage.sh stop

# Restart all services
sudo /opt/ezrec-backend/manage.sh restart

# Check service status
sudo /opt/ezrec-backend/manage.sh status

# View live logs
sudo /opt/ezrec-backend/manage.sh logs

# Health check
sudo /opt/ezrec-backend/manage.sh health

# Update application
sudo /opt/ezrec-backend/manage.sh update
```

### **Direct systemctl commands:**
```bash
# Check specific service
sudo systemctl status ezrec-backend.service
sudo systemctl status ezrec-orchestrator.service
sudo systemctl status ezrec-scheduler.service
sudo systemctl status ezrec-status.service

# View logs
sudo journalctl -u ezrec-backend.service -f
sudo journalctl -u ezrec-orchestrator.service -f
sudo journalctl -u ezrec-scheduler.service -f
sudo journalctl -u ezrec-status.service -f

# Recent logs (last 50 lines)
sudo journalctl -u ezrec-backend.service -n 50
```

## 🔧 **Step 4: Troubleshooting Commands**

### **Check system resources:**
```bash
# Check disk space
df -h

# Check memory usage
free -h

# Check CPU usage
top

# Check network
ip addr show
hostname -I
```

### **Check camera:**
```bash
# List camera devices
v4l2-ctl --list-devices

# Check camera formats
v4l2-ctl --device=/dev/video0 --list-formats-ext

# Test camera
v4l2-ctl --device=/dev/video0 --stream-mmap --stream-count=1
```

### **Check Python environment:**
```bash
# Check Python version
python3 --version

# Check pip packages
pip list

# Check virtual environment
which python
echo $VIRTUAL_ENV
```

### **Check configuration:**
```bash
# Check .env file
cat /opt/ezrec-backend/.env

# Check environment variables
env | grep -E "(SUPABASE|CAMERA|USER)"

# Check file permissions
ls -la /opt/ezrec-backend/
```

## 🔄 **Step 5: Backup and Restore**

### **Backup current configuration:**
```bash
# Create backup directory
sudo mkdir -p /opt/ezrec-backend-backup-$(date +%Y%m%d_%H%M%S)

# Backup .env file
sudo cp /opt/ezrec-backend/.env /opt/ezrec-backend-backup-$(date +%Y%m%d_%H%M%S)/.env.backup

# Backup service files
sudo cp /etc/systemd/system/smartcam*.service /opt/ezrec-backend-backup-$(date +%Y%m%d_%H%M%S)/
```

### **Restore from backup:**
```bash
# Restore .env file
sudo cp /opt/ezrec-backend-backup-YYYYMMDD_HHMMSS/.env.backup /opt/ezrec-backend/.env

# Restore service files
sudo cp /opt/ezrec-backend-backup-YYYYMMDD_HHMMSS/*.service /etc/systemd/system/

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart ezrec-backend.service
```

## 📊 **Step 6: Monitoring Commands**

### **Real-time monitoring:**
```bash
# Watch service status
watch -n 2 'systemctl status ezrec-backend.service'

# Monitor logs in real-time
sudo journalctl -u ezrec-backend.service -f

# Monitor system resources
htop

# Monitor disk usage
watch -n 5 'df -h'
```

### **Check for errors:**
```bash
# Check for failed services
sudo systemctl --failed

# Check for errors in logs
sudo journalctl -u ezrec-backend.service --since "1 hour ago" | grep -i error

# Check for warnings
sudo journalctl -u ezrec-backend.service --since "1 hour ago" | grep -i warning
```

## 🚀 **Quick Start Commands**

### **For a fresh installation:**
```bash
# 1. Check current state
sudo ./check_current_services.sh

# 2. Update existing services (or fresh install)
sudo ./update_existing_services.sh

# 3. Start services
sudo /opt/ezrec-backend/manage.sh start

# 4. Check status
sudo /opt/ezrec-backend/manage.sh status

# 5. Health check
sudo /opt/ezrec-backend/manage.sh health
```

### **For daily management:**
```bash
# Check if everything is running
sudo /opt/ezrec-backend/manage.sh health

# View recent logs
sudo /opt/ezrec-backend/manage.sh logs

# Update application
sudo /opt/ezrec-backend/manage.sh update
```

## ⚠️ **Important Notes**

1. **Always backup** before making changes
2. **Check logs** if services fail to start
3. **Verify camera** is properly connected
4. **Ensure .env file** has correct Supabase credentials
5. **Monitor disk space** regularly
6. **Keep system updated** with `sudo apt update && sudo apt upgrade`

## 📞 **Emergency Commands**

### **If services won't start:**
```bash
# Check what's wrong
sudo journalctl -u ezrec-backend.service -n 100

# Restart from scratch
sudo systemctl stop ezrec-*.service
sudo systemctl disable ezrec-*.service
sudo systemctl daemon-reload
sudo systemctl enable ezrec-backend.service
sudo systemctl start ezrec-backend.service
```

### **If camera isn't working:**
```bash
# Check camera permissions
ls -la /dev/video*

# Add user to video group
sudo usermod -a -G video ezrec

# Reboot to apply changes
sudo reboot
```

### **If disk is full:**
```bash
# Clean up old recordings
sudo find /opt/ezrec-backend/recordings -name "*.mp4" -mtime +7 -delete

# Clean up old logs
sudo find /opt/ezrec-backend/logs -name "*.log" -mtime +30 -delete

# Check what's using space
sudo du -sh /opt/ezrec-backend/*
``` 