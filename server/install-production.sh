#!/bin/bash

# Production Installation Script for WhatsApp Multi-Session API
# This script prepares a fresh server for the application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="/var/www/whatsapp-api"
SERVICE_USER="www-data"
DOMAIN=""
EMAIL=""

# Helper functions
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} WhatsApp API Production Setup${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Get user input
get_user_input() {
    print_header
    echo "This script will install and configure the WhatsApp Multi-Session API"
    echo "on this server for production use."
    echo ""
    
    read -p "Enter your domain name (e.g., api.yourdomain.com): " DOMAIN
    read -p "Enter your email for SSL certificate (e.g., admin@yourdomain.com): " EMAIL
    
    if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
        print_error "Domain and email are required"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}Configuration:${NC}"
    echo -e "  Domain: $DOMAIN"
    echo -e "  Email: $EMAIL"
    echo -e "  Project Directory: $PROJECT_DIR"
    echo ""
    
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Installation cancelled"
        exit 0
    fi
}

# Update system
update_system() {
    print_status "Updating system packages..."
    apt update
    apt upgrade -y
}

# Install Node.js
install_nodejs() {
    print_status "Installing Node.js..."
    
    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
    
    # Install PM2 globally
    npm install -g pm2@latest
    
    # Setup PM2 startup
    pm2 startup systemd -u $SERVICE_USER --hp /var/www
    
    print_status "Node.js $(node --version) and PM2 installed"
}

# Install Nginx
install_nginx() {
    print_status "Installing and configuring Nginx..."
    
    apt install -y nginx
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Enable Nginx
    systemctl enable nginx
    systemctl start nginx
    
    print_status "Nginx installed and started"
}

# Install SSL with Certbot
install_ssl() {
    print_status "Installing SSL certificate..."
    
    # Install Certbot
    apt install -y certbot python3-certbot-nginx
    
    # Get SSL certificate
    certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
    
    # Setup auto-renewal
    systemctl enable certbot.timer
    
    print_status "SSL certificate installed for $DOMAIN"
}

# Install additional tools
install_tools() {
    print_status "Installing additional tools..."
    
    apt install -y \
        git \
        curl \
        wget \
        unzip \
        htop \
        ufw \
        fail2ban \
        logrotate
    
    print_status "Additional tools installed"
}

# Configure firewall
configure_firewall() {
    print_status "Configuring firewall..."
    
    # Enable UFW
    ufw --force enable
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Show status
    ufw status
    
    print_status "Firewall configured"
}

# Create directories
create_directories() {
    print_status "Creating project directories..."
    
    # Create main project directory
    mkdir -p $PROJECT_DIR
    
    # Create subdirectories
    mkdir -p $PROJECT_DIR/server/{logs,uploads,qr,sessions,database,backups}
    mkdir -p /var/backups/whatsapp-api
    mkdir -p /var/log/whatsapp-api
    
    # Set ownership
    chown -R $SERVICE_USER:$SERVICE_USER $PROJECT_DIR
    chown -R $SERVICE_USER:$SERVICE_USER /var/backups/whatsapp-api
    chown -R $SERVICE_USER:$SERVICE_USER /var/log/whatsapp-api
    
    # Set permissions
    chmod 755 $PROJECT_DIR
    chmod 750 $PROJECT_DIR/server/database
    chmod 750 $PROJECT_DIR/server/sessions
    
    print_status "Directories created with proper permissions"
}

# Clone repository
clone_repository() {
    print_status "Setting up Git repository..."
    
    cd $PROJECT_DIR
    
    # Initialize git if not already a repository
    if [ ! -d ".git" ]; then
        git init
        print_warning "Repository initialized. You'll need to add your remote and pull code:"
        print_warning "  cd $PROJECT_DIR"
        print_warning "  git remote add origin <your-repo-url>"
        print_warning "  git pull origin main"
    else
        print_status "Git repository already exists"
    fi
    
    # Set ownership
    chown -R $SERVICE_USER:$SERVICE_USER $PROJECT_DIR
}

# Setup logrotate
setup_logrotate() {
    print_status "Setting up log rotation..."
    
    cat > /etc/logrotate.d/whatsapp-api << EOF
$PROJECT_DIR/server/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 $SERVICE_USER $SERVICE_USER
    postrotate
        pm2 reload whatsapp-api > /dev/null 2>&1 || true
    endscript
}

/var/log/whatsapp-api/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 $SERVICE_USER $SERVICE_USER
}
EOF

    print_status "Log rotation configured"
}

# Setup monitoring
setup_monitoring() {
    print_status "Setting up basic monitoring..."
    
    # Create a simple health check script
    cat > /usr/local/bin/whatsapp-api-health << 'EOF'
#!/bin/bash

# Simple health check for WhatsApp API
HEALTH_URL="http://localhost:3000/health"
LOG_FILE="/var/log/whatsapp-api/health-check.log"

# Make health check request
if curl -f -s "$HEALTH_URL" > /dev/null; then
    echo "$(date): ✅ Health check passed" >> "$LOG_FILE"
    exit 0
else
    echo "$(date): ❌ Health check failed" >> "$LOG_FILE"
    # Restart application if health check fails
    pm2 restart whatsapp-api
    exit 1
fi
EOF

    chmod +x /usr/local/bin/whatsapp-api-health
    
    # Add to crontab for www-data user
    (crontab -u $SERVICE_USER -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/whatsapp-api-health") | crontab -u $SERVICE_USER -
    
    print_status "Health monitoring configured"
}

# Display completion info
display_completion_info() {
    print_header
    echo -e "${GREEN}✅ Production server setup completed!${NC}"
    echo ""
    echo -e "${BLUE}What was installed:${NC}"
    echo -e "  ✅ Node.js $(node --version)"
    echo -e "  ✅ PM2 process manager"
    echo -e "  ✅ Nginx web server"
    echo -e "  ✅ SSL certificate for $DOMAIN"
    echo -e "  ✅ Firewall (UFW) configured"
    echo -e "  ✅ Log rotation setup"
    echo -e "  ✅ Basic monitoring"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Add your code to $PROJECT_DIR"
    echo -e "     git remote add origin <your-repo-url>"
    echo -e "     git pull origin main"
    echo ""
    echo -e "  2. Deploy your application:"
    echo -e "     cd $PROJECT_DIR"
    echo -e "     ./server/deploy.sh $DOMAIN"
    echo ""
    echo -e "  3. Your application will be available at:"
    echo -e "     https://$DOMAIN"
    echo ""
    echo -e "${BLUE}Important files and directories:${NC}"
    echo -e "  Project: $PROJECT_DIR"
    echo -e "  Logs: $PROJECT_DIR/server/logs/"
    echo -e "  Nginx config: /etc/nginx/sites-available/whatsapp-api"
    echo -e "  SSL certificates: /etc/letsencrypt/live/$DOMAIN/"
    echo ""
    echo -e "${YELLOW}Security reminders:${NC}"
    echo -e "  🔒 Change default admin password after first login"
    echo -e "  🔒 Review firewall rules: ufw status"
    echo -e "  🔒 Monitor logs regularly"
    echo -e "  🔒 Keep system updated: apt update && apt upgrade"
    echo ""
}

# Main installation function
main() {
    # Pre-flight checks
    check_root
    get_user_input
    
    # System setup
    update_system
    install_nodejs
    install_nginx
    install_tools
    configure_firewall
    
    # Application setup
    create_directories
    clone_repository
    setup_logrotate
    setup_monitoring
    
    # SSL (do this after Nginx is configured)
    install_ssl
    
    # Completion
    display_completion_info
}

# Run main function
main "$@"