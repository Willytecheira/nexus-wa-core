#!/bin/bash

# WhatsApp Multi-Session API - Rollback Script
# Restore previous version from backup

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="/var/www/whatsapp-api"
BACKUP_DIR="/var/backups/whatsapp-api"
LOG_FILE="/var/log/whatsapp-api-rollback.log"

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

# List available backups
list_backups() {
    echo "Available backups:"
    echo "=================="
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "No backup directory found"
        return 1
    fi
    
    local count=0
    for backup in $(find "$BACKUP_DIR" -name "backup_*" -o -name "auto_backup_*" | sort -r); do
        if [ -d "$backup" ]; then
            count=$((count + 1))
            local timestamp=$(basename "$backup" | sed 's/.*backup_//')
            local date_formatted=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}:${timestamp:13:2}" 2>/dev/null || echo "$timestamp")
            local size=$(du -sh "$backup" | cut -f1)
            
            echo "$count) $(basename "$backup") - $date_formatted ($size)"
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo "No backups found"
        return 1
    fi
    
    return 0
}

# Get last backup
get_last_backup() {
    # Check for automatic backup first
    if [ -f "/tmp/whatsapp-api-auto-backup" ]; then
        local auto_backup=$(cat /tmp/whatsapp-api-auto-backup)
        if [ -d "$auto_backup" ]; then
            echo "$auto_backup"
            return 0
        fi
    fi
    
    # Check for last manual backup
    if [ -f "/tmp/whatsapp-api-last-backup" ]; then
        local last_backup=$(cat /tmp/whatsapp-api-last-backup)
        if [ -d "$last_backup" ]; then
            echo "$last_backup"
            return 0
        fi
    fi
    
    # Find most recent backup
    local latest_backup=$(find "$BACKUP_DIR" -name "backup_*" -o -name "auto_backup_*" | sort -r | head -n 1)
    if [ -n "$latest_backup" ] && [ -d "$latest_backup" ]; then
        echo "$latest_backup"
        return 0
    fi
    
    return 1
}

# Rollback to specific backup
rollback_to_backup() {
    local backup_path="$1"
    
    if [ ! -d "$backup_path" ]; then
        error "Backup not found: $backup_path"
    fi
    
    log "Starting rollback to: $(basename "$backup_path")"
    
    # Stop current application
    if pm2 list | grep -q "whatsapp-api"; then
        log "Stopping application..."
        pm2 stop whatsapp-api || true
    fi
    
    # Create emergency backup of current state
    local emergency_backup="$BACKUP_DIR/emergency_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$emergency_backup"
    
    if [ -d "$PROJECT_DIR" ]; then
        cp -r "$PROJECT_DIR" "$emergency_backup/app"
        log "Emergency backup created: $emergency_backup"
    fi
    
    # Restore application files
    if [ -d "$backup_path/app" ]; then
        log "Restoring application files..."
        rm -rf "$PROJECT_DIR"
        cp -r "$backup_path/app" "$PROJECT_DIR"
    else
        error "Application backup not found in: $backup_path"
    fi
    
    # Restore database if exists
    if [ -f "$backup_path/database.db" ]; then
        log "Restoring database..."
        mkdir -p "$PROJECT_DIR/server/database"
        cp "$backup_path/database.db" "$PROJECT_DIR/server/database/whatsapp_api.db"
    fi
    
    # Restore sessions if exists
    if [ -d "$backup_path/sessions" ]; then
        log "Restoring sessions..."
        cp -r "$backup_path/sessions" "$PROJECT_DIR/server/"
    fi
    
    # Set proper permissions
    chown -R www-data:www-data "$PROJECT_DIR"
    chmod -R 755 "$PROJECT_DIR"
    
    # Reinstall dependencies if needed
    local current_dir=$(pwd)
    cd "$PROJECT_DIR/server"
    
    if [ -f "package.json" ]; then
        log "Reinstalling server dependencies..."
        npm ci --production
    fi
    
    cd "$PROJECT_DIR"
    if [ -f "package.json" ]; then
        log "Reinstalling frontend dependencies..."
        npm ci
        npm run build
    fi
    
    cd "$current_dir"
    
    # Start application
    log "Starting application..."
    cd "$PROJECT_DIR/server"
    pm2 start ecosystem.config.js
    
    # Health check
    log "Performing health check..."
    sleep 10
    
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        log "Rollback completed successfully!"
        info "Application restored to: $(basename "$backup_path")"
        
        # Clean up temporary backup markers
        rm -f /tmp/whatsapp-api-auto-backup
        rm -f /tmp/whatsapp-api-last-backup
    else
        error "Health check failed after rollback!"
    fi
}

# Interactive rollback
interactive_rollback() {
    echo "WhatsApp Multi-Session API - Rollback Tool"
    echo "=========================================="
    echo
    
    if ! list_backups; then
        error "No backups available for rollback"
    fi
    
    echo
    read -p "Enter backup number to rollback to (or 'q' to quit): " choice
    
    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        log "Rollback cancelled by user"
        exit 0
    fi
    
    # Get selected backup
    local backups=($(find "$BACKUP_DIR" -name "backup_*" -o -name "auto_backup_*" | sort -r))
    local selected_index=$((choice - 1))
    
    if [ $selected_index -lt 0 ] || [ $selected_index -ge ${#backups[@]} ]; then
        error "Invalid backup selection: $choice"
    fi
    
    local selected_backup="${backups[$selected_index]}"
    
    echo
    echo "Selected backup: $(basename "$selected_backup")"
    echo "WARNING: This will replace the current application!"
    echo
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rollback_to_backup "$selected_backup"
    else
        log "Rollback cancelled by user"
    fi
}

# Quick rollback to last backup
quick_rollback() {
    log "Starting quick rollback to last backup..."
    
    local last_backup
    if ! last_backup=$(get_last_backup); then
        error "No recent backup found for quick rollback"
    fi
    
    echo "Rolling back to: $(basename "$last_backup")"
    rollback_to_backup "$last_backup"
}

# Show rollback status
show_status() {
    echo "Rollback Tool Status"
    echo "==================="
    echo
    
    if [ -d "$PROJECT_DIR" ]; then
        echo "Application Status: Installed"
        if pm2 list | grep -q "whatsapp-api.*online"; then
            echo "Service Status:     Running"
        else
            echo "Service Status:     Stopped"
        fi
        
        if [ -f "$PROJECT_DIR/.last-deployment" ]; then
            echo "Last Deployment:    $(cat "$PROJECT_DIR/.last-deployment")"
        fi
        
        if [ -d "$PROJECT_DIR/.git" ]; then
            local current_commit=$(git -C "$PROJECT_DIR" rev-parse --short HEAD)
            echo "Current Version:    $current_commit"
        fi
    else
        echo "Application Status: Not Installed"
    fi
    
    echo
    echo "Available Backups:"
    if ! list_backups; then
        echo "No backups available"
    fi
    
    echo
    if [ -f "/tmp/whatsapp-api-auto-backup" ]; then
        echo "Last Auto Backup:   $(basename "$(cat /tmp/whatsapp-api-auto-backup)")"
    fi
    
    if [ -f "/tmp/whatsapp-api-last-backup" ]; then
        echo "Last Manual Backup: $(basename "$(cat /tmp/whatsapp-api-last-backup)")"
    fi
}

# Main function
main() {
    case "${1:-interactive}" in
        "quick"|"last")
            quick_rollback
            ;;
        "list")
            list_backups
            ;;
        "status")
            show_status
            ;;
        "interactive")
            interactive_rollback
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [quick|list|status|interactive|help]"
            echo "  quick       - Rollback to last backup"
            echo "  list        - List available backups"
            echo "  status      - Show current status"
            echo "  interactive - Interactive rollback (default)"
            echo "  help        - Show this help"
            ;;
        *)
            if [ -d "$BACKUP_DIR/$1" ]; then
                rollback_to_backup "$BACKUP_DIR/$1"
            else
                error "Unknown command or backup: $1. Use 'help' for usage information."
            fi
            ;;
    esac
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root or with sudo"
fi

# Run main function
main "$@"