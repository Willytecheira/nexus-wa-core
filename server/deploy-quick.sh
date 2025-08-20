#!/bin/bash

# WhatsApp Multi-Session API - Quick Deploy Script
# For rapid deployment and updates

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/var/www/whatsapp-api"
REPO_URL="https://github.com/your-username/whatsapp-multi-session-api.git"
BRANCH="main"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Check root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use: sudo $0"
fi

# Quick deployment function
quick_deploy() {
    log "🚀 Starting quick deployment..."
    
    # Stop services
    log "Stopping services..."
    sudo -u www-data pm2 stop whatsapp-api || true
    
    # Backup current version
    if [[ -d "$PROJECT_DIR" ]]; then
        log "Creating backup..."
        cp -r "$PROJECT_DIR" "/tmp/whatsapp-api-backup-$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Update code
    log "Updating code..."
    cd "$PROJECT_DIR"
    
    if [[ -d ".git" ]]; then
        git fetch origin
        git reset --hard origin/$BRANCH
    else
        warning "Not a git repository. Manual deployment needed."
    fi
    
    # Install server dependencies
    log "Installing server dependencies..."
    cd server
    npm install --only=production
    
    # Build frontend if exists
    if [[ -f "../package.json" ]]; then
        log "Building frontend..."
        cd ..
        npm install
        npm run build
        
        if [[ -d "dist" ]]; then
            rm -rf server/public
            mv dist server/public
        fi
        
        cd server
    fi
    
    # Set permissions
    chown -R www-data:www-data "$PROJECT_DIR"
    
    # Restart services
    log "Restarting services..."
    sudo -u www-data pm2 restart whatsapp-api || sudo -u www-data pm2 start ecosystem.config.js
    
    # Quick health check
    sleep 3
    if curl -s http://localhost:3000/health > /dev/null; then
        log "✅ Deployment successful - Application is responding"
    else
        error "❌ Deployment failed - Application not responding"
    fi
}

# Update configuration function
update_config() {
    log "🔧 Updating configuration..."
    
    cd "$PROJECT_DIR/server"
    
    # Backup current .env
    if [[ -f ".env" ]]; then
        cp .env .env.backup
        info "Current .env backed up to .env.backup"
    fi
    
    read -p "Enter your domain/IP: " DOMAIN
    read -p "Use HTTPS? (y/N): " USE_HTTPS
    
    if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
        FRONTEND_URL="https://$DOMAIN"
    else
        FRONTEND_URL="http://$DOMAIN"
    fi
    
    # Update .env
    if [[ -f ".env" ]]; then
        sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=$FRONTEND_URL|" .env
        sed -i "s|CORS_ORIGINS=.*|CORS_ORIGINS=$FRONTEND_URL,http://localhost:5173,http://127.0.0.1:5173|" .env
    else
        warning "No .env file found. Run full installation first."
    fi
    
    log "Configuration updated"
}

# Show status
show_status() {
    log "📊 System Status"
    
    echo -e "\n${BLUE}PM2 Status:${NC}"
    sudo -u www-data pm2 status
    
    echo -e "\n${BLUE}Application Health:${NC}"
    if curl -s http://localhost:3000/health > /dev/null; then
        echo -e "${GREEN}✅ Application is healthy${NC}"
    else
        echo -e "${RED}❌ Application is not responding${NC}"
    fi
    
    echo -e "\n${BLUE}Nginx Status:${NC}"
    systemctl status nginx --no-pager -l
    
    echo -e "\n${BLUE}Disk Usage:${NC}"
    df -h "$PROJECT_DIR"
    
    echo -e "\n${BLUE}Recent Logs:${NC}"
    sudo -u www-data pm2 logs whatsapp-api --lines 10 --nostream
}

# Show help
show_help() {
    echo -e "${GREEN}WhatsApp Multi-Session API - Quick Deploy${NC}"
    echo -e "${BLUE}Usage: $0 [command]${NC}"
    echo
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  deploy     - Quick deployment (default)"
    echo -e "  config     - Update configuration"
    echo -e "  status     - Show system status"
    echo -e "  logs       - Show recent logs"
    echo -e "  restart    - Restart application"
    echo -e "  help       - Show this help"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0         - Quick deploy"
    echo -e "  $0 status  - Check status"
    echo -e "  $0 config  - Update config"
}

# Main command handler
case "${1:-deploy}" in
    "deploy")
        quick_deploy
        ;;
    "config")
        update_config
        ;;
    "status")
        show_status
        ;;
    "logs")
        sudo -u www-data pm2 logs whatsapp-api
        ;;
    "restart")
        log "Restarting application..."
        sudo -u www-data pm2 restart whatsapp-api
        log "Application restarted"
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        error "Unknown command: $1. Use '$0 help' for usage information."
        ;;
esac