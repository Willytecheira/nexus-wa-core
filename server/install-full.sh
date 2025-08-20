#!/bin/bash

# WhatsApp Multi-Session API - Complete Installation Script
# This script handles the complete installation and configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="whatsapp-api"
PROJECT_DIR="/var/www/$PROJECT_NAME"
BACKUP_DIR="/var/backups/$PROJECT_NAME"
LOG_FILE="/var/log/${PROJECT_NAME}-install.log"
REPO_URL="https://github.com/your-username/whatsapp-multi-session-api.git" # Update this with your repo
BRANCH="main"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    echo "[ERROR] $1" >> $LOG_FILE
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    echo "[WARNING] $1" >> $LOG_FILE
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
    echo "[INFO] $1" >> $LOG_FILE
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo $0"
    fi
}

# System updates and dependencies
install_system_dependencies() {
    log "Updating system and installing dependencies..."
    
    apt-get update
    apt-get upgrade -y
    
    # Install essential packages
    apt-get install -y \
        curl \
        wget \
        git \
        nginx \
        ufw \
        fail2ban \
        certbot \
        python3-certbot-nginx \
        sqlite3 \
        unzip \
        htop \
        tree \
        jq
    
    log "System dependencies installed"
}

# Install Node.js
install_nodejs() {
    log "Installing Node.js 18.x..."
    
    # Remove existing Node.js if present
    apt-get remove -y nodejs npm || true
    
    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    # Install PM2 globally
    npm install -g pm2
    
    # Verify installation
    node_version=$(node --version)
    npm_version=$(npm --version)
    pm2_version=$(pm2 --version)
    
    info "Node.js version: $node_version"
    info "NPM version: $npm_version"
    info "PM2 version: $pm2_version"
    
    log "Node.js and PM2 installed successfully"
}

# Setup firewall
setup_firewall() {
    log "Configuring firewall..."
    
    # Reset UFW
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (be careful with this!)
    ufw allow 22/tcp
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable firewall
    ufw --force enable
    
    log "Firewall configured"
}

# Create project structure
create_project_structure() {
    log "Creating project structure..."
    
    # Backup existing installation if present
    if [[ -d "$PROJECT_DIR" ]]; then
        warning "Existing installation found, creating backup..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$PROJECT_DIR" "$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S)"
        rm -rf "$PROJECT_DIR"
    fi
    
    # Create directories
    mkdir -p "$PROJECT_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p /var/log/$PROJECT_NAME
    
    # Set proper ownership
    chown -R www-data:www-data "$PROJECT_DIR"
    chown -R www-data:www-data "/var/log/$PROJECT_NAME"
    
    log "Project structure created"
}

# Clone and setup repository
clone_repository() {
    log "Cloning repository..."
    
    cd "$PROJECT_DIR"
    
    # If we have a repository URL, clone it
    if [[ "$REPO_URL" != *"your-username"* ]]; then
        git clone -b "$BRANCH" "$REPO_URL" .
    else
        # If no repository is configured, create a basic structure
        warning "No repository configured. Creating basic structure..."
        mkdir -p server
        
        # Create a basic server structure
        cat > server/package.json << 'EOF'
{
  "name": "whatsapp-multi-session-api",
  "version": "2.0.0",
  "description": "WhatsApp Multi-Session API Server",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.7.2",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "express-rate-limit": "^6.8.1",
    "morgan": "^1.10.0",
    "sqlite3": "^5.1.6",
    "whatsapp-web.js": "^1.23.0",
    "qrcode": "^1.5.3",
    "multer": "^1.4.5-lts.1"
  }
}
EOF
        info "Basic package.json created. You'll need to add your application files."
    fi
    
    # Set ownership
    chown -R www-data:www-data "$PROJECT_DIR"
    
    log "Repository setup completed"
}

# Generate secure configuration
generate_configuration() {
    log "Generating secure configuration..."
    
    cd "$PROJECT_DIR/server"
    
    # Get server info
    SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    
    # Ask for domain or use IP
    read -p "Enter your domain name (or press Enter to use IP $SERVER_IP): " DOMAIN
    
    if [[ -z "$DOMAIN" ]]; then
        FRONTEND_URL="http://$SERVER_IP"
        info "Using IP-based configuration: $FRONTEND_URL"
    else
        read -p "Use HTTPS for $DOMAIN? (y/N): " USE_HTTPS
        if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
            FRONTEND_URL="https://$DOMAIN"
        else
            FRONTEND_URL="http://$DOMAIN"
        fi
        info "Using domain-based configuration: $FRONTEND_URL"
    fi
    
    # Generate JWT secret
    JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 32)
    
    # Create .env file
    cat > .env << EOF
# Server Configuration
NODE_ENV=production
PORT=3000

# Security
JWT_SECRET=${JWT_SECRET}

# Frontend Configuration
FRONTEND_URL=${FRONTEND_URL}
CORS_ORIGINS=${FRONTEND_URL},http://localhost:5173,http://127.0.0.1:5173

# Database Configuration
DATABASE_PATH=./data/whatsapp.db

# Logging
LOG_LEVEL=info
LOG_FILE=../logs/application.log

# WhatsApp Configuration
WHATSAPP_SESSION_TIMEOUT=300000
WHATSAPP_MAX_SESSIONS=50

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# File Upload
MAX_FILE_SIZE=10485760
UPLOAD_PATH=./uploads

# Backup Configuration
BACKUP_SCHEDULE=0 2 * * *
BACKUP_RETENTION_DAYS=30

# Monitoring
HEALTH_CHECK_INTERVAL=30000

# Production Settings
PM2_INSTANCES=1
PM2_MAX_MEMORY=2048MB
EOF

    chmod 600 .env
    chown www-data:www-data .env
    
    # Store configuration for later use
    echo "DOMAIN=$DOMAIN" > /tmp/whatsapp-config
    echo "FRONTEND_URL=$FRONTEND_URL" >> /tmp/whatsapp-config
    echo "USE_HTTPS=$USE_HTTPS" >> /tmp/whatsapp-config
    
    log "Configuration generated and secured"
}

# Install application dependencies
install_dependencies() {
    log "Installing application dependencies..."
    
    cd "$PROJECT_DIR/server"
    
    # Install server dependencies
    npm install --only=production
    
    # If frontend exists, build it
    if [[ -f "../package.json" ]]; then
        cd "$PROJECT_DIR"
        npm install
        npm run build
        
        # Move built files to server
        if [[ -d "dist" ]]; then
            rm -rf server/public
            mv dist server/public
            log "Frontend built and moved to server/public"
        fi
    fi
    
    # Create necessary directories
    cd "$PROJECT_DIR/server"
    mkdir -p data logs uploads qr-codes
    chown -R www-data:www-data data logs uploads qr-codes
    
    log "Dependencies installed"
}

# Setup database
setup_database() {
    log "Setting up database..."
    
    cd "$PROJECT_DIR/server"
    
    # Run migrations if they exist
    if [[ -f "migrations/migrate.js" ]]; then
        sudo -u www-data node migrations/migrate.js
    fi
    
    # Ensure proper permissions
    chown -R www-data:www-data data/
    chmod 755 data/
    
    log "Database setup completed"
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    # Load configuration
    source /tmp/whatsapp-config
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/$PROJECT_NAME << EOF
server {
    listen 80;
    server_name ${DOMAIN:-_};
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'" always;
    
    # Frontend static files
    location / {
        root $PROJECT_DIR/server/public;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # API routes
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:3000/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # WebSocket support
    location /socket.io/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # File uploads (if needed)
    location /uploads/ {
        alias $PROJECT_DIR/server/uploads/;
        expires 1d;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    nginx -t || error "Nginx configuration test failed"
    
    # Reload Nginx
    systemctl reload nginx
    systemctl enable nginx
    
    log "Nginx configured successfully"
}

# Setup SSL if requested
setup_ssl() {
    source /tmp/whatsapp-config
    
    if [[ "$USE_HTTPS" =~ ^[Yy]$ ]] && [[ -n "$DOMAIN" ]]; then
        log "Setting up SSL certificate..."
        
        # Get SSL certificate
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "admin@${DOMAIN}" || {
            warning "SSL setup failed. Continuing without SSL."
            return
        }
        
        # Update environment
        sed -i "s|FRONTEND_URL=http://${DOMAIN}|FRONTEND_URL=https://${DOMAIN}|" "$PROJECT_DIR/server/.env"
        
        log "SSL certificate installed"
    fi
}

# Setup PM2 and start application
start_application() {
    log "Starting application with PM2..."
    
    cd "$PROJECT_DIR/server"
    
    # Create PM2 ecosystem file if it doesn't exist
    if [[ ! -f "ecosystem.config.js" ]]; then
        cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'whatsapp-api',
    script: 'server.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    log_file: '../logs/combined.log',
    out_file: '../logs/out.log',
    error_file: '../logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    max_memory_restart: '2G',
    node_args: '--max-old-space-size=2048'
  }]
};
EOF
    fi
    
    # Start with PM2
    sudo -u www-data pm2 start ecosystem.config.js --env production
    sudo -u www-data pm2 save
    
    # Setup PM2 to start on boot
    pm2 startup systemd -u www-data --hp /var/www
    
    log "Application started with PM2"
}

# Perform health checks
health_check() {
    log "Performing health checks..."
    
    sleep 5
    
    # Check if application is running
    if ! sudo -u www-data pm2 list | grep -q "online"; then
        error "Application is not running in PM2"
    fi
    
    # Test local connectivity
    for i in {1..30}; do
        if curl -s http://localhost:3000/health > /dev/null; then
            log "✅ Local health check passed"
            break
        fi
        info "Waiting for application... ($i/30)"
        sleep 2
    done
    
    # Test external connectivity
    source /tmp/whatsapp-config
    if curl -s "${FRONTEND_URL}/health" > /dev/null; then
        log "✅ External health check passed"
    else
        warning "External health check failed. Check firewall and DNS settings."
    fi
    
    log "Health checks completed"
}

# Setup monitoring and maintenance
setup_monitoring() {
    log "Setting up monitoring and maintenance..."
    
    # Create log rotation
    cat > /etc/logrotate.d/$PROJECT_NAME << EOF
/var/log/$PROJECT_NAME/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0644 www-data www-data
    postrotate
        sudo -u www-data pm2 reloadLogs
    endscript
}
EOF

    # Create backup script
    cat > /usr/local/bin/${PROJECT_NAME}-backup << EOF
#!/bin/bash
BACKUP_DIR="$BACKUP_DIR"
PROJECT_DIR="$PROJECT_DIR"
DATE=\$(date +%Y%m%d-%H%M%S)

mkdir -p "\$BACKUP_DIR"
tar -czf "\$BACKUP_DIR/backup-\$DATE.tar.gz" -C "\$PROJECT_DIR" .

# Keep only last 10 backups
ls -t "\$BACKUP_DIR"/backup-*.tar.gz | tail -n +11 | xargs rm -f

echo "Backup completed: \$BACKUP_DIR/backup-\$DATE.tar.gz"
EOF

    chmod +x /usr/local/bin/${PROJECT_NAME}-backup
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/${PROJECT_NAME}-backup") | crontab -
    
    log "Monitoring and maintenance setup completed"
}

# Display final information
display_final_info() {
    log "🎉 Installation completed successfully!"
    
    source /tmp/whatsapp-config
    
    echo
    echo -e "${GREEN}📋 Installation Summary:${NC}"
    echo -e "${BLUE}Application URL: ${FRONTEND_URL}${NC}"
    echo -e "${BLUE}Health Check: ${FRONTEND_URL}/health${NC}"
    echo -e "${BLUE}API Base: ${FRONTEND_URL}/api${NC}"
    echo
    echo -e "${YELLOW}🔐 Default Credentials:${NC}"
    echo -e "${YELLOW}Username: admin${NC}"
    echo -e "${YELLOW}Password: admin123${NC}"
    echo -e "${RED}⚠️  CRITICAL: Change the default password immediately after first login!${NC}"
    echo
    echo -e "${GREEN}📁 Important Paths:${NC}"
    echo -e "${BLUE}Application: $PROJECT_DIR${NC}"
    echo -e "${BLUE}Configuration: $PROJECT_DIR/server/.env${NC}"
    echo -e "${BLUE}Logs: /var/log/$PROJECT_NAME${NC}"
    echo -e "${BLUE}Database: $PROJECT_DIR/server/data${NC}"
    echo -e "${BLUE}Nginx Config: /etc/nginx/sites-available/$PROJECT_NAME${NC}"
    echo
    echo -e "${GREEN}🔧 Management Commands:${NC}"
    echo -e "${BLUE}View logs: sudo -u www-data pm2 logs whatsapp-api${NC}"
    echo -e "${BLUE}Restart app: sudo -u www-data pm2 restart whatsapp-api${NC}"
    echo -e "${BLUE}App status: sudo -u www-data pm2 status${NC}"
    echo -e "${BLUE}Manual backup: /usr/local/bin/${PROJECT_NAME}-backup${NC}"
    echo -e "${BLUE}Nginx status: systemctl status nginx${NC}"
    echo -e "${BLUE}View Nginx logs: tail -f /var/log/nginx/error.log${NC}"
    echo
    echo -e "${GREEN}🔥 Next Steps:${NC}"
    echo -e "${BLUE}1. Access your application at: ${FRONTEND_URL}${NC}"
    echo -e "${BLUE}2. Login with admin/admin123${NC}"
    echo -e "${BLUE}3. IMMEDIATELY change the default password${NC}"
    echo -e "${BLUE}4. Configure your WhatsApp sessions${NC}"
    echo -e "${BLUE}5. Review the logs to ensure everything is working${NC}"
    
    # Cleanup temporary files
    rm -f /tmp/whatsapp-config
}

# Main installation function
main() {
    log "🚀 Starting WhatsApp Multi-Session API Installation"
    log "This will install and configure the complete system"
    
    check_root
    install_system_dependencies  
    install_nodejs
    setup_firewall
    create_project_structure
    clone_repository
    generate_configuration
    install_dependencies
    setup_database
    configure_nginx
    setup_ssl
    start_application
    health_check
    setup_monitoring
    display_final_info
    
    log "✅ Installation completed successfully!"
    log "Check the information above and visit your application URL to get started."
}

# Handle script interruption
trap 'error "Installation interrupted"' INT TERM

# Start installation
main "$@"