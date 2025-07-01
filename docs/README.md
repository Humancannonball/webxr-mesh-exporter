# WebXR Mesh and Plane Export Tool

## Mixed Reality Robot Programming Platform

A WebXR-based application for capturing and exporting 3D environment data from Meta Quest 3 devices for robot programming and simulation. This tool scans environments using WebXR's mesh detection APIs and exports the data in formats suitable for ROS2, Gazebo, and other robotics platforms.

## Features

- 🥽 **WebXR Mesh Detection**: Capture real-world 3D geometry using Meta Quest 3
- 🌐 **Multi-user Support**: Real-time collaboration with Socket.IO
- 📡 **Data Export**: Export scanned environments to JSON and URDF formats
- 🤖 **Robotics Integration**: Compatible with ROS2, Gazebo, and Nav2
- ☁️ **AWS Ready**: Optimized for deployment on AWS Lightsail

## System Requirements

- Meta Quest 3 or other WebXR-compatible device
- Modern web browser with WebXR support
- Node.js 16+ (for server deployment)

## AWS Lightsail Deployment

1. **Create a new AWS Lightsail instance** with "Node.js Packaged by Bitnami"
2. **Instance Size**: Minimum 1 GB RAM (2 GB recommended)
3. **Launch Script**: Copy and paste the content of `scripts/lightsail-setup.sh` into the launch script field
4. **Networking**: Ensure ports 80 (HTTP) and 443 (HTTPS) are open in the firewall

After deployment, access your application at `http://your-instance-ip` or `https://your-instance-ip`

## Usage

### WebXR Controls

- **Trigger**: Test AR functionality
- **X Button**: Toggle environment visibility
- **Y Button**: Export scene to server

### Management Commands

```bash
# Check application status
pm2 status

# View logs
pm2 logs webxr-mesh-exporter

# Restart application
pm2 restart webxr-mesh-exporter

# Update application from GitHub
./scripts/update.sh

# Manual update process
cd /opt/bitnami/projects/webxr-mesh-exporter
git pull origin main
npm install --production  # Only if package.json changed
pm2 restart webxr-mesh-exporter
```

### SSL Configuration

For custom domain with SSL:
```bash
sudo /opt/bitnami/bncert-tool
```

## API Endpoints

- `GET /`: Main application interface
- `GET /health`: Health check endpoint
- `WebSocket /`: Real-time communication for multi-user features

## File Structure

```
webxr-mesh-exporter/
├── src/                          # Source code
│   ├── server.js                 # Node.js/Express server
│   ├── client.js                 # WebXR client-side application
│   └── public/                   # Static files served to clients
│       ├── index.html            # Main HTML interface
│       ├── style.css             # Application styles
│       └── js/                   # Client-side JavaScript modules
│           ├── ARButton.js       # WebXR AR button component
│           └── RapierPhysics.js  # Physics engine integration
├── config/                       # Configuration files
│   ├── ecosystem.config.js       # PM2 process configuration
│   └── .env.example              # Environment variables template
├── scripts/                      # Deployment and utility scripts
│   ├── lightsail-setup.sh        # AWS Lightsail automated setup
│   └── update.sh                 # Application update script
├── data/                         # Application data (excluded from git)
│   ├── export/                   # Exported scene data
│   │   └── json/                 # JSON scene exports
│   └── logs/                     # Application logs
├── docs/                         # Documentation
│   └── README.md                 # Main documentation
├── tools/                        # Development and conversion tools
│   ├── json_to_urdf.py           # Convert JSON to URDF format
│   └── convert_to_urdf.sh        # URDF conversion wrapper script
├── package.json                  # Node.js dependencies and scripts
└── .gitignore                    # Git ignore rules
```
