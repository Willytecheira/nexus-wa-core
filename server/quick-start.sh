#!/bin/bash

# WhatsApp Multi-Session API - Quick Start Script
# One-command installation and setup

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
GITHUB_REPO="${GITHUB_REPO:-https://github.com/yourusername/whatsapp-multi-session-api.git}"
PROJECT_DIR="/var/www/whatsapp-api"
TEMP_DIR="/tmp/whatsapp-api-setup"

# ASCII Art Logo
show_logo() {
    echo -e "${CYAN}"
    cat << "EOF"
    ╦ ╦┬ ┬┌─┐┌┬┐┌─┐╔═╗┌─┐┌─┐  ╔═╗╔═╗╦
    ║║║├─┤├─┤ │ └─┐╠═╣╠═╝╠═╝  ╠═╣╠═╝║
    ╚╩╝┴ ┴┴ ┴ ┴ └─┘╩ ╩╩  ╩    ╩ ╩╩  ╩
    ╔╦╗┬ ┬┬ ┌┬┐┬   ╔═╗┌─┐┌─┐┌─┐┬┌─┐┌┐┌
    ║║║│ ││  │ │───╚═╗├┤ └─┐└─┐││ ││││
    ╩ ╩└─┘┴─┘┴ ┴   ╚═╝└─┘└─┘└─┘┴└─┘┘└┘
EOF
    echo -e "${NC}"
    echo -e "${PURPLE}🚀 Enterprise WhatsApp Multi-Session API${NC}"
    echo -e "${BLUE}📱 Production-Ready Installation${NC}"
    echo
}

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
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

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check OS
    if ! grep -q "Ubuntu" /etc/os-release; then
        warning "This script is optimized for Ubuntu. Other distributions may require modifications."
    fi
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
    fi
    
    # Check internet connection
    if ! ping -c 1 google.com &> /dev/null; then
        error "No internet connection available"
    fi
    
    # Check available space (minimum 5GB)
    AVAILABLE_SPACE=$(df / | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 5242880 ]; then
        error "Insufficient disk space. At least 5GB required."
    fi
    
    # Check memory (minimum 1GB)
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$TOTAL_MEM" -lt 1024 ]; then
        warning "Low memory detected ($TOTAL_MEM MB). 2GB+ recommended for optimal performance."
    fi
    
    success "System requirements check passed"
}

# Install dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    # Update system
    apt update && apt upgrade -y
    
    # Install essential packages
    apt install -y curl wget git unzip nano software-properties-common apt-transport-https ca-certificates gnupg lsb-release
    
    success "System dependencies installed"
}

# Download and setup project
setup_project() {
    log "Setting up project..."
    
    # Remove temp directory if exists
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Clone repository
    cd "$TEMP_DIR"
    git clone "$GITHUB_REPO" .
    
    # Make scripts executable
    find . -name "*.sh" -exec chmod +x {} \;
    
    success "Project setup completed"
}

# Run installation
run_installation() {
    log "Running automated installation..."
    
    cd "$TEMP_DIR"
    
    # Run install script
    if [ -f "server/install.sh" ]; then
        ./server/install.sh
    else
        error "Install script not found"
    fi
    
    success "Installation completed"
}

# Deploy application
deploy_application() {
    log "Deploying application..."
    
    # Copy project to final location
    mkdir -p "$PROJECT_DIR"
    cp -r "$TEMP_DIR"/* "$PROJECT_DIR/"
    
    # Set permissions
    chown -R www-data:www-data "$PROJECT_DIR"
    
    # Run deployment
    cd "$PROJECT_DIR"
    if [ -f "server/deploy.sh" ]; then
        GITHUB_REPO="$GITHUB_REPO" ./server/deploy.sh
    fi
    
    success "Application deployed"
}

# Interactive configuration
interactive_config() {
    echo
    echo -e "${CYAN}🔧 INTERACTIVE CONFIGURATION${NC}"
    echo "Let's configure your WhatsApp API..."
    echo
    
    # Ask for domain
    read -p "Do you have a domain name? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your domain (e.g., myapi.com): " DOMAIN
        
        if [ -n "$DOMAIN" ]; then
            # Update environment
            sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=https://$DOMAIN|" "$PROJECT_DIR/server/.env"
            
            # Update Nginx
            sed -i "s|server_name .*;|server_name $DOMAIN www.$DOMAIN;|" /etc/nginx/sites-available/whatsapp-api
            nginx -t && systemctl reload nginx
            
            # Ask for SSL
            read -p "Setup free SSL certificate with Let's Encrypt? (Y/n): " -n 1 -r
            echo
            
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                setup_ssl "$DOMAIN"
            fi
        fi
    fi
    
    # Generate secure JWT secret
    JWT_SECRET=$(openssl rand -hex 32)
    sed -i "s|JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" "$PROJECT_DIR/server/.env"
    
    log "Configuration completed"
}

# Setup SSL
setup_ssl() {
    local domain=$1
    log "Setting up SSL for $domain..."
    
    # Install Certbot
    apt install -y certbot python3-certbot-nginx
    
    # Get certificate
    certbot --nginx -d "$domain" -d "www.$domain" --non-interactive --agree-tos --email "admin@$domain" || {
        warning "SSL setup failed. You can configure it manually later with: sudo certbot --nginx -d $domain"
        return
    }
    
    # Setup auto-renewal
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
    
    success "SSL certificate installed and auto-renewal configured"
}

# Final health check
final_health_check() {
    log "Performing final health check..."
    
    sleep 10
    
    # Run comprehensive health check
    if [ -f "$PROJECT_DIR/server/health-check.sh" ]; then
        "$PROJECT_DIR/server/health-check.sh" quick
    fi
    
    # Check if application is responding
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        success "✅ Application is responding correctly"
    else
        error "❌ Application health check failed"
    fi
}

# Display final information
show_final_info() {
    clear
    show_logo
    
    echo -e "${GREEN}🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉${NC}"
    echo
    
    # Get server info
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    DOMAIN=$(grep "FRONTEND_URL=" "$PROJECT_DIR/server/.env" | cut -d'=' -f2 | sed 's|https://||' | sed 's|http://||')
    
    echo -e "${CYAN}📍 ACCESS YOUR APPLICATION:${NC}"
    echo "   🌐 Web Interface: http://$SERVER_IP"
    if [[ "$DOMAIN" != *"$SERVER_IP"* ]] && [ -n "$DOMAIN" ]; then
        echo "   🔗 Domain: https://$DOMAIN"
    fi
    echo "   ⚡ API Endpoint: http://$SERVER_IP/api"
    echo "   💊 Health Check: http://$SERVER_IP/health"
    echo
    
    echo -e "${YELLOW}🔐 DEFAULT CREDENTIALS:${NC}"
    echo "   👤 Username: admin"
    echo "   🔑 Password: admin123"
    echo "   ⚠️  CHANGE THESE IMMEDIATELY AFTER LOGIN!"
    echo
    
    echo -e "${BLUE}🛠️ MANAGEMENT COMMANDS:${NC}"
    echo "   📊 Status: sudo pm2 status"
    echo "   📝 Logs: sudo pm2 logs whatsapp-api"
    echo "   🔄 Restart: sudo pm2 restart whatsapp-api"
    echo "   🏥 Health: sudo $PROJECT_DIR/server/health-check.sh"
    echo "   📦 Update: sudo $PROJECT_DIR/server/update.sh"
    echo "   ↩️  Rollback: sudo $PROJECT_DIR/server/rollback.sh"
    echo "   🧹 Maintenance: sudo $PROJECT_DIR/server/maintenance.sh"
    echo
    
    echo -e "${PURPLE}📁 IMPORTANT LOCATIONS:${NC}"
    echo "   📂 Project: $PROJECT_DIR"
    echo "   ⚙️  Config: $PROJECT_DIR/server/.env"
    echo "   📋 Logs: /var/log/whatsapp-api-*.log"
    echo "   🌐 Nginx: /etc/nginx/sites-available/whatsapp-api"
    echo
    
    echo -e "${GREEN}🎯 NEXT STEPS:${NC}"
    echo "   1. 🔐 Change default admin password"
    echo "   2. 📱 Create your first WhatsApp session"
    echo "   3. 📖 Read the API documentation"
    echo "   4. 🔧 Customize configuration if needed"
    echo "   5. 📊 Monitor with health checks"
    echo
    
    echo -e "${CYAN}💡 TIPS:${NC}"
    echo "   • Use 'sudo pm2 monit' for real-time monitoring"
    echo "   • Check logs regularly with 'sudo pm2 logs'"
    echo "   • Update regularly with 'sudo ./server/update.sh'"
    echo "   • Setup regular backups for production use"
    echo
    
    echo -e "${GREEN}✨ Your WhatsApp Multi-Session API is ready for production! ✨${NC}"
    echo
}

# Cleanup
cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Main installation process
main() {
    clear
    show_logo
    
    echo -e "${YELLOW}🚀 Starting automated installation...${NC}"
    echo "This will install and configure everything needed for WhatsApp Multi-Session API"
    echo
    
    # Confirmation
    read -p "Continue with installation? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    # Installation steps
    check_requirements
    install_dependencies
    setup_project
    run_installation
    deploy_application
    interactive_config
    final_health_check
    show_final_info
    cleanup
    
    log "Installation process completed successfully!"
}

# Handle interrupts
trap 'echo -e "\n${RED}Installation interrupted!${NC}"; cleanup; exit 1' INT TERM

# Run main function
main "$@"