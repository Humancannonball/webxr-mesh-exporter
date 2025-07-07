#!/bin/bash

# DNS Configuration Script for WebXR Mesh Exporter
# Run this script AFTER the basic setup is working to add custom domain support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1"
}

# Check if domain is provided
if [ -z "$1" ]; then
    print_header "WebXR Mesh Exporter - DNS Setup"
    print_error "Please provide your domain name"
    echo ""
    echo "Usage: ./setup-dns.sh yourdomain.com [--skip-dns-check]"
    echo ""
    echo "📋 Before running this script:"
    echo "1. Make sure your domain's A record points to this server's IP"
    echo "2. Wait for DNS propagation (up to 24 hours)"
    echo "3. Test that 'ping yourdomain.com' resolves to this server"
    echo ""
    echo "🌐 Current server IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'Unable to detect')"
    echo ""
    echo "Options:"
    echo "  --skip-dns-check    Skip DNS validation (use with caution)"
    exit 1
fi

DOMAIN_NAME=$1
SKIP_DNS_CHECK=false

# Check for optional parameters
if [ "$2" = "--skip-dns-check" ]; then
    SKIP_DNS_CHECK=true
    print_warning "DNS check will be skipped"
fi

APP_DIR="/opt/bitnami/projects/webxr-mesh-exporter"

print_header "WebXR Mesh Exporter - DNS Setup"
echo "🌐 Setting up DNS for WebXR Mesh Exporter..."
echo "🏷️  Domain: $DOMAIN_NAME"
if [ "$SKIP_DNS_CHECK" = true ]; then
    echo "⚠️  DNS check: SKIPPED"
fi
echo ""

# Check if we're in the right directory
if [ ! -d "$APP_DIR" ]; then
    print_error "Application directory not found: $APP_DIR"
    echo "Please run the basic setup script first:"
    echo "  ./scripts/lightsail-setup.sh"
    exit 1
fi

cd $APP_DIR

# Validate domain format
print_step "Validating domain format..."
if ! echo "$DOMAIN_NAME" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'; then
    print_error "Invalid domain format: $DOMAIN_NAME"
    echo "Domain should be in format: example.com or subdomain.example.com"
    exit 1
fi
print_status "Domain format is valid"

# Check if application is running
print_step "Checking if WebXR application is running..."
if ! pm2 list | grep -q "webxr-mesh-exporter"; then
    print_error "WebXR application is not running in PM2"
    echo "Please start the application first:"
    echo "  pm2 start config/ecosystem.config.js"
    exit 1
fi

# Check jq availability for PM2 status parsing
if command -v jq >/dev/null 2>&1; then
    APP_STATUS=$(pm2 jlist | jq -r '.[] | select(.name=="webxr-mesh-exporter") | .pm2_env.status' 2>/dev/null || echo "unknown")
else
    print_warning "jq not available, using basic PM2 status check"
    if pm2 list | grep "webxr-mesh-exporter" | grep -q "online"; then
        APP_STATUS="online"
    else
        APP_STATUS="unknown"
    fi
fi

if [ "$APP_STATUS" != "online" ]; then
    print_error "WebXR application is not online (status: $APP_STATUS)"
    echo "Please check PM2 status:"
    echo "  pm2 status"
    echo "  pm2 logs webxr-mesh-exporter"
    exit 1
fi
print_status "WebXR application is running"

# Test local application
print_step "Testing local application..."
if curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/health" | grep -q "200"; then
    print_status "Local application responds correctly"
else
    print_error "Local application is not responding"
    echo "Please check application logs:"
    echo "  pm2 logs webxr-mesh-exporter"
    exit 1
fi

# Get server IP
print_step "Getting server information..."
SERVER_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
if [ -z "$SERVER_IP" ]; then
    print_error "Unable to determine server IP"
    exit 1
fi
print_status "Server IP: $SERVER_IP"

# Test if domain resolves
if [ "$SKIP_DNS_CHECK" = false ]; then
    print_step "Testing DNS resolution..."
    if command -v dig >/dev/null 2>&1; then
        DOMAIN_IP=$(dig +short $DOMAIN_NAME | head -1 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || echo "")
    else
        print_warning "dig command not found, installing dnsutils..."
        sudo apt-get update -q && sudo apt-get install -y dnsutils
        DOMAIN_IP=$(dig +short $DOMAIN_NAME | head -1 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || echo "")
    fi

    if [ -z "$DOMAIN_IP" ]; then
        print_error "Domain $DOMAIN_NAME does not resolve to an IP address"
        echo ""
        echo "📋 Common DNS setup instructions:"
        echo "1. Go to your domain registrar's DNS settings"
        echo "2. Create/update A record:"
        echo "   Name: @ (for root domain) or subdomain name"
        echo "   Value: $SERVER_IP"
        echo "   TTL: 300 (5 minutes)"
        echo ""
        echo "3. Wait for DNS propagation (5 minutes to 24 hours)"
        echo "4. Test with: ping $DOMAIN_NAME"
        echo ""
        echo "To skip this check (not recommended): ./setup-dns.sh $DOMAIN_NAME --skip-dns-check"
        exit 1
    fi

    print_status "Domain resolves to: $DOMAIN_IP"

    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        print_warning "Domain $DOMAIN_NAME resolves to $DOMAIN_IP"
        print_warning "But this server IP is $SERVER_IP"
        echo ""
        echo "This could mean:"
        echo "1. DNS is still propagating (can take up to 24 hours)"
        echo "2. Your A record is pointing to the wrong IP"
        echo "3. You're using a CDN or proxy service"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted. Please check your DNS settings and try again."
            echo ""
            echo "💡 To fix DNS:"
            echo "1. Go to your domain registrar's DNS settings"
            echo "2. Create/update A record:"
            echo "   Name: @ (or subdomain like 'webxr')"
            echo "   Value: $SERVER_IP"
            echo "   TTL: 300"
            exit 1
        fi
    else
        print_success "DNS is correctly configured!"
    fi
else
    print_warning "Skipping DNS validation as requested"
    DOMAIN_IP="(skipped)"
fi

# Backup current Apache configuration
print_step "Backing up current Apache configuration..."
BACKUP_FILE="/opt/bitnami/apache/conf/vhosts/webxr-mesh-exporter.conf.backup.$(date +%Y%m%d_%H%M%S)"
sudo cp /opt/bitnami/apache/conf/vhosts/webxr-mesh-exporter.conf "$BACKUP_FILE"
print_status "Backup created: $BACKUP_FILE"

# Create domain-specific Apache configuration
print_step "Creating domain-specific Apache configuration..."
if [ ! -f "apache/webxr-mesh-exporter-domain.conf" ]; then
    print_error "Domain template file not found: apache/webxr-mesh-exporter-domain.conf"
    echo "Please ensure you're running this from the project root directory"
    exit 1
fi

TEMP_CONF="/tmp/webxr-domain-$(date +%s).conf"
cp apache/webxr-mesh-exporter-domain.conf "$TEMP_CONF"
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN_NAME/g" "$TEMP_CONF"

print_status "Generated configuration for domain: $DOMAIN_NAME"

# Show configuration preview
print_step "Configuration preview:"
echo "────────────────────────────────────────"
head -20 "$TEMP_CONF" | sed 's/^/  /'
echo "  ... (truncated) ..."
echo "────────────────────────────────────────"

# Test Apache configuration syntax
print_step "Testing Apache configuration..."
sudo cp "$TEMP_CONF" /opt/bitnami/apache/conf/vhosts/webxr-mesh-exporter.conf

if ! sudo /opt/bitnami/apache/bin/httpd -t 2>/dev/null; then
    print_error "Apache configuration test failed!"
    print_status "Restoring original configuration..."
    sudo cp "$BACKUP_FILE" /opt/bitnami/apache/conf/vhosts/webxr-mesh-exporter.conf
    rm -f "$TEMP_CONF"
    exit 1
fi

print_success "Apache configuration test passed"

# Restart Apache
print_step "Restarting Apache..."
if sudo /opt/bitnami/ctlscript.sh restart apache; then
    print_success "Apache restarted successfully"
else
    print_error "Failed to restart Apache"
    print_status "Restoring original configuration..."
    sudo cp "$BACKUP_FILE" /opt/bitnami/apache/conf/vhosts/webxr-mesh-exporter.conf
    sudo /opt/bitnami/ctlscript.sh restart apache
    rm -f "$TEMP_CONF"
    exit 1
fi

# Clean up temporary files
rm -f "$TEMP_CONF"

# Wait for Apache to fully start
print_step "Waiting for Apache to start..."
sleep 5

# Comprehensive testing
print_step "Testing domain access..."
HTTP_STATUS=""
HTTPS_STATUS=""
HEALTH_CHECK=""

# Test HTTP
print_status "Testing HTTP access..."
if HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN_NAME/health" 2>/dev/null) && [ "$HTTP_RESPONSE" = "200" ]; then
    HTTP_STATUS="✅ Working (HTTP 200)"
    print_success "HTTP access successful"
    
    # Get health check response
    HEALTH_RESPONSE=$(curl -s "http://$DOMAIN_NAME/health" 2>/dev/null || echo "Unable to fetch")
    HEALTH_CHECK="✅ Responding: $HEALTH_RESPONSE"
else
    HTTP_STATUS="❌ Failed (HTTP $HTTP_RESPONSE)"
    print_warning "HTTP access failed (Status: $HTTP_RESPONSE)"
    HEALTH_CHECK="❌ Not responding"
fi

# Test HTTPS (might fail if no SSL cert yet)
print_status "Testing HTTPS access..."
if HTTPS_RESPONSE=$(curl -s -k -o /dev/null -w "%{http_code}" "https://$DOMAIN_NAME/health" 2>/dev/null) && [ "$HTTPS_RESPONSE" = "200" ]; then
    HTTPS_STATUS="✅ Working (HTTP 200)"
    print_success "HTTPS access successful"
else
    HTTPS_STATUS="⚠️ No SSL yet (HTTP $HTTPS_RESPONSE)"
    print_status "HTTPS not working yet (SSL certificate needed)"
fi

# Test main page
print_status "Testing main application page..."
if curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN_NAME/" | grep -q "200"; then
    MAIN_PAGE_STATUS="✅ Working"
    print_success "Main page accessible"
else
    MAIN_PAGE_STATUS="❌ Failed"
    print_warning "Main page not accessible"
fi

# Final status report
echo ""
print_header "🎉 DNS Setup Completed!"
echo ""
echo "📊 Status Report:"
echo "   Domain:           $DOMAIN_NAME"
echo "   DNS Resolution:   $DOMAIN_IP"
echo "   Server IP:        $SERVER_IP"
echo "   HTTP Access:      $HTTP_STATUS"
echo "   HTTPS Access:     $HTTPS_STATUS"
echo "   Health Check:     $HEALTH_CHECK"
echo "   Main Page:        $MAIN_PAGE_STATUS"
echo ""

if [[ $HTTP_STATUS == *"Working"* ]]; then
    print_success "🌐 Your application is now accessible at:"
    echo "   Main App:  http://$DOMAIN_NAME"
    echo "   Health:    http://$DOMAIN_NAME/health"
    echo ""
    
    if [[ $HTTPS_STATUS != *"Working"* ]]; then
        print_step "🔒 Next Steps - SSL Certificate Setup:"
        echo ""
        echo "Run the Bitnami SSL tool to set up automatic HTTPS:"
        echo "   sudo /opt/bitnami/bncert-tool"
        echo ""
        echo "When prompted:"
        echo "   1. Enter your domain: $DOMAIN_NAME"
        echo "   2. Enter your email for Let's Encrypt notifications"
        echo "   3. Agree to redirect HTTP to HTTPS: Y"
        echo "   4. Agree to update /opt/bitnami/apache/conf/vhosts/letsencrypt.conf: Y"
        echo ""
        echo "This will:"
        echo "   ✓ Install Let's Encrypt SSL certificate"
        echo "   ✓ Automatically redirect HTTP to HTTPS"
        echo "   ✓ Set up automatic certificate renewal"
        echo ""
    else
        print_success "🔒 SSL is already working!"
    fi
    
    echo "📱 WebXR Features:"
    echo "   ✓ The app should now work with WebXR on mobile devices"
    echo "   ✓ Domain access enables camera/AR permissions"
    echo "   ✓ HTTPS (when configured) provides secure context"
    echo ""
    
else
    print_error "❌ Domain setup needs attention"
    echo ""
    echo "🔍 Troubleshooting steps:"
    echo ""
    echo "1. Verify DNS propagation:"
    echo "   ping $DOMAIN_NAME"
    echo "   nslookup $DOMAIN_NAME"
    echo "   dig $DOMAIN_NAME"
    echo ""
    echo "2. Check firewall settings in AWS Lightsail:"
    echo "   - Port 80 (HTTP) should be open"
    echo "   - Port 443 (HTTPS) should be open"
    echo "   - Port 3000 should NOT be open (app runs behind Apache)"
    echo ""
    echo "3. Check Apache logs:"
    echo "   sudo tail -f /opt/bitnami/apache/logs/error_log"
    echo "   sudo tail -f /opt/bitnami/apache/logs/access_log"
    echo ""
    echo "4. Test application directly:"
    echo "   curl http://localhost:3000/health"
    echo ""
    echo "5. Check Apache configuration:"
    echo "   sudo /opt/bitnami/apache/bin/httpd -t"
    echo "   sudo /opt/bitnami/ctlscript.sh status"
    echo ""
    echo "6. Restore backup if needed:"
    echo "   sudo cp $BACKUP_FILE /opt/bitnami/apache/conf/vhosts/webxr-mesh-exporter.conf"
    echo "   sudo /opt/bitnami/ctlscript.sh restart apache"
    echo ""
    echo "7. Check PM2 application:"
    echo "   pm2 status"
    echo "   pm2 logs webxr-mesh-exporter"
fi

echo ""
print_header "💡 Useful Commands:"
echo "Test domain:         curl http://$DOMAIN_NAME/health"
echo "Test HTTPS:          curl https://$DOMAIN_NAME/health"
echo "Check Apache:        sudo /opt/bitnami/ctlscript.sh status apache"
echo "View Apache errors:  sudo tail -f /opt/bitnami/apache/logs/error_log"
echo "View Apache access:  sudo tail -f /opt/bitnami/apache/logs/access_log"
echo "Check PM2:           pm2 status"
echo "App logs:            pm2 logs webxr-mesh-exporter"
echo "Setup SSL:           sudo /opt/bitnami/bncert-tool"
echo ""
echo "📁 Configuration Files:"
echo "Apache config:       /opt/bitnami/apache/conf/vhosts/webxr-mesh-exporter.conf"
echo "Backup config:       $BACKUP_FILE"
echo "PM2 config:          $APP_DIR/config/ecosystem.config.js"
echo ""

if [[ $HTTP_STATUS == *"Working"* ]]; then
    print_success "🚀 Setup completed successfully! Your WebXR Mesh Exporter is now live!"
else
    print_warning "⚠️  Setup completed with issues. Please check troubleshooting steps above."
fi
