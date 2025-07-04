#!/bin/bash

# WebXR Mesh Exporter - Ubuntu 24.04 Complete Setup
# One script to deploy everything on a fresh Ubuntu 24.04 instance

set -e

# Configuration
APP_NAME="webxr-mesh-exporter"
APP_DIR="/opt/webxr-mesh-exporter"
DOMAIN="industreo.works"
REPO_URL="https://github.com/Humancannonball/webxr-mesh-exporter.git"
USER_EMAIL="mark20.mikula05@gmail.com"

echo "🚀 WebXR Mesh Exporter - Complete Setup"
echo "=========================================="
echo "📦 Application: $APP_NAME"
echo "📂 Directory: $APP_DIR"
echo "🌐 Domain: $DOMAIN"
echo ""

# Update system
echo "📥 Updating system..."
sudo apt update && sudo apt upgrade -y

# Install everything
echo "🔧 Installing packages..."
sudo apt install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release ufw fail2ban snapd build-essential nginx

# Install Node.js 20.x
echo "📦 Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2
echo "📦 Installing PM2..."
sudo npm install -g pm2

# Install Certbot
echo "🔐 Installing Certbot..."
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Setup application
echo "📂 Setting up application..."
sudo mkdir -p $APP_DIR
sudo chown -R $USER:$USER $APP_DIR

if [ -d "$APP_DIR/.git" ]; then
    echo "Updating existing repository..."
    cd $APP_DIR
    git pull origin main
else
    echo "Cloning repository..."
    git clone $REPO_URL $APP_DIR
    cd $APP_DIR
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install --production

# Create data directories
mkdir -p data/logs data/export/json data/export/stl

# Create simple Nginx config
echo "🌐 Creating Nginx configuration..."
sudo tee /etc/nginx/sites-available/webxr-mesh-exporter << 'EOF'
server {
    listen 80;
    server_name industreo.works www.industreo.works;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/webxr-mesh-exporter /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Create web root
sudo mkdir -p /var/www/html
sudo chown -R www-data:www-data /var/www/html

# Configure firewall
echo "🔒 Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Start services
echo "🚀 Starting services..."
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Start application
echo "🚀 Starting application..."
PORT=3000 pm2 start src/server.js --name webxr-mesh-exporter
pm2 save
pm2 startup

# Verify application is running
echo "🔍 Verifying application..."
sleep 3
if pm2 list | grep -q "online"; then
    echo "✅ Application is running"
    pm2 status
    
    # Test if app responds on port 3000
    if curl -s http://localhost:3000 >/dev/null; then
        echo "✅ Application responding on port 3000"
    else
        echo "❌ Application not responding on port 3000"
    fi
else
    echo "❌ Application failed to start. Checking logs..."
    pm2 logs webxr-mesh-exporter --lines 20
    echo "🔧 Attempting to restart..."
    pm2 restart webxr-mesh-exporter || PORT=3000 pm2 start src/server.js --name webxr-mesh-exporter
fi

# Get SSL certificate
echo "🔐 Getting SSL certificate..."
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --email $USER_EMAIL --agree-tos --no-eff-email --redirect --non-interactive || echo "⚠️  SSL setup failed, app running on HTTP"

# Fix nginx config after Certbot (Certbot sometimes breaks the proxy)
echo "🔧 Ensuring proxy settings are correct after SSL setup..."
sudo tee /etc/nginx/sites-available/webxr-mesh-exporter << 'EOF'
server {
    listen 80;
    server_name industreo.works www.industreo.works;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name industreo.works www.industreo.works;
    
    ssl_certificate /etc/letsencrypt/live/industreo.works/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/industreo.works/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
    }
}
EOF

# Reload nginx with the fixed config
sudo systemctl reload nginx

# Test HTTPS
echo "🔍 Testing HTTPS..."
if curl -I -k https://localhost >/dev/null 2>&1; then
    echo "✅ HTTPS is working"
else
    echo "⚠️  HTTPS test failed"
fi

# Final status
echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "========================"
echo "🌐 Your app is running at:"
echo "   - HTTP:  http://$DOMAIN"
echo "   - HTTPS: https://$DOMAIN (if SSL worked)"
echo ""
echo "🔧 Management:"
echo "   - View logs: pm2 logs webxr-mesh-exporter"
echo "   - Restart: pm2 restart webxr-mesh-exporter"
echo "   - Stop: pm2 stop webxr-mesh-exporter"
echo ""
