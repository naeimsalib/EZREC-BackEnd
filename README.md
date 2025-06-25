# EZREC Backend - Raspberry Pi Camera Recording System

🎬 **Automated camera recording system** for Raspberry Pi with Supabase integration. Perfect for sports recording, security, or any scheduled recording needs.

## ✨ Features

- 🎯 **Automatic Recording**: Schedule-based recording with precise timing
- 📹 **Smart Camera Support**: Pi Camera + USB camera fallback
- 🔄 **Real-time Monitoring**: Live status updates to dashboard
- 🛡️ **Production Ready**: Systemd service with error recovery
- 📊 **Health Monitoring**: Comprehensive diagnostics and logging
- ☁️ **Cloud Integration**: Supabase database synchronization

## 🚀 One-Command Installation

**For a fresh Raspberry Pi:**

```bash
# 1. Clone the repository
git clone https://github.com/naeimsalib/EZREC-BackEnd.git
cd EZREC-BackEnd

# 2. Run complete installation (one command!)
sudo ./deploy_ezrec.sh

# 3. Configure your Supabase credentials
sudo ./create_env_file.sh
sudo nano /opt/ezrec-backend/.env  # Add your Supabase details

# 4. Start the service
sudo systemctl start ezrec-backend
sudo systemctl enable ezrec-backend

# 5. Verify everything works
./check_recordings.sh
```

**That's it! Your Pi is now ready for automatic recording.** 🎉

## 📋 Prerequisites

- **Hardware**: Raspberry Pi 4 (recommended) or Pi 3B+
- **OS**: Raspberry Pi OS (Bullseye or newer)
- **Camera**: Pi Camera module or USB camera
- **Network**: WiFi or Ethernet connection
- **Account**: Free Supabase account

## ⚙️ Configuration

### Supabase Setup

1. Create a free account at [supabase.com](https://supabase.com)
2. Create a new project
3. Get your Project URL and Service Role Key from Settings → API
4. Add them to `/opt/ezrec-backend/.env`:

```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
USER_ID=your_unique_user_id
CAMERA_ID=raspberry_pi_camera
```

### Database Tables

EZREC automatically works with these Supabase tables:

- `bookings`: Scheduled recording sessions
- `system_status`: Real-time Pi status
- `cameras`: Camera visibility for dashboard

## 🎬 How It Works

1. **Booking Creation**: Create bookings in Supabase with camera_id and schedule
2. **Auto-Detection**: EZREC polls for new bookings every 5 seconds
3. **Smart Recording**: Automatically starts/stops at scheduled times
4. **Status Updates**: Reports camera status to dashboard every 10 seconds
5. **File Management**: Saves recordings to `/opt/ezrec-backend/recordings/`

## 📱 Management Commands

### Check Status & Recordings

```bash
./check_recordings.sh                    # Complete status check
sudo systemctl status ezrec-backend      # Service status
sudo journalctl -u ezrec-backend -f      # Live logs
ls -la /opt/ezrec-backend/recordings/    # View recordings
```

### Troubleshooting

```bash
./camera_diagnostic.py                   # Camera diagnostics
./debug_camera_bookings.py              # Booking detection debug
./verify_installation.sh                # Full system check
./restart_ezrec.sh                      # Service restart
```

### System Snapshot (for replication)

```bash
./system_snapshot.sh > my_setup.txt     # Capture complete setup
```

## 🔧 Advanced Configuration

### Camera Settings

```bash
# Edit /opt/ezrec-backend/.env
RECORD_WIDTH=1920           # Recording resolution
RECORD_HEIGHT=1080
RECORD_FPS=30               # Frames per second
RECORDING_BITRATE=10000000  # Video quality
```

### Performance Tuning

```bash
DEBUG=false                 # Disable for production
LOG_LEVEL=INFO             # ERROR, WARN, INFO, DEBUG
BOOKING_CHECK_INTERVAL=5   # Seconds between booking checks
STATUS_UPDATE_INTERVAL=10  # Dashboard update frequency
```

## 🔄 Multiple Pi Setup

**Deploy to additional Raspberry Pis:**

1. Use unique `CAMERA_ID` for each Pi (e.g., `camera_1`, `camera_2`)
2. Run the same installation commands
3. Each Pi operates independently
4. All cameras appear in the same dashboard

## 📊 Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Dashboard     │    │   Supabase   │    │  Raspberry Pi   │
│   (Web App)     │◄──►│   Database   │◄──►│   EZREC Backend │
└─────────────────┘    └──────────────┘    └─────────────────┘
                                                    │
                                            ┌───────▼───────┐
                                            │  Pi Camera /  │
                                            │  USB Camera   │
                                            └───────────────┘
```

## 🛠️ Troubleshooting Guide

### Common Issues

**Service won't start:**

```bash
sudo journalctl -u ezrec-backend --no-pager
./verify_installation.sh
```

**Camera not detected:**

```bash
./camera_diagnostic.py
# Check camera connections and permissions
```

**No bookings detected:**

```bash
./debug_camera_bookings.py
# Verify Supabase connection and camera_id matching
```

**Permission errors:**

```bash
sudo ./fix_camera_issues.sh
# Fixes camera access and WirePlumber conflicts
```

### Expert Recovery

```bash
# Complete reinstallation
sudo ./deploy_ezrec.sh

# Virtual environment issues
sudo ./fix_picamera2_venv.sh

# Supabase compatibility
sudo ./fix_supabase_compatibility.sh
```

## 📁 Project Structure

```
EZREC-BackEnd/
├── 🚀 deploy_ezrec.sh              # One-command installer
├── 📊 check_recordings.sh          # Status checker
├── 📸 system_snapshot.sh           # System replication
├── 🔧 Installation Scripts/
│   ├── install_ezrec.sh            # Core installation
│   ├── setup_pi_env.sh             # Pi environment setup
│   └── create_env_file.sh          # Environment configuration
├── 🛠️ Diagnostic Tools/
│   ├── camera_diagnostic.py        # Camera troubleshooting
│   ├── debug_camera_bookings.py    # Booking detection debug
│   └── verify_installation.sh      # Full system verification
├── 🔧 Fix Scripts/
│   ├── fix_camera_issues.sh        # Camera access fixes
│   ├── fix_picamera2_venv.sh       # Virtual environment fixes
│   └── fix_supabase_compatibility.sh # Database compatibility
├── 📁 src/                         # Core application code
├── 📁 migrations/                  # Database migrations
└── 📋 Documentation/
    ├── README.md                   # This file
    ├── CAMERA_TROUBLESHOOTING.md   # Camera-specific help
    └── requirements.txt            # Python dependencies
```

## 🔗 Related Projects

This backend works with:

- **EZREC Dashboard**: Web interface for camera management
- **EZREC Mobile App**: Mobile control and monitoring
- **EZREC Analytics**: Recording analysis and highlights

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with `./verify_installation.sh`
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/naeimsalib/EZREC-BackEnd/issues)
- **Discussions**: [GitHub Discussions](https://github.com/naeimsalib/EZREC-BackEnd/discussions)
- **Documentation**: [CAMERA_TROUBLESHOOTING.md](CAMERA_TROUBLESHOOTING.md)

---

**Made with ❤️ for the Raspberry Pi community**

_Inspired by projects like [ezbeq](https://ezbeq.readthedocs.io/en/latest/rpi/) that show how powerful automated Pi installations can be._
