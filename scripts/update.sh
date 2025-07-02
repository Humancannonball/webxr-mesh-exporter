#!/bin/bash

# WebXR Mesh Exporter Update Script
# Run this script on your AWS Lightsail instance to update the application

set -e

APP_DIR="/opt/bitnami/projects/webxr-mesh-exporter"
APP_NAME="webxr-mesh-exporter"

echo "🔄 Updating WebXR Mesh Exporter..."

# Check if we're in the right directory
if [ ! -d "$APP_DIR" ]; then
    echo "❌ Application directory not found: $APP_DIR"
    exit 1
fi

cd $APP_DIR

# Check if git repo exists
if [ ! -d ".git" ]; then
    echo "❌ Not a git repository. Please check your installation."
    exit 1
fi

# Backup current version (optional)
echo "📦 Creating backup..."
tar -czf "/tmp/webxr-backup-$(date +%Y%m%d-%H%M%S).tar.gz" --exclude=node_modules --exclude=.git --exclude=data/logs .

# Fetch latest changes
echo "📥 Fetching latest changes from GitHub..."
git fetch origin

# Check if there are updates
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Application is already up to date!"
    sudo pm2 status $APP_NAME
    exit 0
fi

echo "🔄 Updates found. Applying changes..."

# Stash any local changes (if any)
git stash push -m "Auto-stash before update $(date)"

# Pull latest changes
git pull origin main

# Check if package.json changed
if git diff --name-only HEAD~1 HEAD | grep -q "package.json"; then
    echo "📦 Package.json changed. Updating dependencies..."
    npm install --production
fi

# Restart the application (requires sudo for port 80)
echo "🚀 Restarting application..."
sudo pm2 restart $APP_NAME

# Check application health
echo "🏥 Checking application health..."
sleep 5

if curl -s -f "http://localhost/health" > /dev/null; then
    echo "✅ Application updated successfully!"
    echo "📊 Current status:"
    sudo pm2 status $APP_NAME
    echo ""
    echo "🌐 Application accessible at:"
    echo "   HTTP:  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'YOUR_INSTANCE_IP')"
    echo "   HTTPS: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'YOUR_INSTANCE_IP')"
else
    echo "❌ Application health check failed!"
    echo "📝 Check logs: sudo pm2 logs $APP_NAME"
    exit 1
fi

echo ""
echo "💡 Update completed successfully!"
echo "🗂️ Backup saved to: /tmp/webxr-backup-$(date +%Y%m%d)-*.tar.gz"
