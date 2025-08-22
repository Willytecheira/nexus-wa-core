#!/bin/bash

# WhatsApp Multi-Session API - Deployment Script (No Nginx)
# Quick deployment script for updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/var/www/whatsapp-api"
SERVICE_USER="whatsapp"

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

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    print_error "Project directory $PROJECT_DIR does not exist. Run install script first."
    exit 1
fi

print_status "Starting deployment..."

# Backup current version
print_status "Creating backup..."
cd $PROJECT_DIR
BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
sudo -u $SERVICE_USER mkdir -p backups
sudo -u $SERVICE_USER tar -czf "backups/${BACKUP_NAME}.tar.gz" \
    --exclude="node_modules" \
    --exclude="logs" \
    --exclude="backups" \
    --exclude=".git" \
    .

# Stop the application
print_status "Stopping application..."
sudo -u $SERVICE_USER pm2 stop all

# Pull latest changes
print_status "Pulling latest changes from repository..."
cd $PROJECT_DIR
sudo -u $SERVICE_USER git fetch origin
sudo -u $SERVICE_USER git reset --hard origin/main

# Install/update backend dependencies
print_status "Installing backend dependencies..."
cd $PROJECT_DIR/server
sudo -u $SERVICE_USER npm install --production

# Install/update frontend dependencies and build
print_status "Building frontend..."
cd $PROJECT_DIR
sudo -u $SERVICE_USER npm install
sudo -u $SERVICE_USER npm run build

# Static files are now served directly from dist directory

# Run database migrations
print_status "Running database migrations..."
cd $PROJECT_DIR/server
sudo -u $SERVICE_USER node migrations/migrate.js

# Restart the application
print_status "Starting application..."
sudo -u $SERVICE_USER pm2 start all

# Wait for application to start
sleep 5

# Check application status
print_status "Checking application status..."
if sudo -u $SERVICE_USER pm2 list | grep -q "online"; then
    print_status "Application is running successfully!"
else
    print_error "Application failed to start. Check logs with: pm2 logs"
    exit 1
fi

# Cleanup old backups (keep last 10)
print_status "Cleaning up old backups..."
cd $PROJECT_DIR/backups
ls -t backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --

print_status "Deployment completed successfully!"

echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}  Deployment Complete${NC}"
echo -e "${GREEN}================================================${NC}\n"

echo -e "${BLUE}📋 Post-deployment Commands:${NC}"
echo -e "   View logs: pm2 logs"
echo -e "   App status: pm2 status"
echo -e "   Restart app: pm2 restart all"
echo -e "   Monitor: pm2 monit"

echo -e "\n${BLUE}🔍 Health Check:${NC}"
if command -v curl &> /dev/null; then
    echo -e "   Testing API health..."
    if curl -s -f http://localhost/health > /dev/null; then
        echo -e "   ${GREEN}✅ API is responding${NC}"
    else
        echo -e "   ${RED}❌ API is not responding${NC}"
    fi
else
    echo -e "   Manual check: visit your domain/IP in browser"
fi

echo -e "\n${GREEN}✅ Deployment completed successfully!${NC}\n"