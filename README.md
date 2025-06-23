# EZREC Backend - Optimized for Raspberry Pi

Backend services and camera management system for the EZREC SmartCam Soccer platform, specifically optimized for Raspberry Pi deployment with enhanced reliability, monitoring, and performance.

## 🎯 Key Features

- **Intelligent Camera Detection**: Automatic detection and configuration of Pi Camera and USB cameras
- **Robust Recording Management**: Automated recording based on booking schedules with error recovery
- **Enhanced System Monitoring**: Comprehensive health monitoring and logging
- **Production-Ready Deployment**: Systemd service with security hardening and resource limits
- **Optimized Configuration**: Environment-based configuration with validation
- **Comprehensive Testing**: Built-in test suite for validation and troubleshooting

## 🚀 Quick Start

### Prerequisites

- Raspberry Pi 4 (recommended) or Raspberry Pi 3B+
- Raspberry Pi OS (Bullseye or newer)
- Camera module (Pi Camera or USB camera)
- Network connection
- Supabase account and project

### Installation

1. **Clone the repository:**

```bash
git clone https://github.com/yourusername/EZREC-BackEnd.git
cd EZREC-BackEnd
```

2. **Run the automated setup:**

```bash
sudo chmod +x raspberry_pi_setup.sh
sudo ./raspberry_pi_setup.sh
```

3. **Configure your environment:**

```bash
sudo nano /opt/ezrec-backend/.env
```

4. **Start the service:**

```bash
sudo systemctl start ezrec-backend
```

5. **Verify installation:**

```bash
ezrec status
ezrec health
```

## 📋 Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure the following:

#### Required Configuration

```bash
# Supabase Configuration
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# User Configuration
USER_ID=your_user_id_here
USER_EMAIL=your_email@example.com
```

#### Camera Configuration

```bash
# Camera Settings
CAMERA_ID=raspberry_pi_camera
CAMERA_NAME=Raspberry Pi Camera
CAMERA_LOCATION=Soccer Field 1
RECORD_WIDTH=1920
RECORD_HEIGHT=1080
RECORD_FPS=30
```

#### Optional Settings

```bash
# Debug and Logging
DEBUG=false
LOG_LEVEL=INFO

# Performance Tuning
RECORDING_BITRATE=10000000
NETWORK_TIMEOUT=30
```

### Configuration Validation

The system automatically validates configuration on startup and provides helpful error messages for missing or invalid settings.

## 🎥 Camera Support

### Supported Cameras

- **Pi Camera Module**: Primary support via `picamera2` library
- **USB Cameras**: Secondary support via OpenCV
- **Multiple Cameras**: Automatic detection and selection

### Camera Detection

Run the camera detection utility:

```bash
cd /opt/ezrec-backend
sudo -u ezrec ./venv/bin/python src/find_camera.py
```

This provides a comprehensive report of available cameras and their capabilities.

## 🏃‍♂️ Running the System

### Service Management

Use the management script for easy control:

```bash
# Start the service
ezrec start

# Stop the service
ezrec stop

# Restart the service
ezrec restart

# Check status
ezrec status

# View live logs
ezrec logs

# Run health check
ezrec health

# Update the system
ezrec update

# Edit configuration
ezrec config
```

### Direct Systemd Commands

```bash
# Service control
sudo systemctl start ezrec-backend
sudo systemctl stop ezrec-backend
sudo systemctl restart ezrec-backend
sudo systemctl status ezrec-backend

# Enable/disable autostart
sudo systemctl enable ezrec-backend
sudo systemctl disable ezrec-backend

# View logs
sudo journalctl -u ezrec-backend -f
```

## 🔧 Testing and Validation

### Test Suite

Run the comprehensive test suite:

```bash
cd /opt/ezrec-backend
sudo -u ezrec ./venv/bin/python test_system.py
```

### Quick Tests

For faster validation (skips camera tests):

```bash
sudo -u ezrec ./venv/bin/python test_system.py --quick
```

### Test Report

Generate a detailed test report:

```bash
sudo -u ezrec ./venv/bin/python test_system.py --save-report
```

## 📊 Monitoring and Logging

### System Health

The system provides comprehensive health monitoring:

- **Camera Health**: Automatic camera detection and validation
- **System Metrics**: CPU, memory, disk usage, temperature
- **Network Status**: Connection monitoring and retry logic
- **Error Tracking**: Centralized error counting and alerting

### Logging

Logs are automatically managed with rotation:

- **Service Logs**: `sudo journalctl -u ezrec-backend -f`
- **Application Logs**: `/opt/ezrec-backend/logs/ezrec.log`
- **Error Logs**: Integrated with systemd journal
- **Log Rotation**: Automatic cleanup of old logs

### Performance Monitoring

Monitor system performance:

```bash
# Check system resources
ezrec health

# View detailed logs
sudo journalctl -u ezrec-backend --since "1 hour ago"

# Check disk usage
df -h /opt/ezrec-backend

# Monitor temperature (Pi only)
vcgencmd measure_temp
```

## 🔒 Security and Permissions

### Service User

The system runs under a dedicated `ezrec` user with minimal privileges:

- Home directory: `/opt/ezrec-backend`
- Group memberships: `video` (for camera access)
- No sudo privileges
- Restricted filesystem access

### Systemd Security

The service includes security hardening:

- `NoNewPrivileges=true`
- `ProtectSystem=strict`
- `ProtectHome=true`
- `PrivateTmp=true`
- Resource limits (memory, CPU)

### File Permissions

- Configuration files: `600` (owner read/write only)
- Application files: `755` (owner read/write/execute, group/other read/execute)
- Data directories: `775` (group write access for logs/recordings)

## 🛠️ Development

### Project Structure

```
EZREC-BackEnd/
├── src/
│   ├── orchestrator.py          # Main service coordinator
│   ├── camera_interface.py      # Camera abstraction layer
│   ├── camera.py                # Recording management
│   ├── config.py                # Configuration management
│   ├── utils.py                 # Utility functions
│   └── find_camera.py           # Camera detection
├── test_system.py               # Test suite
├── raspberry_pi_setup.sh        # Installation script
├── ezrec-backend.service        # Systemd service file
├── requirements.txt             # Python dependencies
├── .env.example                 # Configuration template
└── README.md                    # This file
```

### Adding Features

1. **Extend Configuration**: Add new settings to `config.py` and `.env.example`
2. **Add Tests**: Include tests in `test_system.py`
3. **Update Service**: Modify `orchestrator.py` for new functionality
4. **Document Changes**: Update this README

### Debugging

Enable debug mode:

```bash
# In .env file
DEBUG=true
LOG_LEVEL=DEBUG

# Restart service
ezrec restart

# View debug logs
ezrec logs
```

## 🔄 Updates and Maintenance

### Updating the System

```bash
# Pull latest changes and restart
ezrec update

# Manual update process
cd /opt/ezrec-backend
git pull
sudo -u ezrec ./venv/bin/pip install -r requirements.txt
sudo systemctl restart ezrec-backend
```

### Maintenance Tasks

Regular maintenance is automated:

- **Log Rotation**: Configured via logrotate
- **Temp File Cleanup**: Automatic cleanup of old temporary files
- **System Monitoring**: Continuous health checks

### Backup and Recovery

Important files to backup:

- `/opt/ezrec-backend/.env` - Configuration
- `/opt/ezrec-backend/logs/` - Application logs
- `/opt/ezrec-backend/recordings/` - Video recordings

## 🐛 Troubleshooting

### Common Issues

#### Camera Not Detected

```bash
# Check camera hardware
ezrec health

# Test camera manually
libcamera-hello --list-cameras

# Check permissions
groups ezrec  # Should include 'video'
```

#### Service Won't Start

```bash
# Check service status
sudo systemctl status ezrec-backend

# View error logs
sudo journalctl -u ezrec-backend --since "10 minutes ago"

# Validate configuration
sudo -u ezrec /opt/ezrec-backend/venv/bin/python src/config.py
```

#### High CPU/Memory Usage

```bash
# Check system resources
ezrec health

# Monitor in real-time
top -p $(pgrep -f ezrec)

# Check disk space
df -h
```

#### Network Connection Issues

```bash
# Test Supabase connection
sudo -u ezrec /opt/ezrec-backend/venv/bin/python -c "
from src.config import SUPABASE_URL
import requests
print(requests.get(SUPABASE_URL + '/rest/v1/').status_code)
"
```

### Debug Mode

Enable enhanced logging:

```bash
# Edit configuration
ezrec config

# Set DEBUG=true and LOG_LEVEL=DEBUG
# Save and restart
ezrec restart

# Monitor debug output
ezrec logs
```

### Getting Help

1. **Check Logs**: Always start with `ezrec logs` and `ezrec health`
2. **Run Tests**: Use `test_system.py` to identify issues
3. **Validate Config**: Ensure `.env` file is properly configured
4. **Check Hardware**: Verify camera connections and permissions

## 📈 Performance Optimization

### Raspberry Pi Optimization

For optimal performance on Raspberry Pi:

1. **Enable camera interface**: `sudo raspi-config`
2. **Increase GPU memory split**: `gpu_mem=128` in `/boot/config.txt`
3. **Use fast SD card**: Class 10 or better
4. **Ensure adequate power supply**: 5V/3A recommended

### Recording Quality

Adjust recording settings in `.env`:

```bash
# High quality (higher CPU usage)
RECORD_WIDTH=1920
RECORD_HEIGHT=1080
RECORD_FPS=30
RECORDING_BITRATE=10000000

# Balanced quality
RECORD_WIDTH=1280
RECORD_HEIGHT=720
RECORD_FPS=24
RECORDING_BITRATE=5000000

# Low quality (lower CPU usage)
RECORD_WIDTH=640
RECORD_HEIGHT=480
RECORD_FPS=15
RECORDING_BITRATE=2000000
```

## 📄 License

This project is licensed under the MIT License. See the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📞 Support

For support and questions:

- Check the troubleshooting section above
- Review logs and health check output
- Create an issue on GitHub with:
  - System information (`ezrec health`)
  - Error logs (`ezrec logs`)
  - Test results (`test_system.py --save-report`)

---

**Note**: This system is optimized for Raspberry Pi deployment. While it may work on other systems, the installation script and some features are specifically designed for Raspberry Pi OS.
