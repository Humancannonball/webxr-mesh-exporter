# WebXR Mesh Exporter - Ubuntu 24.04 Deployment Guide

## Quick Start

### 1. Launch Ubuntu 24.04 LTS on AWS Lightsail
- Choose **Ubuntu 24.04 LTS** 
- Minimum: 1GB RAM, 1 vCPU
- Recommended: 2GB RAM, 1 vCPU

### 2. Initial Setup (Run Once)
```bash
# Clone the repository
git clone https://github.com/Humancannonball/webxr-mesh-exporter.git
cd webxr-mesh-exporter

# Run the setup script
sudo bash scripts/ubuntu-setup.sh
```

### 3. DNS Configuration
Point your domain to the server IP:
- **A Record**: `industreo.works` → `YOUR_SERVER_IP`
- **CNAME Record**: `www.industreo.works` → `industreo.works`

### 4. Update Application
```bash
# Run update script
bash ~/update-webxr.sh
```

## Architecture

```
Internet → Nginx (80/443) → Node.js (3000) → WebXR App
```

### Components
- **Nginx**: Reverse proxy, SSL termination, static files
- **Node.js 20.x LTS**: Application server (port 3000)
- **PM2**: Process manager for Node.js
- **Certbot (via snap)**: Let's Encrypt SSL certificates
- **UFW**: Enhanced firewall configuration
- **Fail2ban**: Intrusion prevention with custom nginx rules

### Nginx Configuration Structure

The Nginx setup uses a layered configuration approach:

1. **Main Config** (`/etc/nginx/nginx.conf`):
   - Global HTTP settings
   - Rate limiting zones (`limit_req_zone`)
   - WebSocket upgrade mapping (`map $http_upgrade $connection_upgrade`)
   - Include directive for site configs

2. **Site Config** (`/etc/nginx/sites-available/webxr-mesh-exporter`):
   - SSL configuration and certificates
   - HTTP to HTTPS redirects
   - Reverse proxy to Node.js (port 3000)
   - Security headers and rate limiting rules
   - WebSocket support for real-time features

3. **Key Features**:
   - **SSL/TLS**: Let's Encrypt certificates with auto-renewal
   - **Rate Limiting**: API endpoints (30 req/min), WebSocket (60 req/min)
   - **Security Headers**: HSTS, CSP, X-Frame-Options, etc.
   - **WebSocket Support**: For real-time mesh streaming
   - **Compression**: Gzip for static assets
   - **Caching**: Static file caching with proper headers

## Features

### ✅ **Web Application**
- 🏠 **Landing Page**: `https://industreo.works/`
- 🥽 **WebXR Interface**: `https://industreo.works/mr/`
- 📱 **Mobile Optimized**: Responsive design for all devices

### ✅ **Security**
- 🔐 **SSL/TLS**: Automatic HTTPS with Let's Encrypt
- 🛡️ **Security Headers**: XSS protection, CSRF protection
- 🔒 **Firewall**: UFW configured for web traffic only
- 🚫 **Fail2ban**: Automatic IP blocking for failed attempts

### ✅ **Performance**
- ⚡ **Gzip Compression**: Faster loading times
- 📦 **Static File Caching**: Optimized asset delivery
- 🔄 **Rate Limiting**: API and WebSocket protection

### ✅ **Monitoring**
- 📊 **PM2 Dashboard**: Process monitoring
- 📝 **Structured Logs**: Application and Nginx logs
- 🏥 **Health Checks**: `/health` endpoint

## Management Commands

### Application Management
```bash
# View application status
pm2 status

# View application logs
pm2 logs webxr-mesh-exporter

# Restart application
pm2 restart webxr-mesh-exporter

# Update application
bash ~/update-webxr.sh
```

### Nginx Management
```bash
# Check Nginx status
sudo systemctl status nginx

# View Nginx logs
sudo tail -f /var/log/nginx/webxr_access.log
sudo tail -f /var/log/nginx/webxr_error.log

# Reload Nginx configuration
sudo systemctl reload nginx

# Test Nginx configuration
sudo nginx -t
```

### SSL Certificate Management
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates (manual)
sudo certbot renew

# Test renewal process
sudo certbot renew --dry-run

# Check automatic renewal timer (Ubuntu 24.04)
sudo systemctl status snap.certbot.renew.timer
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Nginx Configuration Errors

**Error**: `nginx: [emerg] "map" directive is not allowed here`
**Solution**: The `map` directive must be in the `http` block, not in `server` block.

```bash
# Fix automatically
./scripts/fix-nginx-config.sh

# Or manually check/fix
sudo nginx -t
sudo nano /etc/nginx/nginx.conf
```

**Error**: `nginx: [emerg] "limit_req_zone" directive is not allowed here`
**Solution**: Rate limiting zones must be in the `http` block.

```bash
# Check current config
sudo nginx -t

# View current nginx.conf structure
sudo grep -n "http {" /etc/nginx/nginx.conf
sudo grep -n "limit_req_zone" /etc/nginx/nginx.conf
```

#### 2. SSL Certificate Issues

**Error**: Certificate not found or expired
**Solution**: 
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run
```

#### 3. Application Not Starting

**Error**: PM2 app not running
**Solution**:
```bash
# Check PM2 status
pm2 status

# View logs
pm2 logs webxr-mesh-exporter

# Restart application
pm2 restart webxr-mesh-exporter
```

#### 4. Port Already in Use

**Error**: `EADDRINUSE: address already in use :::3000`
**Solution**:
```bash
# Find process using port 3000
sudo netstat -tlnp | grep :3000
sudo lsof -i :3000

# Kill process if needed
sudo kill -9 <PID>

# Restart application
pm2 restart webxr-mesh-exporter
```

#### 5. Firewall Issues

**Error**: Cannot access website
**Solution**:
```bash
# Check firewall status
sudo ufw status

# Allow required ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp

# Check if nginx is running
sudo systemctl status nginx
```

#### 6. Recovery Commands

If the deployment fails partially:

```bash
# 1. Fix Nginx configuration
./scripts/fix-nginx-config.sh

# 2. Restart services
sudo systemctl restart nginx
pm2 restart all

# 3. Check logs
sudo journalctl -u nginx -f
pm2 logs

# 4. Re-run deployment
./scripts/ubuntu-setup.sh
```

### Log Locations
- **Application**: `pm2 logs webxr-mesh-exporter`
- **Nginx Access**: `/var/log/nginx/webxr_access.log`
- **Nginx Error**: `/var/log/nginx/webxr_error.log`
- **System**: `sudo journalctl -u nginx`

## Security Notes

### Firewall Rules
```bash
# Check firewall status
sudo ufw status

# Allow specific ports if needed
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
```

### SSL Security
- **TLS 1.2/1.3 only**: Modern encryption
- **HSTS**: HTTP Strict Transport Security
- **Perfect Forward Secrecy**: Enhanced privacy

## Development

### Local Development
```bash
# Run locally
PORT=3000 npm start

# Access at http://localhost:3000
```

### Production Environment Variables
- `NODE_ENV=production`
- `PORT=3000`

## WebXR Requirements

### Browser Support
- **Chrome/Edge**: WebXR support
- **Firefox**: WebXR support
- **Mobile**: WebXR Viewer app

### Device Support
- **Meta Quest 2/3**: Native WebXR
- **iOS/Android**: WebXR Viewer
- **Desktop**: WebXR emulator

### HTTPS Requirement
WebXR **requires HTTPS** in production. The setup script automatically configures SSL certificates.

## Performance Optimization

### Nginx Configuration
- **Gzip compression**: Reduces bandwidth
- **Static file caching**: Faster repeated visits
- **HTTP/2**: Improved performance
- **Rate limiting**: Prevents abuse

### Node.js Optimization
- **PM2 clustering**: Can scale to multiple cores
- **Memory limits**: Automatic restart on memory leaks
- **Process monitoring**: Automatic restart on crashes

## Backup Strategy

### Automated Backups
The update script creates automatic backups in `/tmp/webxr-backup-*`

### Manual Backup
```bash
# Create manual backup
tar -czf webxr-backup-$(date +%Y%m%d).tar.gz \
    --exclude=node_modules \
    --exclude=.git \
    --exclude=data/logs \
    /opt/webxr-mesh-exporter
```

## Support

### Check Status
```bash
# Quick system check
pm2 status
sudo systemctl status nginx
sudo ufw status
curl -I https://industreo.works/health
```

### Update Process
1. **Automatic backup** created
2. **Git pull** latest changes
3. **Dependencies** updated if needed
4. **Nginx config** updated if needed
5. **Application restart**
6. **Health check** performed

This setup provides a production-ready WebXR application with enterprise-grade security, performance, and monitoring! 🚀
