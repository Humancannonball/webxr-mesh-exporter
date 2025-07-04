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

### Common Issues

**1. Application not starting**
```bash
pm2 logs webxr-mesh-exporter
pm2 restart webxr-mesh-exporter
```

**2. SSL certificate issues**
```bash
sudo certbot certificates
sudo certbot renew --force-renewal
```

**3. Nginx configuration errors**
```bash
sudo nginx -t
sudo systemctl status nginx
```

**4. Port conflicts**
```bash
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :80
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
