# EZREC Backend

Backend services and system components for the EZREC SmartCam Soccer system.

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

- Python 3.8+
- Raspberry Pi (for camera services)
- Supabase account and project
- Camera hardware (USB or Pi Camera)

### Quick Setup

1. Clone the repository:
```bash
git clone https://github.com/naeimsalib/EZREC-BackEnd.git
cd EZREC-BackEnd
```

2. Run the automated setup:
```bash
chmod +x setup.sh
./setup.sh
```

3. Configure environment variables:
Create a `.env` file with your Supabase credentials:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_service_key
CAMERA_DEVICE=/dev/video0
RECORDING_PATH=/path/to/recordings
```

4. Set up systemd services:
```bash
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable smartcam-camera smartcam-scheduler smartcam-orchestrator
sudo systemctl start smartcam-camera smartcam-scheduler smartcam-orchestrator
```

### Manual Installation

If you prefer manual installation:

1. Install Python dependencies:
```bash
pip install -r requirements.txt
```

2. Set up virtual environment:
```bash
python -m venv venv
source venv/bin/activate
```

3. Install system dependencies:
```bash
chmod +x install_dependencies.sh
./install_dependencies.sh
```

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

## Troubleshooting

### Common Issues

1. **Camera not detected**
   - Check camera permissions
   - Verify device path in environment variables
   - Ensure camera is properly connected

2. **Services not starting**
   - Check systemd service status
   - Verify environment variables
   - Check log files for errors

3. **Database connection issues**
   - Verify Supabase credentials
   - Check network connectivity
   - Ensure database tables exist

### Debug Mode

Enable debug logging by setting:
```env
DEBUG=true
LOG_LEVEL=DEBUG
```

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