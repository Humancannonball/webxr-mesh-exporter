#!/bin/bash
# WebXR Mesh Exporter Diagnostic Script
# This script helps diagnose common deployment issues

set -e

echo "🔍 WebXR Mesh Exporter System Diagnostic"
echo "========================================"
echo ""

# Check system info
echo "📊 System Information:"
echo "- OS: $(lsb_release -d -s 2>/dev/null || echo 'Unknown')"
echo "- Kernel: $(uname -r)"
echo "- Architecture: $(uname -m)"
echo "- Uptime: $(uptime -p 2>/dev/null || uptime)"
echo ""

# Check services
echo "🔧 Service Status:"
services=("nginx" "fail2ban" "ufw")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "✅ $service: Running"
    else
        echo "❌ $service: Not running"
    fi
done
echo ""

# Check PM2
echo "📱 PM2 Status:"
if command -v pm2 &> /dev/null; then
    pm2 status 2>/dev/null || echo "❌ PM2 not running or no processes"
else
    echo "❌ PM2 not installed"
fi
echo ""

# Check ports
echo "🔌 Port Status:"
ports=(80 443 3000 22)
for port in "${ports[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        process=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
        echo "✅ Port $port: In use by $process"
    else
        echo "❌ Port $port: Not in use"
    fi
done
echo ""

# Check Nginx configuration
echo "📋 Nginx Configuration:"
if nginx -t 2>/dev/null; then
    echo "✅ Nginx configuration is valid"
else
    echo "❌ Nginx configuration has errors:"
    nginx -t 2>&1 | head -10
fi
echo ""

# Check SSL certificates
echo "🔐 SSL Certificates:"
if command -v certbot &> /dev/null; then
    echo "$(certbot certificates 2>/dev/null | grep -E "(Certificate Name|Expiry Date)" | head -4)"
else
    echo "❌ Certbot not installed"
fi
echo ""

# Check disk space
echo "💾 Disk Usage:"
df -h / | tail -1 | awk '{print "- Root: " $3 "/" $2 " (" $5 " used)"}'
df -h /tmp 2>/dev/null | tail -1 | awk '{print "- Tmp: " $3 "/" $2 " (" $5 " used)"}'
echo ""

# Check memory
echo "🧠 Memory Usage:"
free -h | awk 'NR==2{print "- Memory: " $3 "/" $2 " (" ($3/$2)*100 "% used)"}'
echo ""

# Check logs for errors
echo "📄 Recent Errors:"
echo "Nginx errors (last 5):"
sudo tail -5 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error log found"
echo ""

echo "System journal errors (last 3):"
sudo journalctl -p err -n 3 --no-pager 2>/dev/null || echo "No journal errors found"
echo ""

# Check file permissions
echo "🔒 File Permissions:"
app_dir="/opt/webxr-mesh-exporter"
if [ -d "$app_dir" ]; then
    echo "- App directory: $(ls -ld $app_dir | awk '{print $1 " " $3 ":" $4}')"
    echo "- Data directory: $(ls -ld $app_dir/data 2>/dev/null | awk '{print $1 " " $3 ":" $4}' || echo 'Not found')"
else
    echo "❌ App directory not found at $app_dir"
fi
echo ""

# Check network connectivity
echo "🌐 Network Connectivity:"
if ping -c 1 google.com &> /dev/null; then
    echo "✅ Internet connectivity: OK"
else
    echo "❌ Internet connectivity: Failed"
fi

if curl -s https://acme-v02.api.letsencrypt.org/directory &> /dev/null; then
    echo "✅ Let's Encrypt API: Accessible"
else
    echo "❌ Let's Encrypt API: Not accessible"
fi
echo ""

# Firewall status
echo "🛡️  Firewall Status:"
sudo ufw status | head -10
echo ""

echo "🎉 Diagnostic complete!"
echo ""
echo "💡 Common fixes:"
echo "- Service issues: sudo systemctl restart nginx"
echo "- PM2 issues: pm2 restart all"
echo "- Config issues: ./scripts/fix-nginx-config.sh"
echo "- SSL issues: sudo certbot renew"
echo "- Re-deploy: ./scripts/ubuntu-setup.sh"
