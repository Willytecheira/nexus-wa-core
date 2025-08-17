# WhatsApp Multi-Session API - Deployment Guide

This guide provides comprehensive instructions for deploying the WhatsApp Multi-Session API in production environments.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Deployment](#quick-deployment)
3. [Manual Deployment](#manual-deployment)
4. [Configuration](#configuration)
5. [SSL/TLS Setup](#ssltls-setup)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Updates & Rollbacks](#updates--rollbacks)
8. [Troubleshooting](#troubleshooting)
9. [Performance Optimization](#performance-optimization)
10. [Security Hardening](#security-hardening)

## Prerequisites

### System Requirements

**Minimum Requirements:**
- Ubuntu 20.04 LTS or later (recommended)
- 2 CPU cores
- 2GB RAM
- 10GB disk space
- Node.js 18+
- Chrome/Chromium browser

**Recommended for Production:**
- Ubuntu 22.04 LTS
- 4 CPU cores
- 4GB RAM
- 50GB SSD storage
- Node.js 20 LTS
- Dedicated server or VPS

### Network Requirements
- Port 80 (HTTP) - for Let's Encrypt verification
- Port 443 (HTTPS) - for secure API access
- Port 3000 (optional) - direct API access
- Outbound HTTPS access for WhatsApp Web

## Quick Deployment

### One-Command Installation

```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/yourusername/whatsapp-multi-session-api/main/server/install.sh | sudo bash
```

This script will:
- Install all dependencies (Node.js, Chrome, PM2, Nginx)
- Clone the repository
- Configure the application
- Set up SSL certificates
- Start all services

### Quick Start Commands

```bash
# Check system status
sudo ./server/health-check.sh

# View application logs
sudo pm2 logs whatsapp-api

# Restart application
sudo pm2 restart whatsapp-api

# Update application
sudo ./server/update.sh
```

## Manual Deployment

### Step 1: System Preparation

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install Chrome
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo apt install -y google-chrome-stable

# Install PM2 globally
sudo npm install -g pm2

# Install Nginx
sudo apt install -y nginx

# Install SQLite
sudo apt install -y sqlite3
```

### Step 2: Application Setup

```bash
# Create application directory
sudo mkdir -p /var/www/whatsapp-api
cd /var/www/whatsapp-api

# Clone repository
sudo git clone https://github.com/yourusername/whatsapp-multi-session-api.git .

# Set proper ownership
sudo chown -R $USER:$USER /var/www/whatsapp-api

# Install server dependencies
cd server
npm ci --production

# Install frontend dependencies and build
cd ..
npm ci
npm run build

# Create necessary directories
sudo mkdir -p /var/log/whatsapp-api
sudo mkdir -p /var/backups/whatsapp-api
sudo chown -R www-data:www-data /var/www/whatsapp-api
```

### Step 3: Configuration

```bash
# Copy environment configuration
cd /var/www/whatsapp-api/server
sudo cp .env.example .env

# Edit configuration
sudo nano .env
```

**Required Environment Variables:**
```env
NODE_ENV=production
PORT=3000
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
FRONTEND_URL=https://your-domain.com
LOG_LEVEL=info
WHATSAPP_SESSION_TIMEOUT=300000
WHATSAPP_MAX_SESSIONS=50
```

### Step 4: Database Setup

```bash
# Run database migrations
cd /var/www/whatsapp-api/server
node migrations/migrate.js

# Verify database creation
sqlite3 database/whatsapp_api.db ".tables"
```

### Step 5: PM2 Configuration

```bash
# Start application with PM2
cd /var/www/whatsapp-api/server
sudo pm2 start ecosystem.config.js

# Save PM2 configuration
sudo pm2 save

# Set up PM2 startup script
sudo pm2 startup

# Verify application is running
sudo pm2 status
```

### Step 6: Nginx Configuration

```bash
# Create Nginx configuration
sudo nano /etc/nginx/sites-available/whatsapp-api
```

**Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;
    
    # SSL Configuration (will be added by Certbot)
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Frontend (React app)
    location / {
        root /var/www/whatsapp-api/dist;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # API routes
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Increase timeout for WhatsApp operations
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Socket.IO
    location /socket.io/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:3000;
        access_log off;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/whatsapp-api /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

## SSL/TLS Setup

### Using Let's Encrypt (Recommended)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Set up automatic renewal
sudo crontab -e
# Add this line:
# 0 12 * * * /usr/bin/certbot renew --quiet
```

### Using Custom SSL Certificate

```bash
# Copy your certificates
sudo cp your-domain.crt /etc/ssl/certs/whatsapp-api.crt
sudo cp your-domain.key /etc/ssl/private/whatsapp-api.key

# Set proper permissions
sudo chmod 644 /etc/ssl/certs/whatsapp-api.crt
sudo chmod 600 /etc/ssl/private/whatsapp-api.key

# Update Nginx configuration
sudo nano /etc/nginx/sites-available/whatsapp-api
```

Add to server block:
```nginx
ssl_certificate /etc/ssl/certs/whatsapp-api.crt;
ssl_certificate_key /etc/ssl/private/whatsapp-api.key;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
```

## Monitoring & Maintenance

### Setting up Monitoring

```bash
# Set up automated health checks
sudo crontab -e
# Add these lines:
# 0 */6 * * * /var/www/whatsapp-api/server/health-check.sh silent
# 0 2 * * 0 /var/www/whatsapp-api/server/maintenance.sh auto

# Install monitoring tools
sudo apt install -y htop iotop nethogs

# Set up log rotation
sudo nano /etc/logrotate.d/whatsapp-api
```

**Log Rotation Configuration:**
```
/var/www/whatsapp-api/server/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        sudo pm2 reload whatsapp-api
    endscript
}
```

### Health Monitoring Commands

```bash
# Full system health check
sudo ./server/health-check.sh full

# Application status
sudo pm2 status
sudo pm2 monit

# System resources
htop
df -h
free -h

# Application logs
sudo tail -f /var/www/whatsapp-api/server/logs/combined.log
sudo pm2 logs whatsapp-api
```

## Updates & Rollbacks

### Updating the Application

```bash
# Automatic update
sudo ./server/update.sh

# Manual update
sudo ./server/update.sh manual

# Check for updates only
sudo ./server/update.sh check
```

### Rolling Back

```bash
# Quick rollback to last backup
sudo ./server/rollback.sh quick

# Interactive rollback
sudo ./server/rollback.sh

# List available backups
sudo ./server/rollback.sh list
```

### Scheduled Updates

```bash
# Set up automatic update checks
sudo crontab -e
# Add this line for weekly update checks:
# 0 3 * * 1 /var/www/whatsapp-api/server/update.sh scheduled
```

## Performance Optimization

### System Optimization

```bash
# Increase file limits
sudo nano /etc/security/limits.conf
```

Add:
```
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
```

```bash
# Optimize kernel parameters
sudo nano /etc/sysctl.conf
```

Add:
```
# Network optimizations
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 20

# Memory optimizations
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
```

Apply changes:
```bash
sudo sysctl -p
```

### Application Optimization

```bash
# Optimize PM2 configuration
sudo nano /var/www/whatsapp-api/server/ecosystem.config.js
```

Adjust based on your server:
```javascript
instances: 'max', // Use all CPU cores
max_memory_restart: '1G', // Restart if memory usage exceeds 1GB
```

### Database Optimization

```bash
# Regular database maintenance
sudo ./server/maintenance.sh database

# Optimize database
sqlite3 /var/www/whatsapp-api/server/database/whatsapp_api.db "VACUUM; ANALYZE;"
```

## Security Hardening

### Firewall Configuration

```bash
# Install UFW
sudo apt install -y ufw

# Configure firewall rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### Fail2Ban Setup

```bash
# Install Fail2Ban
sudo apt install -y fail2ban

# Configure for Nginx
sudo nano /etc/fail2ban/jail.local
```

Add:
```ini
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2
```

### Additional Security Measures

```bash
# Disable unused services
sudo systemctl disable apache2 2>/dev/null || true
sudo systemctl stop apache2 2>/dev/null || true

# Set up automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Secure shared memory
sudo nano /etc/fstab
# Add: tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0

# Set proper file permissions
sudo find /var/www/whatsapp-api -type f -exec chmod 644 {} \;
sudo find /var/www/whatsapp-api -type d -exec chmod 755 {} \;
sudo chmod +x /var/www/whatsapp-api/server/*.sh
```

## Troubleshooting

### Common Issues

**Issue: Application won't start**
```bash
# Check logs
sudo pm2 logs whatsapp-api
sudo tail -f /var/www/whatsapp-api/server/logs/error.log

# Check dependencies
cd /var/www/whatsapp-api/server
npm audit
```

**Issue: WhatsApp sessions fail to connect**
```bash
# Check Chrome process
ps aux | grep chrome

# Test Chrome installation
google-chrome --version

# Check session directory permissions
ls -la /var/www/whatsapp-api/server/sessions/
```

**Issue: High memory usage**
```bash
# Monitor memory usage
sudo ./server/health-check.sh system

# Restart application
sudo pm2 restart whatsapp-api

# Check for memory leaks
sudo pm2 monit
```

### Log Analysis

```bash
# Application logs
sudo tail -f /var/www/whatsapp-api/server/logs/combined.log

# Error logs
sudo tail -f /var/www/whatsapp-api/server/logs/error.log

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# System logs
sudo journalctl -u nginx -f
sudo journalctl -f
```

### Performance Monitoring

```bash
# Real-time system monitoring
htop
iotop
nethogs

# Application metrics
curl http://localhost:3000/api/metrics

# Health check
curl http://localhost:3000/health
```

## Support

### Getting Help

1. **Documentation**: Check the main [README.md](README.md) for basic setup
2. **Logs**: Always check application and system logs first
3. **Health Check**: Run the health check script for diagnostics
4. **GitHub Issues**: Report bugs and request features
5. **Community**: Join our community discussions

### Useful Commands

```bash
# Quick status check
sudo ./server/health-check.sh quick

# View all logs
sudo journalctl -xe

# Restart all services
sudo systemctl restart nginx
sudo pm2 restart whatsapp-api

# Check system resources
df -h && free -h && uptime

# Database backup
sudo cp /var/www/whatsapp-api/server/database/whatsapp_api.db /var/backups/whatsapp-api/manual_backup_$(date +%Y%m%d_%H%M%S).db
```

---

## Conclusion

This deployment guide provides comprehensive instructions for setting up a production-ready WhatsApp Multi-Session API. Follow the security hardening and optimization sections for the best performance and security.

For additional support, please refer to the troubleshooting section or create an issue in the GitHub repository.