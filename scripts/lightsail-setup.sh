#!/bin/bash

# AWS Lightsail Setup Script for WebXR Mesh Exporter
# Run this script when creating your Lightsail instance with Node.js Packaged by Bitnami

set -e

echo "🚀 Starting WebXR Mesh Exporter setup on AWS Lightsail..."

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update -y

# Install git if not present
echo "🔧 Installing git..."
sudo apt-get install -y git

# Navigate to projects directory
cd /opt/bitnami/projects

# Clone the repository
echo "📥 Cloning WebXR Mesh Exporter repository..."
sudo git clone https://github.com/Humancannonball/webxr-mesh-exporter.git
cd webxr-mesh-exporter

# Set proper ownership
echo "🔑 Setting proper file ownership..."
sudo chown -R bitnami:bitnami /opt/bitnami/projects/webxr-mesh-exporter

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm install --production

# Install PM2 globally
echo "⚙️ Installing PM2 process manager..."
sudo npm install -g pm2

# Create logs and export directories
echo "📝 Creating required directories..."
mkdir -p data/logs
mkdir -p data/export/json

# Create environment file
echo "🌍 Creating production environment file..."
cat > .env << EOF
NODE_ENV=production
PORT=3000
EOF

# Make update script executable
echo "🔐 Making update script executable..."
chmod +x scripts/update.sh

# Configure Apache virtual host
echo "🌐 Configuring Apache virtual host..."
sudo tee /opt/bitnami/apache/conf/vhosts/webxr-mesh-exporter.conf > /dev/null << EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /opt/bitnami/projects/webxr-mesh-exporter
    
    # Proxy WebSocket connections
    ProxyPreserveHost On
    ProxyRequests Off
    
    # WebSocket proxy
    ProxyPass /socket.io/ ws://localhost:3000/socket.io/
    ProxyPassReverse /socket.io/ ws://localhost:3000/socket.io/
    
    # HTTP proxy for everything else
    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/
    
    # Enable WebSocket upgrade
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://localhost:3000/\$1" [P,L]
    
    ErrorLog /opt/bitnami/apache/logs/webxr_error.log
    CustomLog /opt/bitnami/apache/logs/webxr_access.log combined
</VirtualHost>

<VirtualHost *:443>
    ServerName localhost
    DocumentRoot /opt/bitnami/projects/webxr-mesh-exporter
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /opt/bitnami/apache/conf/bitnami/certs/server.crt
    SSLCertificateKeyFile /opt/bitnami/apache/conf/bitnami/certs/server.key
    
    # Proxy WebSocket connections
    ProxyPreserveHost On
    ProxyRequests Off
    
    # WebSocket proxy
    ProxyPass /socket.io/ ws://localhost:3000/socket.io/
    ProxyPassReverse /socket.io/ ws://localhost:3000/socket.io/
    
    # HTTP proxy for everything else
    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/
    
    # Enable WebSocket upgrade
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://localhost:3000/\$1" [P,L]
    
    ErrorLog /opt/bitnami/apache/logs/webxr_ssl_error.log
    CustomLog /opt/bitnami/apache/logs/webxr_ssl_access.log combined
</VirtualHost>
EOF

# Enable required Apache modules
echo "🔧 Enabling Apache modules..."
sudo a2enmod rewrite
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_wstunnel
sudo a2enmod ssl

# Start the application with PM2
echo "🚀 Starting application with PM2..."
pm2 start config/ecosystem.config.js --env production

# Save PM2 configuration
echo "💾 Saving PM2 configuration..."
pm2 save

# Setup PM2 to start on boot
echo "🔄 Setting up PM2 to start on boot..."
pm2 startup | tail -1 | sudo bash

# Restart Apache to apply configuration
echo "🔄 Restarting Apache..."
sudo /opt/bitnami/ctlscript.sh restart apache

# Create a simple status check script
echo "📊 Creating status check script..."
cat > status-check.sh << 'EOF'
#!/bin/bash
echo "=== WebXR Mesh Exporter Status ==="
echo "PM2 Status:"
pm2 status
echo ""
echo "Application Health:"
curl -s http://localhost:3000/health | python3 -m json.tool
echo ""
echo "Apache Status:"
sudo /opt/bitnami/ctlscript.sh status apache
EOF

chmod +x status-check.sh

# Final status check
echo "✅ Setup complete! Running status check..."
sleep 5
./status-check.sh

echo ""
echo "🎉 WebXR Mesh Exporter setup completed successfully!"
echo ""
echo "📍 Access your application at:"
echo "   HTTP:  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "   HTTPS: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "🔧 Useful commands:"
echo "   pm2 status                    - Check application status"
echo "   pm2 logs webxr-mesh-exporter  - View application logs"
echo "   pm2 restart webxr-mesh-exporter - Restart application"
echo "   ./status-check.sh             - Run comprehensive status check"
echo ""
echo "📚 For SSL setup with custom domain, run: sudo /opt/bitnami/bncert-tool"
