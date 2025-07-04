#!/bin/bash

# WebXR Mesh Exporter - Ubuntu Initial Setup Script
# Run this script on a fresh Ubuntu 24.04 LTS AWS Lightsail instance

set -e

# Configuration
APP_NAME="webxr-mesh-exporter"
APP_DIR="/opt/webxr-mesh-exporter"
DOMAIN="industreo.works"
REPO_URL="https://github.com/Humancannonball/webxr-mesh-exporter.git"
USER_EMAIL="mark20.mikula05@gmail.com"

echo "🚀 Setting up WebXR Mesh Exporter on Ubuntu 24.04..."
echo "📦 Application: $APP_NAME"
echo "📂 Directory: $APP_DIR"
echo "🌐 Domain: $DOMAIN"
echo ""

# Update system
echo "📥 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
echo "🔧 Installing essential packages..."
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    fail2ban \
    snapd \
    build-essential

# Install Node.js 20.x LTS (recommended for Ubuntu 24.04)
echo "📦 Installing Node.js 20.x LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
echo "✅ Node.js version: $(node --version)"
echo "✅ NPM version: $(npm --version)"

# Install PM2 globally
echo "📦 Installing PM2 process manager..."
sudo npm install -g pm2

# Install and configure Nginx
echo "🌐 Installing and configuring Nginx..."
sudo apt install -y nginx

# Install Certbot using snap (recommended for Ubuntu 24.04)
echo "🔐 Installing Certbot via snap..."
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Install Certbot Nginx plugin
sudo snap set certbot trust-plugin-with-root=ok
sudo snap install certbot-dns-cloudflare  # Optional: for DNS challenges

# Create application directory
echo "📂 Creating application directory..."
sudo mkdir -p $APP_DIR
sudo chown -R $USER:$USER $APP_DIR

# Clone repository (handle existing directory)
echo "📥 Cloning repository..."
if [ -d "$APP_DIR/.git" ]; then
    echo "Repository already exists, updating..."
    cd $APP_DIR
    git fetch origin
    git reset --hard origin/main
    git clean -fd
else
    # Remove existing directory if it exists but isn't a git repo
    if [ -d "$APP_DIR" ] && [ "$(ls -A $APP_DIR)" ]; then
        echo "Removing existing non-git directory..."
        sudo rm -rf $APP_DIR/*
    fi
    git clone $REPO_URL $APP_DIR
    cd $APP_DIR
fi

# Install dependencies
echo "📦 Installing Node.js dependencies..."
npm install --production

# Create data directories
echo "📁 Creating data directories..."
mkdir -p data/logs
mkdir -p data/export/json
mkdir -p data/export/stl

# Copy Nginx configuration
echo "🌐 Configuring Nginx..."
sudo cp nginx/webxr-mesh-exporter.conf /etc/nginx/sites-available/webxr-mesh-exporter
sudo ln -sf /etc/nginx/sites-available/webxr-mesh-exporter /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Add rate limiting to main nginx.conf
echo "🔧 Adding rate limiting to nginx.conf..."
if ! grep -q "limit_req_zone.*api:" /etc/nginx/nginx.conf; then
    sudo sed -i '/http {/a\\n\t# Rate limiting zones for WebXR app\n\tlimit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;\n\tlimit_req_zone $binary_remote_addr zone=websocket:10m rate=60r/m;\n' /etc/nginx/nginx.conf
    echo "✅ Rate limiting zones added to nginx.conf"
else
    echo "✅ Rate limiting zones already configured"
fi

# Test Nginx configuration
echo "🔍 Testing Nginx configuration..."
sudo nginx -t

# Configure firewall with improved rules for Ubuntu 24.04
echo "🔒 Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw status verbose

# Configure fail2ban with improved settings for Ubuntu 24.04
echo "🛡️ Configuring fail2ban..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Create custom jail for nginx
sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-noscript]
enabled = true
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
filter = nginx-noproxy
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

sudo systemctl restart fail2ban

# Start services
echo "🚀 Starting services..."
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl reload nginx

# Start the application with PM2
echo "🚀 Starting application..."
if pm2 list | grep -q "webxr-mesh-exporter"; then
    echo "Application already running, restarting..."
    pm2 restart webxr-mesh-exporter
else
    pm2 start config/ecosystem.config.js --env production
fi
pm2 save

# Setup PM2 startup (only if not already configured)
if ! systemctl is-enabled pm2-ubuntu >/dev/null 2>&1; then
    pm2 startup
    echo "📝 Setting up PM2 startup script..."
    sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp /home/$USER
else
    echo "✅ PM2 startup already configured"
fi

# Get SSL certificate
echo "🔐 Setting up SSL certificate..."
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN \
    --email $USER_EMAIL \
    --agree-tos \
    --no-eff-email \
    --redirect

# Test SSL renewal
echo "🔄 Testing SSL certificate renewal..."
sudo certbot renew --dry-run

# Setup automatic renewal with systemd timer (Ubuntu 24.04 style)
echo "⏰ Setting up automatic SSL renewal..."
sudo systemctl enable snap.certbot.renew.timer
sudo systemctl start snap.certbot.renew.timer

# Verify the timer is active
sudo systemctl status snap.certbot.renew.timer --no-pager

# Create update script
echo "📝 Creating update script..."
cat > /home/$USER/update-webxr.sh << 'EOF'
#!/bin/bash
set -e

APP_DIR="/opt/webxr-mesh-exporter"
echo "🔄 Updating WebXR Mesh Exporter..."

cd $APP_DIR
git pull origin main

# Check if package.json changed
if git diff --name-only HEAD~1 HEAD | grep -q "package.json"; then
    echo "📦 Updating dependencies..."
    npm install --production
fi

# Restart application
pm2 restart webxr-mesh-exporter
sudo systemctl reload nginx

echo "✅ Update completed!"
echo "🌐 Application: https://industreo.works"
EOF

chmod +x /home/$USER/update-webxr.sh

# Final status check
echo ""
echo "🏥 Final system status check..."
echo "📊 PM2 processes:"
pm2 status
echo ""
echo "🌐 Nginx status:"
sudo systemctl status nginx --no-pager -l
echo ""
echo "🔐 SSL certificates:"
sudo certbot certificates
echo ""

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "UNKNOWN")

echo "🎉 Setup completed successfully!"
echo ""
echo "🌐 Your application is now accessible at:"
echo "   HTTP:  http://$DOMAIN (redirects to HTTPS)"
echo "   HTTPS: https://$DOMAIN"
echo "   IP:    $PUBLIC_IP"
echo ""
echo "🔧 Management commands:"
echo "   Application logs: pm2 logs webxr-mesh-exporter"
echo "   Application status: pm2 status"
echo "   Nginx logs: sudo tail -f /var/log/nginx/webxr_access.log"
echo "   Update app: ~/update-webxr.sh"
echo ""
echo "🚀 WebXR Mixed Reality interface: https://$DOMAIN/mr/"
echo "📱 Mobile-optimized landing page: https://$DOMAIN/"
echo ""
echo "🎯 Next steps:"
echo "1. Verify your domain DNS points to: $PUBLIC_IP"
echo "2. Test the application at: https://$DOMAIN"
echo "3. Test WebXR functionality at: https://$DOMAIN/mr/"
echo ""
echo "💡 The application is now running with:"
echo "   ✅ Node.js 20.x LTS on port 3000"
echo "   ✅ Nginx reverse proxy on ports 80/443"
echo "   ✅ SSL certificate from Let's Encrypt (via snap)"
echo "   ✅ Automatic HTTPS redirects"
echo "   ✅ www to non-www redirects"
echo "   ✅ PM2 process management"
echo "   ✅ Automatic SSL renewal via systemd timer"
echo "   ✅ Enhanced firewall configuration"
echo "   ✅ Fail2ban with custom nginx rules"
echo "   ✅ Security headers for WebXR"
echo "   ✅ Ubuntu 24.04 LTS optimizations"
