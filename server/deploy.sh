#!/bin/bash

# WhatsApp Multi-Session API - Production Deployment Script
# Version: 2.0.0
# Author: WhatsApp API Team

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="whatsapp-api"
PROJECT_DIR="/var/www/whatsapp-api"
BACKUP_DIR="/var/backups/whatsapp-api"
LOG_FILE="/var/log/whatsapp-api-deploy.log"
GITHUB_REPO="https://github.com/yourusername/whatsapp-multi-session-api.git"
BRANCH="${1:-main}"

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Pre-deployment checks
pre_deploy_checks() {
    log "Starting pre-deployment checks..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
    fi
    
    # Check system requirements
    if ! command -v node &> /dev/null; then
        error "Node.js is not installed"
    fi
    
    if ! command -v pm2 &> /dev/null; then
        error "PM2 is not installed"
    fi
    
    if ! command -v git &> /dev/null; then
        error "Git is not installed"
    fi
    
    # Check Node.js version
    NODE_VERSION=$(node -v | cut -d'v' -f2)
    REQUIRED_VERSION="18.0.0"
    if ! dpkg --compare-versions "$NODE_VERSION" "ge" "$REQUIRED_VERSION"; then
        error "Node.js version $NODE_VERSION is too old. Required: $REQUIRED_VERSION+"
    fi
    
    log "Pre-deployment checks completed successfully"
}

# Create backup
create_backup() {
    log "Creating backup..."
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"
    
    mkdir -p "$BACKUP_PATH"
    
    # Backup current application
    if [ -d "$PROJECT_DIR" ]; then
        cp -r "$PROJECT_DIR" "$BACKUP_PATH/app"
        log "Application backup created at $BACKUP_PATH/app"
    fi
    
    # Backup database
    if [ -f "$PROJECT_DIR/server/database/whatsapp_api.db" ]; then
        cp "$PROJECT_DIR/server/database/whatsapp_api.db" "$BACKUP_PATH/database.db"
        log "Database backup created at $BACKUP_PATH/database.db"
    fi
    
    # Backup sessions
    if [ -d "$PROJECT_DIR/server/sessions" ]; then
        cp -r "$PROJECT_DIR/server/sessions" "$BACKUP_PATH/"
        log "Sessions backup created at $BACKUP_PATH/sessions"
    fi
    
    # Store backup path for potential rollback
    echo "$BACKUP_PATH" > /tmp/whatsapp-api-last-backup
    
    log "Backup completed: $BACKUP_PATH"
}

# Deploy application
deploy_application() {
    log "Starting application deployment..."
    
    # Stop current application
    if pm2 list | grep -q "$PROJECT_NAME"; then
        log "Stopping current application..."
        pm2 stop "$PROJECT_NAME" || true
    fi
    
    # Create project directory if it doesn't exist
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Clone or update repository
    if [ ! -d ".git" ]; then
        log "Cloning repository..."
        git clone "$GITHUB_REPO" .
    else
        log "Updating repository..."
        git fetch origin
        git reset --hard "origin/$BRANCH"
        git clean -fd
    fi
    
    # Switch to specified branch
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
    
    # Install dependencies for server
    log "Installing server dependencies..."
    cd server
    npm ci --production
    
    # Install dependencies for frontend
    log "Installing frontend dependencies..."
    cd ..
    npm ci
    
    # Build frontend
    log "Building frontend..."
    npm run build
    
    # Copy environment file if it doesn't exist
    if [ ! -f "server/.env" ]; then
        cp "server/.env.example" "server/.env"
        warning "Environment file created from example. Please configure it manually."
    fi
    
    # Set proper permissions
    chown -R www-data:www-data "$PROJECT_DIR"
    chmod -R 755 "$PROJECT_DIR"
    
    log "Application deployment completed"
}

# Start services
start_services() {
    log "Starting services..."
    
    cd "$PROJECT_DIR/server"
    
    # Start application with PM2
    if pm2 list | grep -q "$PROJECT_NAME"; then
        pm2 restart ecosystem.config.js
    else
        pm2 start ecosystem.config.js
    fi
    
    # Save PM2 configuration
    pm2 save
    
    log "Services started successfully"
}

# Health check
health_check() {
    log "Performing health check..."
    
    # Wait for application to start
    sleep 10
    
    # Check if PM2 process is running
    if ! pm2 list | grep -q "$PROJECT_NAME.*online"; then
        error "Application failed to start"
    fi
    
    # Check if application responds
    if ! curl -f http://localhost:3000/health > /dev/null 2>&1; then
        warning "Health check endpoint not responding"
    else
        log "Health check passed"
    fi
    
    log "Deployment completed successfully!"
}

# Cleanup old backups
cleanup_backups() {
    log "Cleaning up old backups..."
    
    # Keep only last 10 backups
    find "$BACKUP_DIR" -name "backup_*" -type d | sort -r | tail -n +11 | xargs rm -rf
    
    log "Backup cleanup completed"
}

# Main deployment process
main() {
    log "Starting deployment of WhatsApp Multi-Session API"
    log "Branch: $BRANCH"
    
    pre_deploy_checks
    create_backup
    deploy_application
    start_services
    health_check
    cleanup_backups
    
    log "Deployment completed successfully!"
    info "Application is running at: http://localhost:3000"
    info "Admin panel: http://localhost:3000/admin"
    info "API docs: http://localhost:3000/docs"
}

# Trap errors and provide rollback option
trap 'error "Deployment failed! Run ./rollback.sh to restore previous version"' ERR

# Run main function
main

# Create deployment success marker
echo "$(date)" > "$PROJECT_DIR/.last-deployment"

log "Deployment process completed!"