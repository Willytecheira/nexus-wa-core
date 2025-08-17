#!/bin/bash

# WhatsApp Multi-Session API - Ubuntu Installation Script
# Supports Ubuntu 18.04, 20.04, 22.04

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NODE_VERSION="18"
PROJECT_DIR="/var/www/whatsapp-api"
SERVICE_USER="whatsapp"

echo -e "${BLUE}🚀 WhatsApp Multi-Session API Installation Script${NC}"
echo -e "${BLUE}=================================================${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root${NC}"
   echo "Usage: sudo bash install.sh"
   exit 1
fi

echo -e "${YELLOW}📋 System Information:${NC}"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Architecture: $(uname -m)"
echo "Kernel: $(uname -r)"
echo ""

# Update system packages
echo -e "${BLUE}📦 Updating system packages...${NC}"
apt update && apt upgrade -y

# Install essential packages
echo -e "${BLUE}🔧 Installing essential packages...${NC}"
apt install -y curl wget git unzip software-properties-common build-essential

# Install Node.js
echo -e "${BLUE}📱 Installing Node.js ${NODE_VERSION}...${NC}"
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt install -y nodejs

# Verify Node.js installation
NODE_VER=$(node --version)
NPM_VER=$(npm --version)
echo -e "${GREEN}✅ Node.js ${NODE_VER} installed${NC}"
echo -e "${GREEN}✅ NPM ${NPM_VER} installed${NC}"

# Install PM2 globally
echo -e "${BLUE}⚡ Installing PM2 process manager...${NC}"
npm install -g pm2
pm2 startup systemd -u root --hp /root

# Install Google Chrome dependencies for Puppeteer
echo -e "${BLUE}🌐 Installing Chrome dependencies...${NC}"
apt install -y \
    gconf-service \
    libasound2 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgcc1 \
    libgconf-2-4 \
    libgdk-pixbuf2.0-0 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    ca-certificates \
    fonts-liberation \
    libappindicator1 \
    libnss3 \
    lsb-release \
    xdg-utils

# Install Google Chrome
echo -e "${BLUE}🔍 Installing Google Chrome...${NC}"
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt update
apt install -y google-chrome-stable

# Install Nginx
echo -e "${BLUE}🌐 Installing Nginx...${NC}"
apt install -y nginx

# Install UFW (Uncomplicated Firewall)
echo -e "${BLUE}🔒 Configuring firewall...${NC}"
apt install -y ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Create service user
echo -e "${BLUE}👤 Creating service user...${NC}"
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd --system --home $PROJECT_DIR --shell /bin/bash $SERVICE_USER
    echo -e "${GREEN}✅ User $SERVICE_USER created${NC}"
else
    echo -e "${YELLOW}⚠️  User $SERVICE_USER already exists${NC}"
fi

# Create project directory
echo -e "${BLUE}📁 Creating project directory...${NC}"
mkdir -p $PROJECT_DIR
mkdir -p $PROJECT_DIR/server
mkdir -p $PROJECT_DIR/server/logs
mkdir -p $PROJECT_DIR/server/uploads
mkdir -p $PROJECT_DIR/server/qr
mkdir -p $PROJECT_DIR/server/sessions
mkdir -p $PROJECT_DIR/server/database
mkdir -p $PROJECT_DIR/dist

# Set proper permissions
chown -R $SERVICE_USER:$SERVICE_USER $PROJECT_DIR
chmod -R 755 $PROJECT_DIR

# Configure system limits for WhatsApp sessions
echo -e "${BLUE}⚙️  Configuring system limits...${NC}"
cat >> /etc/security/limits.conf << EOF

# WhatsApp API limits
$SERVICE_USER soft nofile 65536
$SERVICE_USER hard nofile 65536
$SERVICE_USER soft nproc 32768
$SERVICE_USER hard nproc 32768
EOF

# Configure systemd limits
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/whatsapp-limits.conf << EOF
[Manager]
DefaultLimitNOFILE=65536
DefaultLimitNPROC=32768
EOF

# Reload systemd
systemctl daemon-reload

# Configure Nginx
echo -e "${BLUE}🌐 Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/whatsapp-api << 'EOF'
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

    # Frontend (React app)
    location / {
        root /var/www/whatsapp-api/dist;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # API routes
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # Authentication endpoint with stricter limits
    location /api/auth/login {
        limit_req zone=login burst=5 nodelay;
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket support for Socket.IO
    location /socket.io/ {
        proxy_pass http://127.0.0.1:3000;
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
        proxy_pass http://127.0.0.1:3000;
        access_log off;
    }

    # File uploads and QR codes
    location /uploads/ {
        alias /var/www/whatsapp-api/server/uploads/;
        expires 1d;
    }

    location /qr/ {
        alias /var/www/whatsapp-api/server/qr/;
        expires 5m;
    }

    # Deny access to sensitive files
    location ~ /\. {
        deny all;
    }

    location ~ \.(env|log|json)$ {
        deny all;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/whatsapp-api /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# Start and enable services
echo -e "${BLUE}🚀 Starting services...${NC}"
systemctl start nginx
systemctl enable nginx

# Create logrotate configuration
echo -e "${BLUE}📋 Configuring log rotation...${NC}"
cat > /etc/logrotate.d/whatsapp-api << EOF
$PROJECT_DIR/server/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
    postrotate
        pm2 reloadLogs
    endscript
}
EOF

# Create backup script
echo -e "${BLUE}💾 Creating backup script...${NC}"
cat > /usr/local/bin/whatsapp-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/whatsapp-api"
DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/var/www/whatsapp-api"

mkdir -p $BACKUP_DIR

# Backup database
tar -czf $BACKUP_DIR/database_$DATE.tar.gz -C $PROJECT_DIR/server database/

# Backup configuration
tar -czf $BACKUP_DIR/config_$DATE.tar.gz -C $PROJECT_DIR/server .env ecosystem.config.js

# Remove backups older than 30 days
find $BACKUP_DIR -type f -mtime +30 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /usr/local/bin/whatsapp-backup.sh

# Setup daily backup cron job
echo -e "${BLUE}⏰ Setting up daily backups...${NC}"
echo "0 2 * * * /usr/local/bin/whatsapp-backup.sh >> /var/log/whatsapp-backup.log 2>&1" | crontab -u root -

# Create deployment script
cat > $PROJECT_DIR/deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Deploying WhatsApp Multi-Session API..."

# Navigate to project directory
cd /var/www/whatsapp-api

# Pull latest changes
git pull origin main

# Install/update backend dependencies
cd server
npm install --production

# Build frontend
cd ..
npm install
npm run build

# Restart services
pm2 restart ecosystem.config.js
pm2 save

echo "✅ Deployment completed successfully!"
EOF

chmod +x $PROJECT_DIR/deploy.sh
chown $SERVICE_USER:$SERVICE_USER $PROJECT_DIR/deploy.sh

# Install fail2ban for additional security
echo -e "${BLUE}🔒 Installing fail2ban...${NC}"
apt install -y fail2ban

cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[nginx-http-auth]
enabled = true

[nginx-noscript]
enabled = true

[nginx-badbots]
enabled = true

[nginx-noproxy]
enabled = true
EOF

systemctl restart fail2ban

# Final system optimizations
echo -e "${BLUE}⚡ Applying system optimizations...${NC}"

# Increase file descriptor limits
echo "fs.file-max = 65536" >> /etc/sysctl.conf

# Network optimizations
cat >> /etc/sysctl.conf << EOF
net.core.somaxconn = 1024
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 1024
EOF

sysctl -p

echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Copy your project files to: $PROJECT_DIR"
echo "2. Configure environment variables in: $PROJECT_DIR/server/.env"
echo "3. Start the application with: pm2 start $PROJECT_DIR/server/ecosystem.config.js"
echo "4. Configure SSL certificate (recommended)"
echo ""
echo -e "${BLUE}📖 Useful Commands:${NC}"
echo "• View logs: pm2 logs"
echo "• Restart app: pm2 restart whatsapp-api"
echo "• Monitor: pm2 monit"
echo "• Backup: /usr/local/bin/whatsapp-backup.sh"
echo "• Deploy: $PROJECT_DIR/deploy.sh"
echo ""
echo -e "${BLUE}🔧 Default Credentials:${NC}"
echo "Username: admin"
echo "Password: admin123"
echo ""
echo -e "${YELLOW}⚠️  Security Reminder:${NC}"
echo "• Change default passwords immediately"
echo "• Configure SSL/TLS certificate"
echo "• Update JWT_SECRET in .env file"
echo "• Review firewall settings"
echo ""
echo -e "${GREEN}🌐 Your API will be available at: http://your-server-ip${NC}"