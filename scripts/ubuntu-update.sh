#!/bin/bash

# WebXR Mesh Exporter - Ubuntu Update Script
# Run this script to update the application on Ubuntu

set -e

APP_DIR="/opt/webxr-mesh-exporter"
APP_NAME="webxr-mesh-exporter"

echo "🔄 Updating WebXR Mesh Exporter..."

# Check if application directory exists
if [ ! -d "$APP_DIR" ]; then
    echo "❌ Application directory not found: $APP_DIR"
    echo "💡 Run the initial setup script first"
    exit 1
fi

cd $APP_DIR

# Check if git repo exists
if [ ! -d ".git" ]; then
    echo "❌ Not a git repository. Please check your installation."
    exit 1
fi

# Create backup
echo "📦 Creating backup..."
tar -czf "/tmp/webxr-backup-$(date +%Y%m%d-%H%M%S).tar.gz" \
    --exclude=node_modules \
    --exclude=.git \
    --exclude=data/logs \
    --exclude=data/export \
    .

# Fetch latest changes
echo "📥 Fetching latest changes from GitHub..."
git fetch origin

# Check if there are updates
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Application is already up to date!"
    pm2 status $APP_NAME
    exit 0
fi

echo "🔄 Updates found. Applying changes..."

# Stash any local changes
git stash push -m "Auto-stash before update $(date)"

# Pull latest changes
git pull origin main

# Check if package.json changed
if git diff --name-only HEAD~1 HEAD | grep -q "package.json"; then
    echo "📦 Package.json changed. Updating dependencies..."
    npm install --production
fi

# Check if nginx config changed
if git diff --name-only HEAD~1 HEAD | grep -q "nginx/"; then
    echo "🌐 Nginx configuration changed. Updating..."
    sudo cp nginx/webxr-mesh-exporter.conf /etc/nginx/sites-available/webxr-mesh-exporter
    sudo nginx -t
    sudo systemctl reload nginx
fi

# Restart the application
echo "🚀 Restarting application..."
pm2 restart $APP_NAME

# Check application health
echo "🏥 Checking application health..."
sleep 5

# Test local connection
if curl -s -f "http://localhost:3000/health" > /dev/null; then
    echo "✅ Application is running locally"
else
    echo "⚠️ Application health check failed on localhost:3000"
fi

# Test through nginx
if curl -s -f "http://localhost/health" > /dev/null; then
    echo "✅ Nginx proxy is working"
else
    echo "⚠️ Nginx proxy health check failed"
fi

# Get server status
echo "📊 Current status:"
pm2 status $APP_NAME

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "UNKNOWN")

echo ""
echo "✅ Update completed successfully!"
echo ""
echo "🌐 Application accessible at:"
echo "   HTTPS: https://industreo.works"
echo "   HTTP:  http://industreo.works (redirects to HTTPS)"
echo "   IP:    $PUBLIC_IP"
echo ""
echo "🚀 WebXR interface: https://industreo.works/mr/"
echo "📱 Main page: https://industreo.works/"
echo ""
echo "🔧 Useful commands:"
echo "   View logs: pm2 logs $APP_NAME"
echo "   App status: pm2 status"
echo "   Nginx logs: sudo tail -f /var/log/nginx/webxr_access.log"
echo "   Nginx status: sudo systemctl status nginx"
echo ""
echo "🗂️ Backup saved to: /tmp/webxr-backup-$(date +%Y%m%d)-*.tar.gz"
