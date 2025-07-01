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

# Make scripts executable
echo "🔐 Making scripts executable..."
chmod +x scripts/update.sh scripts/setup-dns.sh

# Configure Apache virtual host
echo "🌐 Configuring Apache virtual host..."
sudo cp apache/webxr-mesh-exporter.conf /opt/bitnami/apache/conf/vhosts/webxr-mesh-exporter.conf

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
echo "🌐 To set up a custom domain:"
echo "   1. Point your domain's A record to this server's IP"
echo "   2. Wait for DNS propagation"
echo "   3. Run: ./scripts/setup-dns.sh yourdomain.com"
echo ""
echo "🔒 For SSL setup after domain configuration:"
echo "   sudo /opt/bitnami/bncert-tool"
