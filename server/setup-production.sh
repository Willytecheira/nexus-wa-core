#!/bin/bash

# WhatsApp Multi-Session API - Production Setup Script
# This script configures the environment for production deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo $0"
    fi
}

# Generate secure JWT secret
generate_jwt_secret() {
    openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 32
}

# Setup environment file
setup_environment() {
    log "Setting up environment configuration..."
    
    # Get server IP/domain
    SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    
    read -p "Enter your domain name (or press Enter for IP-based setup): " DOMAIN
    
    if [[ -z "$DOMAIN" ]]; then
        FRONTEND_URL="http://${SERVER_IP}"
        CORS_ORIGINS="http://${SERVER_IP},http://localhost:5173,http://127.0.0.1:5173"
        info "Using IP-based configuration: $FRONTEND_URL"
    else
        # Validate domain format
        if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
            warning "Domain format may be invalid. Proceeding anyway..."
        fi
        
        read -p "Use HTTPS? (y/N): " USE_HTTPS
        if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
            FRONTEND_URL="https://${DOMAIN}"
        else
            FRONTEND_URL="http://${DOMAIN}"
        fi
        CORS_ORIGINS="${FRONTEND_URL},http://localhost:5173,http://127.0.0.1:5173"
        info "Using domain-based configuration: $FRONTEND_URL"
    fi
    
    # Generate JWT secret
    JWT_SECRET=$(generate_jwt_secret)
    info "Generated JWT secret"
    
    # Create .env file
    cat > .env << EOF
# Server Configuration
NODE_ENV=production
PORT=3000

# Security
JWT_SECRET=${JWT_SECRET}

# Frontend Configuration
FRONTEND_URL=${FRONTEND_URL}
CORS_ORIGINS=${CORS_ORIGINS}

# Database Configuration
DATABASE_PATH=./data/whatsapp.db

# Logging
LOG_LEVEL=info

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
    log "Environment file created with secure permissions"
}

# Install Node.js and PM2
install_nodejs() {
    log "Installing Node.js and PM2..."
    
    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    # Install PM2 globally
    npm install -g pm2
    
    # Setup PM2 startup
    pm2 startup
    
    log "Node.js and PM2 installed successfully"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p data logs uploads qr-codes backups
    
    # Set ownership to current user (not root)
    if [[ -n "$SUDO_USER" ]]; then
        chown -R $SUDO_USER:$SUDO_USER data logs uploads qr-codes backups
    fi
    
    log "Directories created successfully"
}

# Install dependencies and build
build_application() {
    log "Installing dependencies and building application..."
    
    # Install server dependencies
    npm install --only=production
    
    # Build frontend (if package.json exists in root)
    if [[ -f "../package.json" ]]; then
        cd ..
        npm install
        npm run build
        
        # Copy built files to server/public
        rm -rf server/public
        cp -r dist server/public
        cd server
        
        log "Frontend built and copied to server/public"
    else
        warning "Frontend package.json not found, skipping frontend build"
    fi
    
    log "Application built successfully"
}

# Setup systemd service (alternative to PM2)
setup_systemd_service() {
    log "Setting up systemd service..."
    
    cat > /etc/systemd/system/whatsapp-api.service << EOF
[Unit]
Description=WhatsApp Multi-Session API
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/whatsapp-api/server
Environment=NODE_ENV=production
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=whatsapp-api

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable whatsapp-api
    
    log "Systemd service configured"
}

# Setup Nginx
setup_nginx() {
    log "Setting up Nginx..."
    
    # Install Nginx if not present
    if ! command -v nginx &> /dev/null; then
        apt-get update
        apt-get install -y nginx
    fi
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/whatsapp-api << EOF
server {
    listen 80;
    server_name ${DOMAIN:-$SERVER_IP};
    
    # Frontend static files
    location / {
        root /var/www/whatsapp-api/server/public;
        try_files \$uri \$uri/ /index.html;
        add_header Cache-Control "public, max-age=3600";
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
    
    # WebSocket for real-time updates
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
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF

    # Enable the site
    ln -sf /etc/nginx/sites-available/whatsapp-api /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload Nginx
    nginx -t
    systemctl restart nginx
    systemctl enable nginx
    
    log "Nginx configured and started"
}

# Run database migrations
run_migrations() {
    log "Running database migrations..."
    
    if [[ -f "migrations/migrate.js" ]]; then
        node migrations/migrate.js
        log "Database migrations completed"
    else
        warning "No migrations found"
    fi
}

# Start services
start_services() {
    log "Starting services..."
    
    # Use PM2 if available, otherwise use systemd
    if command -v pm2 &> /dev/null; then
        pm2 start ecosystem.config.js --env production
        pm2 save
        log "Application started with PM2"
    else
        systemctl start whatsapp-api
        log "Application started with systemd"
    fi
}

# Perform health check
health_check() {
    log "Performing health check..."
    
    sleep 5
    
    # Check if the application is responding
    for i in {1..30}; do
        if curl -s http://localhost:3000/health > /dev/null; then
            log "✅ Application is healthy and responding"
            
            # Test external access
            if curl -s "http://${SERVER_IP}/health" > /dev/null; then
                log "✅ External access working"
            else
                warning "External access may not be working. Check firewall settings."
            fi
            
            return 0
        fi
        
        info "Waiting for application to start... ($i/30)"
        sleep 2
    done
    
    error "❌ Application health check failed"
}

# Display final information
display_info() {
    log "🎉 Setup completed successfully!"
    echo
    echo -e "${GREEN}📋 Important Information:${NC}"
    echo -e "${BLUE}Application URL: ${FRONTEND_URL}${NC}"
    echo -e "${BLUE}API Endpoint: ${FRONTEND_URL}/api${NC}"
    echo -e "${BLUE}Health Check: ${FRONTEND_URL}/health${NC}"
    echo
    echo -e "${YELLOW}🔐 Default Credentials:${NC}"
    echo -e "${YELLOW}Username: admin${NC}"
    echo -e "${YELLOW}Password: admin123${NC}"
    echo -e "${RED}⚠️  IMPORTANT: Change the default password immediately!${NC}"
    echo
    echo -e "${GREEN}📁 Important Paths:${NC}"
    echo -e "${BLUE}Application: /var/www/whatsapp-api${NC}"
    echo -e "${BLUE}Environment: /var/www/whatsapp-api/server/.env${NC}"
    echo -e "${BLUE}Logs: /var/www/whatsapp-api/server/logs${NC}"
    echo -e "${BLUE}Database: /var/www/whatsapp-api/server/data${NC}"
    echo
    echo -e "${GREEN}🔧 Useful Commands:${NC}"
    echo -e "${BLUE}View logs: pm2 logs whatsapp-api${NC}"
    echo -e "${BLUE}Restart app: pm2 restart whatsapp-api${NC}"
    echo -e "${BLUE}App status: pm2 status${NC}"
    echo -e "${BLUE}Nginx status: systemctl status nginx${NC}"
    echo -e "${BLUE}View Nginx logs: tail -f /var/log/nginx/error.log${NC}"
}

# Main setup function
main() {
    log "🚀 Starting WhatsApp Multi-Session API Production Setup"
    
    check_root
    setup_environment
    install_nodejs
    create_directories
    build_application
    setup_nginx
    run_migrations
    start_services
    health_check
    display_info
    
    log "✅ Production setup completed successfully!"
}

# Run main function
main "$@"