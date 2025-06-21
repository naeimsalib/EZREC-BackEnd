# EZREC Backend

Backend services and system components for the EZREC SmartCam Soccer system.

## 🚨 Raspberry Pi Deployment & Update 🚨

**For all Raspberry Pi deployments and updates, use ONLY the `raspberry_pi_setup.sh` script.**

- This script will install all dependencies, set up the correct user, configure systemd services, and ensure all permissions are correct for the Pi.
- The legacy `complete_update.sh` script is now removed and should NOT be used.
- All updates and management should be done via the `manage.sh` script in `/opt/ezrec-backend`.

### To deploy or update on your Raspberry Pi:

```bash
# 1. Clone or pull the latest code
cd /opt/ezrec-backend || git clone https://github.com/naeimsalib/EZREC-BackEnd.git /opt/ezrec-backend
cd /opt/ezrec-backend

# 2. Run the setup script (for fresh install or update)
sudo ./raspberry_pi_setup.sh

# 3. Edit your .env file if needed
sudo nano /opt/ezrec-backend/.env

# 4. Start the system
sudo /opt/ezrec-backend/manage.sh start

# 5. Check status/logs
sudo /opt/ezrec-backend/manage.sh status
sudo /opt/ezrec-backend/manage.sh logs

# 6. To update in the future
cd /opt/ezrec-backend
sudo /opt/ezrec-backend/manage.sh update
```

---

## Overview

This repository contains all the backend services, systemd configurations, and server-side code for the EZREC SmartCam Soccer system. The frontend application is maintained in a separate repository: [EZREC-FrontEnd](https://github.com/naeimsalib/EZREC-FrontEnd.git).

## System Architecture

### Core Services

1. **Camera Service** (`src/camera_service.py`)
   - Handles camera operations and recording
   - Manages video capture and storage
   - Integrates with YOLO object detection

2. **Scheduler Service** (`src/scheduler_service.py`)
   - Manages recording schedules and automation
   - Handles booking system integration
   - Coordinates with camera service

3. **Orchestrator Service** (`src/orchestrator.py`)
   - Coordinates between different system components
   - Manages system health monitoring
   - Handles database operations

### System Configuration

- **systemd Services**: Service files for automatic startup and management
- **Environment Configuration**: Backend environment variables and settings
- **Database Integration**: Supabase integration for data storage

## Installation

### Prerequisites

- Raspberry Pi OS (Bullseye or newer)
- Raspberry Pi 4 (recommended) or 3B+
- Camera hardware (USB or Pi Camera)
- Supabase account and project

### Quick Setup (Raspberry Pi)

1. Clone the repository:
```bash
git clone https://github.com/naeimsalib/EZREC-BackEnd.git
cd EZREC-BackEnd
```

2. Run the Pi setup script:
```bash
chmod +x raspberry_pi_setup.sh
sudo ./raspberry_pi_setup.sh
```

3. Configure environment variables:
```bash
sudo nano /opt/ezrec-backend/.env
```

4. Start the system:
```bash
sudo /opt/ezrec-backend/manage.sh start
```

5. Check status/logs:
```bash
sudo /opt/ezrec-backend/manage.sh status
sudo /opt/ezrec-backend/manage.sh logs
```

6. Update in the future:
```bash
cd /opt/ezrec-backend
sudo /opt/ezrec-backend/manage.sh update
```

---

## For Developers (Non-Pi)

- You may use a virtual environment and run the code for development, but all deployment and service management must be done via the Pi scripts above.
- The codebase is fully compatible with Raspberry Pi OS and will auto-detect camera hardware.

---

## Troubleshooting

- If you encounter issues, use the health check:
```bash
sudo /opt/ezrec-backend/manage.sh health
```
- Check logs for errors:
```bash
sudo /opt/ezrec-backend/manage.sh logs
```
- Ensure your `.env` file is correct and all permissions are set as per the setup script.

---

## Support

For issues and questions:
- Check the troubleshooting section
- Review logs for error messages
- Create an issue on GitHub

## Usage

### Running Services

#### Development Mode
```bash
# Run individual services
python src/camera_service.py
python src/scheduler_service.py
python src/orchestrator.py
```

#### Production Mode (systemd)
```bash
# Start all services
sudo systemctl start smartcam-camera smartcam-scheduler smartcam-orchestrator

# Check status
sudo systemctl status smartcam-camera smartcam-scheduler smartcam-orchestrator

# View logs
sudo journalctl -u smartcam-camera -f
sudo journalctl -u smartcam-scheduler -f
sudo journalctl -u smartcam-orchestrator -f
```

### Database Setup

The system uses Supabase for data storage. Key tables include:

- `recordings`: Video recording metadata
- `bookings`: Field booking information
- `system_status`: Real-time system status
- `system_health`: System health metrics
- `network_status`: Network connectivity data

### Configuration

#### Camera Configuration
- Set `CAMERA_DEVICE` in environment variables
- Configure recording quality in `src/camera_service.py`
- Adjust YOLO model settings as needed

#### Recording Settings
- Recording duration and quality
- Storage management
- Upload settings to Supabase

## Development

### Project Structure
```
src/
├── camera_service.py      # Camera operations
├── scheduler_service.py   # Scheduling logic
├── orchestrator.py        # Service coordination
├── database.py           # Database operations
└── utils/                # Utility functions

systemd/                  # systemd service files
tests/                    # Test files
migrations/               # Database migrations
```

### Testing

Run tests to ensure everything is working:
```bash
python -m pytest tests/
```

### Logging

Logs are stored in:
- `logs.txt`: General application logs
- `logs_last_10min.txt`: Recent activity
- System logs via journalctl

## API Endpoints

The backend provides several API endpoints for the frontend:

- `GET /api/system-status`: Get current system status
- `GET /api/recordings`: List recordings
- `POST /api/bookings`: Create new booking
- `GET /api/health`: System health check

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is part of the EZREC SmartCam Soccer system.

## Support

For issues and questions:
- Check the troubleshooting section
- Review logs for error messages
- Create an issue on GitHub 