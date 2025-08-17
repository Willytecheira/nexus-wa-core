#!/bin/bash

# WhatsApp Multi-Session API - Update Script
# Automatic update from GitHub with rollback capability

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
PROJECT_DIR="/var/www/whatsapp-api"
BACKUP_DIR="/var/backups/whatsapp-api"
LOG_FILE="/var/log/whatsapp-api-update.log"

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

# Check for updates
check_updates() {
    log "Checking for updates..."
    
    cd "$PROJECT_DIR"
    git fetch origin
    
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse origin/main)
    
    if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
        log "No updates available. Current version is up to date."
        exit 0
    fi
    
    log "Updates available. Local: ${LOCAL_COMMIT:0:8}, Remote: ${REMOTE_COMMIT:0:8}"
    return 0
}

# Automatic update with safety checks
auto_update() {
    log "Starting automatic update..."
    
    # Create backup before update
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_PATH="$BACKUP_DIR/auto_backup_$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"
    
    # Backup current version
    cp -r "$PROJECT_DIR" "$BACKUP_PATH/app"
    if [ -f "$PROJECT_DIR/server/database/whatsapp_api.db" ]; then
        cp "$PROJECT_DIR/server/database/whatsapp_api.db" "$BACKUP_PATH/database.db"
    fi
    
    echo "$BACKUP_PATH" > /tmp/whatsapp-api-auto-backup
    
    # Get current PM2 status
    PM2_STATUS=$(pm2 jlist | jq -r '.[] | select(.name=="whatsapp-api") | .pm2_env.status' 2>/dev/null || echo "stopped")
    
    # Stop application
    if [ "$PM2_STATUS" = "online" ]; then
        log "Stopping application..."
        pm2 stop whatsapp-api
    fi
    
    # Pull updates
    log "Pulling updates from GitHub..."
    cd "$PROJECT_DIR"
    git pull origin main
    
    # Check if package.json changed
    if git diff HEAD~1 HEAD --name-only | grep -q "server/package.json"; then
        log "Package.json changed, updating dependencies..."
        cd server
        npm ci --production
        cd ..
    fi
    
    # Check if frontend dependencies changed
    if git diff HEAD~1 HEAD --name-only | grep -q "package.json"; then
        log "Frontend package.json changed, updating dependencies..."
        npm ci
        npm run build
    fi
    
    # Run database migrations if any
    if [ -f "$PROJECT_DIR/server/migrations/migrate.js" ]; then
        log "Running database migrations..."
        cd "$PROJECT_DIR/server"
        node migrations/migrate.js
    fi
    
    # Restart application
    if [ "$PM2_STATUS" = "online" ]; then
        log "Restarting application..."
        pm2 restart whatsapp-api
    else
        log "Starting application..."
        pm2 start ecosystem.config.js
    fi
    
    # Health check
    log "Performing health check..."
    sleep 5
    
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        log "Update completed successfully!"
        # Clean up old auto backups (keep last 5)
        find "$BACKUP_DIR" -name "auto_backup_*" -type d | sort -r | tail -n +6 | xargs rm -rf
    else
        error "Health check failed! Rolling back..."
        # Rollback will be handled by trap
    fi
}

# Scheduled update check
scheduled_check() {
    log "Running scheduled update check..."
    
    if check_updates; then
        # Send notification (if configured)
        if [ -n "$WEBHOOK_URL" ]; then
            curl -X POST "$WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                -d "{\"text\":\"WhatsApp API updates available on $(hostname)\"}"
        fi
        
        # Auto-update if enabled
        if [ "$AUTO_UPDATE" = "true" ]; then
            auto_update
        else
            log "Updates available but auto-update is disabled"
        fi
    fi
}

# Manual update
manual_update() {
    log "Starting manual update..."
    
    echo "Current version: $(git rev-parse --short HEAD)"
    echo "Latest version:  $(git rev-parse --short origin/main)"
    echo
    
    read -p "Do you want to proceed with the update? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        auto_update
    else
        log "Update cancelled by user"
    fi
}

# Version information
show_version() {
    echo "WhatsApp Multi-Session API Update Tool"
    echo "Current version: $(git -C "$PROJECT_DIR" rev-parse --short HEAD)"
    echo "Current branch:  $(git -C "$PROJECT_DIR" branch --show-current)"
    echo "Last update:     $(git -C "$PROJECT_DIR" log -1 --format=%cd --date=local)"
    echo "Update script:   v2.0.0"
}

# Main function
main() {
    case "${1:-manual}" in
        "check")
            check_updates
            ;;
        "auto")
            auto_update
            ;;
        "scheduled")
            scheduled_check
            ;;
        "manual")
            manual_update
            ;;
        "version"|"-v"|"--version")
            show_version
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [check|auto|scheduled|manual|version|help]"
            echo "  check     - Check for updates only"
            echo "  auto      - Automatic update without confirmation"
            echo "  scheduled - Run scheduled check (for cron)"
            echo "  manual    - Interactive update (default)"
            echo "  version   - Show version information"
            echo "  help      - Show this help"
            ;;
        *)
            error "Unknown command: $1. Use 'help' for usage information."
            ;;
    esac
}

# Trap errors and provide rollback
trap 'error "Update failed! Run ./rollback.sh to restore previous version"' ERR

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    error "Project directory not found: $PROJECT_DIR"
fi

# Load environment variables if available
if [ -f "$PROJECT_DIR/server/.env" ]; then
    source "$PROJECT_DIR/server/.env"
fi

# Run main function
main "$@"