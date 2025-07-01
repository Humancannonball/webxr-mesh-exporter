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

### Step 1: Basic Setup

1. **Create a new AWS Lightsail instance** with "Node.js Packaged by Bitnami"
2. **Instance Size**: Minimum 1 GB RAM (2 GB recommended)
3. **Launch Script**: Copy and paste the content of `scripts/lightsail-setup.sh` into the launch script field
4. **Networking**: Ensure ports 80 (HTTP) and 443 (HTTPS) are open in the firewall

After deployment, your application will be accessible at `http://your-instance-ip`

### Step 2: Custom Domain Setup (Optional)

If you want to use your own domain:

1. **Configure DNS**: Point your domain's A record to your Lightsail instance IP
2. **Wait for propagation**: DNS changes can take up to 24 hours
3. **Run DNS setup**: SSH into your instance and run:
   ```bash
   cd /opt/bitnami/projects/webxr-mesh-exporter
   ./scripts/setup-dns.sh yourdomain.com
   ```
4. **Set up SSL**: After domain is working, run:
   ```bash
   sudo /opt/bitnami/bncert-tool
   ```

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

# Set up custom domain (after DNS is configured)
./scripts/setup-dns.sh yourdomain.com

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
├── apache/                       # Apache configuration files
│   ├── webxr-mesh-exporter.conf  # Default Apache virtual host
│   └── webxr-mesh-exporter-domain.conf # Domain-specific template
├── scripts/                      # Deployment and utility scripts
│   ├── lightsail-setup.sh        # AWS Lightsail automated setup
│   ├── setup-dns.sh              # Custom domain configuration
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
