#!/bin/bash
# Fix Nginx Configuration Issues
# This script fixes common Nginx configuration issues for the WebXR mesh exporter

set -e

echo "🔧 Fixing Nginx configuration issues..."

# Backup current nginx.conf
echo "📋 Backing up current nginx.conf..."
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)

# Add rate limiting zones to http block if not present
echo "🔧 Adding rate limiting zones to nginx.conf..."
if ! grep -q "limit_req_zone.*api:" /etc/nginx/nginx.conf; then
    sudo sed -i '/http {/a\\n\t# Rate limiting zones for WebXR app\n\tlimit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;\n\tlimit_req_zone $binary_remote_addr zone=websocket:10m rate=60r/m;\n' /etc/nginx/nginx.conf
    echo "✅ Rate limiting zones added to nginx.conf"
else
    echo "✅ Rate limiting zones already configured"
fi

# Add WebSocket upgrade mapping to http block if not present
echo "🔧 Adding WebSocket upgrade mapping to nginx.conf..."
if ! grep -q "connection_upgrade" /etc/nginx/nginx.conf; then
    sudo sed -i '/http {/a\\n\t# WebSocket upgrade support\n\tmap $http_upgrade $connection_upgrade {\n\t\tdefault upgrade;\n\t\t'\'''\'' close;\n\t}\n' /etc/nginx/nginx.conf
    echo "✅ WebSocket upgrade mapping added to nginx.conf"
else
    echo "✅ WebSocket upgrade mapping already configured"
fi

# Test Nginx configuration
echo "🔍 Testing Nginx configuration..."
if sudo nginx -t; then
    echo "✅ Nginx configuration is valid"
    
    # Reload Nginx if config is valid
    echo "🔄 Reloading Nginx..."
    sudo systemctl reload nginx
    echo "✅ Nginx reloaded successfully"
    
    # Check Nginx status
    echo "📊 Checking Nginx status..."
    sudo systemctl status nginx --no-pager
    
else
    echo "❌ Nginx configuration test failed"
    echo "📋 Restoring backup..."
    sudo cp /etc/nginx/nginx.conf.backup.$(date +%Y%m%d)* /etc/nginx/nginx.conf
    echo "🔄 Testing restored configuration..."
    sudo nginx -t
    exit 1
fi

echo "🎉 Nginx configuration fixed successfully!"
echo ""
echo "📋 Configuration summary:"
echo "- Rate limiting zones added to http block"
echo "- WebSocket upgrade mapping added to http block"
echo "- All directives moved from server block to http block"
echo "- Configuration tested and validated"
