#!/bin/bash

# WhatsApp Multi-Session API - Complete Installation (No Nginx)
# This script installs everything needed on a fresh Ubuntu server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NODE_VERSION="20"
PROJECT_DIR="/var/www/whatsapp-api"
SERVICE_USER="whatsapp"
DOMAIN=""
REPO_URL="https://github.com/yourusername/your-repo.git"  # UPDATE THIS!

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

print_status "Starting WhatsApp API installation (No Nginx)..."

# Get domain from user
echo -e "${BLUE}Enter your domain name (e.g., api.yourdomain.com) or leave empty for IP access:${NC}"
read -p "Domain: " DOMAIN

# System info
print_status "System Information:"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Domain: ${DOMAIN:-"IP-based access"}"

# Update system
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
print_status "Installing essential packages..."
apt install -y curl wget git software-properties-common build-essential \
    python3 python3-pip ufw fail2ban logrotate cron \
    fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 \
    libgtk-3-0 libnspr4 libnss3 libx11-xcb1 libxcomposite1 libxcursor1 \
    libxdamage1 libxi6 libxrandr2 libxss1 libxtst6 xdg-utils

# Install Node.js and npm
print_status "Installing Node.js ${NODE_VERSION}..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt install -y nodejs

# Verify Node.js installation
node_version=$(node --version)
npm_version=$(npm --version)
print_status "Node.js ${node_version} and npm ${npm_version} installed"

# Install PM2 globally
print_status "Installing PM2..."
npm install -g pm2
pm2 --version

# Install Google Chrome (required for Puppeteer)
print_status "Installing Google Chrome..."
if ! command -v google-chrome &> /dev/null; then
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
    apt update
    apt install -y google-chrome-stable
    
    # Install additional dependencies for Chrome in headless mode
    apt install -y \
        ca-certificates \
        fonts-liberation \
        libappindicator3-1 \
        libasound2 \
        libatk-bridge2.0-0 \
        libdrm2 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libxcomposite1 \
        libxdamage1 \
        libxrandr2 \
        xdg-utils
fi

# Configure UFW Firewall
print_status "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Create service user
print_status "Creating service user..."
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/bash -d /home/$SERVICE_USER -m $SERVICE_USER
    usermod -aG sudo $SERVICE_USER
fi

# Create project directory
print_status "Setting up project directory..."
mkdir -p $PROJECT_DIR
mkdir -p $PROJECT_DIR/server
mkdir -p $PROJECT_DIR/logs
mkdir -p $PROJECT_DIR/uploads
mkdir -p $PROJECT_DIR/qr
mkdir -p $PROJECT_DIR/sessions
mkdir -p $PROJECT_DIR/database
mkdir -p $PROJECT_DIR/backups

# Set permissions
chown -R $SERVICE_USER:$SERVICE_USER $PROJECT_DIR
chmod 755 $PROJECT_DIR

# Configure system limits
print_status "Configuring system limits..."
cat > /etc/security/limits.d/whatsapp.conf << EOF
$SERVICE_USER soft nofile 65536
$SERVICE_USER hard nofile 65536
$SERVICE_USER soft nproc 32768
$SERVICE_USER hard nproc 32768
EOF

# Reload systemd
systemctl daemon-reload

# Clone repository
print_status "Cloning repository..."
cd $PROJECT_DIR
if [ -d ".git" ]; then
    print_status "Repository already exists, pulling latest changes..."
    sudo -u $SERVICE_USER git pull origin main
else
    print_status "Cloning repository from $REPO_URL"
    sudo -u $SERVICE_USER git clone $REPO_URL .
fi

# Install backend dependencies
print_status "Installing backend dependencies..."
cd $PROJECT_DIR/server
sudo -u $SERVICE_USER npm install --production

# Build frontend
print_status "Building frontend..."
cd $PROJECT_DIR
sudo -u $SERVICE_USER npm install
sudo -u $SERVICE_USER npm run build

# Copy dist to server public folder
print_status "Setting up static files..."
mkdir -p $PROJECT_DIR/server/public
cp -r $PROJECT_DIR/dist/* $PROJECT_DIR/server/public/
chown -R $SERVICE_USER:$SERVICE_USER $PROJECT_DIR/server/public

# Setup environment variables
print_status "Setting up environment variables..."
cd $PROJECT_DIR/server
if [ ! -f .env ]; then
    cp .env.example .env
    
    # Generate JWT secret
    JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
    sed -i "s/your-super-secret-jwt-key-change-this-in-production-please/$JWT_SECRET/" .env
    
    # Set frontend URL
    if [ -n "$DOMAIN" ]; then
        sed -i "s|FRONTEND_URL=http://localhost|FRONTEND_URL=https://$DOMAIN|" .env
        sed -i "s|CORS_ORIGINS=.*|CORS_ORIGINS=https://$DOMAIN,https://www.$DOMAIN|" .env
    else
        SERVER_IP=$(curl -s ifconfig.me)
        sed -i "s|FRONTEND_URL=http://localhost|FRONTEND_URL=http://$SERVER_IP|" .env
        sed -i "s|CORS_ORIGINS=.*|CORS_ORIGINS=http://$SERVER_IP|" .env
    fi
    
    # Set production settings
    sed -i "s/NODE_ENV=production/NODE_ENV=production/" .env
    sed -i "s/PORT=3000/PORT=80/" .env
    
    chown $SERVICE_USER:$SERVICE_USER .env
    chmod 600 .env
fi

# Run database migrations
print_status "Running database migrations..."
cd $PROJECT_DIR/server
sudo -u $SERVICE_USER node migrations/migrate.js

# Setup log rotation
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/whatsapp-api << EOF
$PROJECT_DIR/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
    postrotate
        pm2 reload ecosystem.config.js
    endscript
}
EOF

# Setup backup script
print_status "Setting up backup system..."
cat > $PROJECT_DIR/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/www/whatsapp-api/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="whatsapp_backup_$DATE.tar.gz"

# Create backup
cd /var/www/whatsapp-api
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    --exclude="node_modules" \
    --exclude="logs" \
    --exclude="backups" \
    --exclude=".git" \
    .

# Keep only last 30 backups
find "$BACKUP_DIR" -name "whatsapp_backup_*.tar.gz" -type f -mtime +30 -delete

echo "Backup created: $BACKUP_FILE"
EOF

chmod +x $PROJECT_DIR/backup.sh
chown $SERVICE_USER:$SERVICE_USER $PROJECT_DIR/backup.sh

# Add backup to cron
(crontab -u $SERVICE_USER -l 2>/dev/null; echo "0 2 * * * $PROJECT_DIR/backup.sh") | crontab -u $SERVICE_USER -

# Setup fail2ban
print_status "Configuring fail2ban..."
cat > /etc/fail2ban/jail.d/whatsapp-api.conf << EOF
[whatsapp-api]
enabled = true
port = 80,443
filter = whatsapp-api
logpath = $PROJECT_DIR/logs/combined.log
maxretry = 5
bantime = 3600
findtime = 600
action = iptables[name=whatsapp-api, port=http, protocol=tcp]
         iptables[name=whatsapp-api, port=https, protocol=tcp]
EOF

cat > /etc/fail2ban/filter.d/whatsapp-api.conf << EOF
[Definition]
failregex = ^.*"ip":"<HOST>".*"status":(401|403|429).*$
ignoreregex =
EOF

systemctl restart fail2ban

# System optimizations
print_status "Applying system optimizations..."
cat >> /etc/sysctl.conf << EOF
# Network optimizations for WhatsApp API
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3
EOF

sysctl -p

# Start the application with PM2
print_status "Starting the application..."
cd $PROJECT_DIR/server
sudo -u $SERVICE_USER pm2 start ecosystem.config.js --env production
sudo -u $SERVICE_USER pm2 save
pm2 startup systemd -u $SERVICE_USER --hp /home/$SERVICE_USER

# Setup SSL with Let's Encrypt (if domain provided)
if [ -n "$DOMAIN" ]; then
    print_status "Setting up SSL with Let's Encrypt..."
    apt install -y certbot
    
    # Stop the application temporarily
    sudo -u $SERVICE_USER pm2 stop all
    
    # Get SSL certificate
    certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
    
    if [ $? -eq 0 ]; then
        # Update environment to use HTTPS
        sed -i "s/PORT=80/PORT=443/" $PROJECT_DIR/server/.env
        echo "SSL_CERT_PATH=/etc/letsencrypt/live/$DOMAIN/fullchain.pem" >> $PROJECT_DIR/server/.env
        echo "SSL_KEY_PATH=/etc/letsencrypt/live/$DOMAIN/privkey.pem" >> $PROJECT_DIR/server/.env
        
        # Setup auto-renewal
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && pm2 restart all") | crontab -
        
        print_status "SSL certificate installed successfully!"
    else
        print_warning "SSL certificate installation failed. App will run on HTTP."
    fi
    
    # Restart the application
    sudo -u $SERVICE_USER pm2 start all
fi

print_status "Installation completed successfully!"

echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}  WhatsApp Multi-Session API Installation Complete${NC}"
echo -e "${GREEN}================================================${NC}\n"

if [ -n "$DOMAIN" ]; then
    echo -e "${BLUE}🌐 Your API is accessible at:${NC}"
    echo -e "   Dashboard: https://$DOMAIN"
    echo -e "   API: https://$DOMAIN/api"
    echo -e "   WebSocket: wss://$DOMAIN"
else
    SERVER_IP=$(curl -s ifconfig.me)
    echo -e "${BLUE}🌐 Your API is accessible at:${NC}"
    echo -e "   Dashboard: http://$SERVER_IP"
    echo -e "   API: http://$SERVER_IP/api"
    echo -e "   WebSocket: ws://$SERVER_IP"
fi

echo -e "\n${BLUE}👤 Default Admin Credentials:${NC}"
echo -e "   Username: admin"
echo -e "   Password: admin123"
echo -e "   ${RED}⚠️  CHANGE THIS IMMEDIATELY!${NC}"

echo -e "\n${BLUE}📋 Useful Commands:${NC}"
echo -e "   View logs: pm2 logs"
echo -e "   Restart app: pm2 restart all"
echo -e "   Stop app: pm2 stop all"
echo -e "   App status: pm2 status"
echo -e "   System status: systemctl status pm2-$SERVICE_USER"

echo -e "\n${BLUE}📁 Important Paths:${NC}"
echo -e "   Project: $PROJECT_DIR"
echo -e "   Logs: $PROJECT_DIR/logs"
echo -e "   Backups: $PROJECT_DIR/backups"
echo -e "   Environment: $PROJECT_DIR/server/.env"

echo -e "\n${BLUE}🔐 Security Notes:${NC}"
echo -e "   • Change default admin password"
echo -e "   • Configure your domain's DNS to point to this server"
echo -e "   • Monitor logs regularly: tail -f $PROJECT_DIR/logs/combined.log"
echo -e "   • Backups run daily at 2 AM"

if [ -n "$DOMAIN" ]; then
    echo -e "\n${BLUE}🌍 DNS Configuration:${NC}"
    echo -e "   Add these DNS records to your domain:"
    echo -e "   A record: $DOMAIN → $(curl -s ifconfig.me)"
    echo -e "   A record: www.$DOMAIN → $(curl -s ifconfig.me)"
fi

echo -e "\n${GREEN}✅ Installation completed! Your WhatsApp API is ready.${NC}\n"