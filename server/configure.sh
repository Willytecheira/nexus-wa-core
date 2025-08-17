#!/bin/bash

# WhatsApp Multi-Session API - Configuration Script
# This script helps configure the application after installation

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="/var/www/whatsapp-api"
ENV_FILE="$PROJECT_DIR/server/.env"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
    fi
}

# Configure environment variables
configure_env() {
    log "Configuring environment variables..."
    
    if [ ! -f "$ENV_FILE" ]; then
        cp "$PROJECT_DIR/server/.env.example" "$ENV_FILE"
        log "Created .env file from .env.example"
    fi
    
    echo "Please provide the following configuration:"
    echo
    
    # Frontend URL
    read -p "Enter your domain name (e.g., myapp.com) or server IP: " DOMAIN
    if [ -n "$DOMAIN" ]; then
        sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=https://$DOMAIN|" "$ENV_FILE"
        log "Set FRONTEND_URL to https://$DOMAIN"
    fi
    
    # JWT Secret
    read -p "Enter a secure JWT secret (leave empty to generate): " JWT_SECRET
    if [ -z "$JWT_SECRET" ]; then
        JWT_SECRET=$(openssl rand -hex 32)
        log "Generated random JWT secret"
    fi
    sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" "$ENV_FILE"
    
    # Node Environment
    sed -i "s|NODE_ENV=.*|NODE_ENV=production|" "$ENV_FILE"
    
    log "Environment configuration completed"
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    read -p "Do you have a domain name? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your domain name: " DOMAIN
        
        # Update Nginx configuration
        sed -i "s|server_name .*;|server_name $DOMAIN www.$DOMAIN;|" /etc/nginx/sites-available/whatsapp-api
        
        # Test Nginx configuration
        nginx -t && systemctl reload nginx
        
        log "Nginx configured for domain: $DOMAIN"
        
        # Offer SSL setup
        read -p "Do you want to setup SSL with Let's Encrypt? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_ssl "$DOMAIN"
        fi
    else
        log "Nginx configured for IP access"
    fi
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    local domain=$1
    log "Setting up SSL for $domain..."
    
    # Install Certbot if not installed
    if ! command -v certbot &> /dev/null; then
        apt update
        apt install -y certbot python3-certbot-nginx
    fi
    
    # Get SSL certificate
    certbot --nginx -d "$domain" -d "www.$domain" --non-interactive --agree-tos --email admin@"$domain"
    
    if [ $? -eq 0 ]; then
        log "SSL certificate installed successfully"
        
        # Setup auto-renewal
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
        log "SSL auto-renewal configured"
    else
        warning "SSL setup failed. You can try manually later with: sudo certbot --nginx -d $domain"
    fi
}

# Configure database
configure_database() {
    log "Setting up database..."
    
    cd "$PROJECT_DIR/server"
    
    # Run migrations
    if [ -f "migrations/migrate.js" ]; then
        node migrations/migrate.js
        log "Database migrations completed"
    fi
    
    # Set permissions
    chown -R www-data:www-data "$PROJECT_DIR/server/database"
    chmod 750 "$PROJECT_DIR/server/database"
    chmod 640 "$PROJECT_DIR/server/database"/*.db 2>/dev/null || true
    
    log "Database configuration completed"
}

# Configure application
configure_app() {
    log "Configuring application..."
    
    cd "$PROJECT_DIR"
    
    # Set proper ownership
    chown -R www-data:www-data "$PROJECT_DIR"
    
    # Set proper permissions
    find "$PROJECT_DIR" -type d -exec chmod 755 {} \;
    find "$PROJECT_DIR" -type f -exec chmod 644 {} \;
    chmod +x "$PROJECT_DIR/server"/*.sh
    
    log "Application permissions configured"
}

# Start services
start_services() {
    log "Starting services..."
    
    cd "$PROJECT_DIR/server"
    
    # Stop if running
    pm2 stop whatsapp-api 2>/dev/null || true
    
    # Start application
    pm2 start ecosystem.config.js
    
    # Save PM2 configuration
    pm2 save
    
    # Enable PM2 startup
    pm2 startup systemd -u root --hp /root
    
    log "Services started successfully"
}

# Health check
health_check() {
    log "Performing health check..."
    
    sleep 5
    
    # Check PM2 status
    if pm2 list | grep -q "whatsapp-api.*online"; then
        log "✅ PM2 process is running"
    else
        error "❌ PM2 process is not running"
    fi
    
    # Check Nginx
    if systemctl is-active --quiet nginx; then
        log "✅ Nginx is running"
    else
        error "❌ Nginx is not running"
    fi
    
    # Check application response
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        log "✅ Application is responding"
    else
        warning "⚠️ Application health check failed"
    fi
    
    log "Health check completed"
}

# Display final information
display_info() {
    echo
    echo "=================================="
    echo "🚀 CONFIGURATION COMPLETED!"
    echo "=================================="
    echo
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
    
    # Get domain from env file
    DOMAIN=$(grep "FRONTEND_URL=" "$ENV_FILE" | cut -d'=' -f2 | sed 's|https://||' | sed 's|http://||')
    
    echo "📱 Application URLs:"
    if [[ "$DOMAIN" != *"$SERVER_IP"* ]]; then
        echo "   🌐 Domain: https://$DOMAIN"
    fi
    echo "   🔗 IP: http://$SERVER_IP"
    echo "   ⚡ API: http://$SERVER_IP/api"
    echo "   💊 Health: http://$SERVER_IP/health"
    echo
    
    echo "🔑 Default Credentials:"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo "   ⚠️  CHANGE THESE IMMEDIATELY!"
    echo
    
    echo "🛠️ Useful Commands:"
    echo "   Status: sudo pm2 status"
    echo "   Logs: sudo pm2 logs whatsapp-api"
    echo "   Restart: sudo pm2 restart whatsapp-api"
    echo "   Health Check: sudo $PROJECT_DIR/server/health-check.sh"
    echo "   Update: sudo $PROJECT_DIR/server/update.sh"
    echo
    
    echo "📁 Important Paths:"
    echo "   Project: $PROJECT_DIR"
    echo "   Config: $ENV_FILE"
    echo "   Logs: /var/log/whatsapp-api-*.log"
    echo "   Nginx: /etc/nginx/sites-available/whatsapp-api"
    echo
    
    echo "✅ Your WhatsApp Multi-Session API is ready!"
    echo "=================================="
}

# Main configuration process
main() {
    log "Starting WhatsApp Multi-Session API configuration..."
    
    check_root
    
    # Check if project exists
    if [ ! -d "$PROJECT_DIR" ]; then
        error "Project directory not found. Please run install.sh first."
    fi
    
    configure_env
    configure_nginx
    configure_database
    configure_app
    start_services
    health_check
    display_info
    
    log "Configuration completed successfully!"
}

# Run main function
main "$@"