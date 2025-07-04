#!/bin/bash
# Test the current deployment and help with SSL issues

echo "🔍 Testing WebXR Mesh Exporter Deployment"
echo "========================================"

# Check if we're on the server
if [[ $HOSTNAME == *"ip-"* ]] || [[ $HOSTNAME == *"aws"* ]]; then
    echo "✅ Running on server: $HOSTNAME"
    SERVER_MODE=true
else
    echo "📱 Running locally: $HOSTNAME"
    SERVER_MODE=false
fi

# Test Nginx configuration
echo ""
echo "🔧 Testing Nginx Configuration:"
if nginx -t 2>/dev/null; then
    echo "✅ Nginx configuration is valid"
    
    # Check if Nginx is running
    if systemctl is-active --quiet nginx; then
        echo "✅ Nginx is running"
    else
        echo "❌ Nginx is not running"
        if [ "$SERVER_MODE" = true ]; then
            echo "🔄 Attempting to start Nginx..."
            sudo systemctl start nginx
        fi
    fi
else
    echo "❌ Nginx configuration has errors:"
    nginx -t
fi

# Test application
echo ""
echo "📱 Testing Node.js Application:"
APP_DIR="/opt/webxr-mesh-exporter"
if pm2 status | grep -q "webxr-mesh-exporter"; then
    echo "✅ Application is running via PM2"
    pm2 status | grep "webxr-mesh-exporter"
else
    echo "❌ Application is not running"
    if [ "$SERVER_MODE" = true ]; then
        echo "🔄 Attempting to start application..."
        cd "$APP_DIR" || cd /home/ubuntu/webxr-mesh-exporter
        if [ -f "config/ecosystem.config.js" ]; then
            pm2 start config/ecosystem.config.js --env production
        else
            echo "❌ ecosystem.config.js not found in $(pwd)"
            echo "📁 Available files:"
            ls -la config/ 2>/dev/null || echo "No config directory found"
        fi
    fi
fi

# Check port 3000
echo ""
echo "🔌 Testing Port 3000:"
if netstat -tlnp 2>/dev/null | grep -q ":3000 "; then
    echo "✅ Port 3000 is in use"
else
    echo "❌ Port 3000 is not in use"
fi

# Test HTTP access
echo ""
echo "🌐 Testing HTTP Access:"
if curl -I -s --connect-timeout 5 http://localhost 2>/dev/null | grep -q "HTTP"; then
    echo "✅ Local HTTP access works"
else
    echo "❌ Local HTTP access failed"
fi

# Check SSL certificates
echo ""
echo "🔐 SSL Certificate Status:"
DOMAIN="industreo.works"
SSL_CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
SSL_KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

if [ -f "$SSL_CERT_PATH" ] && [ -f "$SSL_KEY_PATH" ]; then
    echo "✅ SSL certificates found"
    if [ "$SERVER_MODE" = true ]; then
        echo "📋 Certificate details:"
        sudo certbot certificates 2>/dev/null | grep -A 5 "Certificate Name: $DOMAIN" || echo "No certificate details available"
    fi
else
    echo "❌ SSL certificates not found"
    echo "📋 SSL certificates should be at:"
    echo "   - Certificate: $SSL_CERT_PATH"
    echo "   - Private Key: $SSL_KEY_PATH"
fi

# Check domain accessibility
echo ""
echo "🌍 Testing Domain Accessibility:"
if [ "$SERVER_MODE" = true ]; then
    # Get public IP (try multiple methods)
    PUBLIC_IP=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || \
                curl -s --connect-timeout 5 http://checkip.amazonaws.com 2>/dev/null || \
                curl -s --connect-timeout 5 https://ipinfo.io/ip 2>/dev/null || \
                echo "UNKNOWN")
    echo "📍 Server Public IP: $PUBLIC_IP"
    
    # Test domain resolution
    if nslookup $DOMAIN 2>/dev/null | grep -q "Address"; then
        DOMAIN_IP=$(nslookup $DOMAIN 2>/dev/null | grep "Address" | tail -1 | awk '{print $2}')
        echo "📍 Domain resolves to: $DOMAIN_IP"
        
        if [ "$DOMAIN_IP" = "$PUBLIC_IP" ]; then
            echo "✅ Domain DNS is correctly configured"
        else
            echo "❌ Domain DNS points to wrong IP address"
            echo "   Expected: $PUBLIC_IP"
            echo "   Current:  $DOMAIN_IP"
        fi
    else
        echo "❌ Domain DNS resolution failed"
    fi
    
    # Test HTTP access from internet
    echo ""
    echo "🌐 Testing Internet Access:"
    if curl -I -s --connect-timeout 10 http://$DOMAIN 2>/dev/null | grep -q "HTTP"; then
        echo "✅ Domain is accessible via HTTP"
    else
        echo "❌ Domain is not accessible via HTTP"
        echo "📋 Common causes:"
        echo "   - DNS not propagated yet"
        echo "   - Firewall blocking port 80"
        echo "   - Nginx not running"
    fi
fi

# Show next steps
echo ""
echo "🎯 Next Steps:"
echo ""

if [ ! -f "$SSL_CERT_PATH" ]; then
    echo "🔐 To set up SSL certificates:"
    echo "   1. Ensure domain DNS points to this server"
    echo "   2. Ensure nginx is running: sudo systemctl start nginx"
    echo "   3. Run: sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --email YOUR_EMAIL --agree-tos --no-eff-email --redirect"
    echo ""
fi

echo "🔧 Common commands:"
echo "   - Check logs: pm2 logs webxr-mesh-exporter"
echo "   - Restart app: pm2 restart webxr-mesh-exporter"
echo "   - Check nginx: sudo systemctl status nginx"
echo "   - Fix nginx: ./scripts/fix-nginx-config.sh"
echo "   - Diagnose: ./scripts/diagnose.sh"
echo ""

if [ "$SERVER_MODE" = true ]; then
    echo "🌐 Your application should be accessible at:"
    echo "   - HTTP:  http://$DOMAIN"
    echo "   - Local: http://localhost"
    echo "   - IP:    http://$PUBLIC_IP"
    
    if [ -f "$SSL_CERT_PATH" ]; then
        echo "   - HTTPS: https://$DOMAIN"
    fi
fi
