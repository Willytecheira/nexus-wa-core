#!/bin/bash

# WhatsApp Multi-Session API Deployment Script
# Usage: ./deploy.sh [domain] [--skip-backup]

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
BACKUP_DIR="/var/backups/whatsapp-api"
DOMAIN=${1:-"localhost"}
SKIP_BACKUP=${2}

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
    echo -e "${BLUE} WhatsApp API Deployment Script${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Create backup
create_backup() {
    if [[ "$SKIP_BACKUP" == "--skip-backup" ]]; then
        print_warning "Skipping backup as requested"
        return
    fi
    
    print_status "Creating backup..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Create timestamped backup
    BACKUP_NAME="whatsapp-api-$(date +%Y%m%d-%H%M%S)"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    
    # Backup application files
    cp -r "$PROJECT_DIR" "$BACKUP_PATH"
    
    # Backup databases if they exist
    if [ -d "$PROJECT_DIR/server/database" ]; then
        print_status "Backing up database..."
        cp -r "$PROJECT_DIR/server/database" "$BACKUP_PATH/database-backup"
    fi
    
    # Create backup info file
    cat > "$BACKUP_PATH/backup-info.txt" << EOF
Backup created: $(date)
Git commit: $(cd $PROJECT_DIR && git rev-parse HEAD 2>/dev/null || echo "unknown")
Domain: $DOMAIN
Environment: production
EOF
    
    print_status "Backup created: $BACKUP_PATH"
}

# Pre-deployment checks
pre_deploy_checks() {
    print_status "Running pre-deployment checks..."
    
    # Check if project directory exists
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "Project directory not found: $PROJECT_DIR"
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        exit 1
    fi
    
    # Check PM2
    if ! command -v pm2 &> /dev/null; then
        print_error "PM2 is not installed"
        exit 1
    fi
    
    # Run pre-deploy script
    cd "$PROJECT_DIR/server"
    if [ -f "scripts/pre-deploy-check.js" ]; then
        print_status "Running pre-deployment validation..."
        node scripts/pre-deploy-check.js
    fi
}

# Stop application
stop_application() {
    print_status "Stopping application..."
    
    # Stop PM2 processes
    pm2 stop all 2>/dev/null || true
    
    # Wait for processes to stop
    sleep 3
}

# Update code
update_code() {
    print_status "Updating code from repository..."
    
    cd "$PROJECT_DIR"
    
    # Fetch latest changes
    git fetch origin
    
    # Reset to latest main branch
    git reset --hard origin/main
    
    # Update permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"
}

# Install dependencies and build
build_application() {
    print_status "Installing dependencies and building application..."
    
    cd "$PROJECT_DIR"
    
    # Install frontend dependencies and build
    npm install
    npm run build
    
    # Install backend dependencies
    cd server
    npm install --production
    
    # Generate production configuration
    if [ -f "scripts/generate-jwt-secret.js" ]; then
        print_status "Generating production secrets..."
        node scripts/generate-jwt-secret.js
    fi
    
    # Set proper permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"
}

# Configure environment
configure_environment() {
    print_status "Configuring production environment..."
    
    cd "$PROJECT_DIR/server"
    
    # Create production .env if it doesn't exist
    if [ ! -f ".env" ]; then
        cp .env.example .env
        
        # Update domain-specific settings
        sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=https://$DOMAIN|g" .env
        sed -i "s|CORS_ORIGINS=.*|CORS_ORIGINS=https://$DOMAIN,https://www.$DOMAIN|g" .env
        
        print_warning "Environment file created. Please review and update:"
        print_warning "  - JWT_SECRET (should be automatically generated)"
        print_warning "  - Database credentials (if using external DB)"
        print_warning "  - Other production-specific settings"
    fi
}

# Run database migrations
run_migrations() {
    print_status "Running database migrations..."
    
    cd "$PROJECT_DIR/server"
    
    if [ -f "migrations/migrate.js" ]; then
        node migrations/migrate.js
    else
        print_warning "No migration script found, skipping..."
    fi
}

# Configure Nginx
configure_nginx() {
    print_status "Configuring Nginx..."
    
    # Copy Nginx configuration
    if [ -f "$PROJECT_DIR/server/nginx/whatsapp-api.conf" ]; then
        cp "$PROJECT_DIR/server/nginx/whatsapp-api.conf" "/etc/nginx/sites-available/whatsapp-api"
        
        # Update domain in Nginx config
        sed -i "s|server_name _;|server_name $DOMAIN www.$DOMAIN;|g" "/etc/nginx/sites-available/whatsapp-api"
        
        # Enable site
        ln -sf "/etc/nginx/sites-available/whatsapp-api" "/etc/nginx/sites-enabled/"
        
        # Remove default site if it exists
        rm -f "/etc/nginx/sites-enabled/default"
        
        # Test Nginx configuration
        nginx -t
        
        # Reload Nginx
        systemctl reload nginx
        
        print_status "Nginx configured for domain: $DOMAIN"
    else
        print_warning "Nginx configuration not found, skipping..."
    fi
}

# Start application
start_application() {
    print_status "Starting application..."
    
    cd "$PROJECT_DIR/server"
    
    # Start with PM2
    if [ -f "ecosystem.config.js" ]; then
        pm2 start ecosystem.config.js --env production
    else
        pm2 start server.js --name "whatsapp-api" --env production
    fi
    
    # Save PM2 configuration
    pm2 save
    
    # Wait for application to start
    print_status "Waiting for application to start..."
    sleep 10
}

# Health check
health_check() {
    print_status "Performing health check..."
    
    # Check if application is responding
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            print_status "✅ Application is healthy!"
            break
        else
            print_warning "Health check attempt $attempt/$max_attempts failed, retrying..."
            sleep 5
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "❌ Health check failed after $max_attempts attempts"
        return 1
    fi
}

# Clean up old backups
cleanup_backups() {
    print_status "Cleaning up old backups..."
    
    # Keep only last 10 backups
    cd "$BACKUP_DIR"
    ls -t | tail -n +11 | xargs -r rm -rf
    
    print_status "Backup cleanup completed"
}

# Display deployment info
display_deployment_info() {
    print_header
    echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Application URLs:${NC}"
    echo -e "  Frontend: https://$DOMAIN"
    echo -e "  API: https://$DOMAIN/api"
    echo -e "  Health: https://$DOMAIN/health"
    echo ""
    echo -e "${BLUE}Useful commands:${NC}"
    echo -e "  View logs: pm2 logs whatsapp-api"
    echo -e "  Check status: pm2 status"
    echo -e "  Restart app: pm2 restart whatsapp-api"
    echo -e "  Monitor: pm2 monit"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Set up SSL certificate: certbot --nginx -d $DOMAIN"
    echo -e "  2. Test all functionality"
    echo -e "  3. Update DNS if needed"
    echo -e "  4. Change default admin password"
    echo ""
}

# Rollback function
rollback() {
    local backup_name=$1
    
    if [ -z "$backup_name" ]; then
        print_error "Please specify backup name for rollback"
        echo "Available backups:"
        ls -la "$BACKUP_DIR"
        exit 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [ ! -d "$backup_path" ]; then
        print_error "Backup not found: $backup_path"
        exit 1
    fi
    
    print_warning "Rolling back to: $backup_name"
    
    # Stop application
    stop_application
    
    # Restore backup
    rm -rf "$PROJECT_DIR"
    cp -r "$backup_path" "$PROJECT_DIR"
    
    # Start application
    cd "$PROJECT_DIR/server"
    pm2 start ecosystem.config.js --env production
    
    print_status "Rollback completed"
}

# Main deployment function
main() {
    print_header
    
    # Handle rollback
    if [ "$1" = "rollback" ]; then
        rollback "$2"
        exit 0
    fi
    
    # Pre-flight checks
    check_root
    pre_deploy_checks
    
    # Create backup
    create_backup
    
    # Deployment steps
    stop_application
    update_code
    build_application
    configure_environment
    run_migrations
    configure_nginx
    start_application
    
    # Post-deployment
    if health_check; then
        cleanup_backups
        display_deployment_info
    else
        print_error "Deployment failed health check!"
        print_warning "Consider rolling back: ./deploy.sh rollback [backup-name]"
        exit 1
    fi
}

# Show usage if no arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <domain> [--skip-backup]"
    echo "       $0 rollback <backup-name>"
    echo ""
    echo "Examples:"
    echo "  $0 myapi.com"
    echo "  $0 localhost --skip-backup"
    echo "  $0 rollback whatsapp-api-20231201-120000"
    exit 1
fi

# Run main function
main "$@"