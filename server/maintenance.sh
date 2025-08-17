#!/bin/bash

# WhatsApp Multi-Session API - Maintenance Script
# Automated maintenance tasks and cleanup

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
LOG_FILE="/var/log/whatsapp-api-maintenance.log"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Cleanup old log files
cleanup_logs() {
    log "Cleaning up old log files..."
    
    local log_dir="$PROJECT_DIR/server/logs"
    local system_logs="/var/log"
    
    # Rotate application logs older than 30 days
    if [ -d "$log_dir" ]; then
        find "$log_dir" -name "*.log" -mtime +30 -delete
        log "Cleaned old application logs"
    fi
    
    # Compress logs older than 7 days
    if [ -d "$log_dir" ]; then
        find "$log_dir" -name "*.log" -mtime +7 ! -name "*.gz" -exec gzip {} \;
        log "Compressed old application logs"
    fi
    
    # Clean system logs related to WhatsApp API
    find "$system_logs" -name "*whatsapp-api*" -mtime +60 -delete 2>/dev/null || true
    log "Cleaned old system logs"
}

# Cleanup old backups
cleanup_backups() {
    log "Cleaning up old backups..."
    
    if [ -d "$BACKUP_DIR" ]; then
        # Keep only last 30 backups
        local backup_count=$(find "$BACKUP_DIR" -name "backup_*" -o -name "auto_backup_*" | wc -l)
        if [ "$backup_count" -gt 30 ]; then
            find "$BACKUP_DIR" -name "backup_*" -o -name "auto_backup_*" | sort | head -n $((backup_count - 30)) | xargs rm -rf
            log "Removed old backups, kept last 30"
        else
            log "Backup count: $backup_count (within limit)"
        fi
        
        # Remove emergency backups older than 7 days
        find "$BACKUP_DIR" -name "emergency_*" -mtime +7 -exec rm -rf {} + 2>/dev/null || true
        log "Cleaned old emergency backups"
    fi
}

# Cleanup temporary files
cleanup_temp_files() {
    log "Cleaning up temporary files..."
    
    local temp_dirs=("$PROJECT_DIR/server/uploads/temp" "$PROJECT_DIR/server/qr" "/tmp")
    
    for temp_dir in "${temp_dirs[@]}"; do
        if [ -d "$temp_dir" ]; then
            # Remove files older than 24 hours
            find "$temp_dir" -name "*whatsapp*" -mtime +1 -delete 2>/dev/null || true
            find "$temp_dir" -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
        fi
    done
    
    # Clean PM2 logs
    if command -v pm2 &> /dev/null; then
        pm2 flush whatsapp-api 2>/dev/null || true
        log "Flushed PM2 logs"
    fi
    
    log "Cleaned temporary files"
}

# Database maintenance
database_maintenance() {
    log "Starting database maintenance..."
    
    local db_file="$PROJECT_DIR/server/database/whatsapp_api.db"
    
    if [ -f "$db_file" ]; then
        # Create backup before maintenance
        local backup_file="$BACKUP_DIR/db_maintenance_$(date +%Y%m%d_%H%M%S).db"
        mkdir -p "$BACKUP_DIR"
        cp "$db_file" "$backup_file"
        log "Database backup created: $backup_file"
        
        # Vacuum database
        sqlite3 "$db_file" "VACUUM;" || warning "Database vacuum failed"
        log "Database vacuumed"
        
        # Update statistics
        sqlite3 "$db_file" "ANALYZE;" || warning "Database analyze failed"
        log "Database statistics updated"
        
        # Check database integrity
        local integrity_check=$(sqlite3 "$db_file" "PRAGMA integrity_check;" 2>/dev/null || echo "error")
        if [ "$integrity_check" = "ok" ]; then
            log "Database integrity: OK"
        else
            warning "Database integrity check failed: $integrity_check"
        fi
        
        # Clean old sessions (older than 30 days)
        local cleaned_sessions=$(sqlite3 "$db_file" "DELETE FROM sessions WHERE last_active < datetime('now', '-30 days'); SELECT changes();" 2>/dev/null || echo "0")
        log "Cleaned $cleaned_sessions old sessions"
        
        # Clean old messages (keep last 10000 per session)
        sqlite3 "$db_file" "
        DELETE FROM messages 
        WHERE id NOT IN (
            SELECT id FROM messages 
            ORDER BY timestamp DESC 
            LIMIT 10000
        );" 2>/dev/null || warning "Message cleanup failed"
        log "Cleaned old messages"
        
        # Get database size
        local db_size=$(du -h "$db_file" | cut -f1)
        log "Database size after maintenance: $db_size"
    else
        warning "Database file not found: $db_file"
    fi
}

# System optimization
system_optimization() {
    log "Starting system optimization..."
    
    # Clear system cache (if available)
    if [ -w "/proc/sys/vm/drop_caches" ]; then
        sync
        echo 3 > /proc/sys/vm/drop_caches
        log "Cleared system cache"
    fi
    
    # Restart application to free memory
    if pm2 list | grep -q "whatsapp-api.*online"; then
        local memory_before=$(pm2 jlist | jq -r '.[] | select(.name=="whatsapp-api") | .monit.memory' 2>/dev/null || echo "0")
        local memory_before_mb=$((memory_before / 1024 / 1024))
        
        pm2 restart whatsapp-api
        sleep 10
        
        local memory_after=$(pm2 jlist | jq -r '.[] | select(.name=="whatsapp-api") | .monit.memory' 2>/dev/null || echo "0")
        local memory_after_mb=$((memory_after / 1024 / 1024))
        
        log "Application restarted - Memory: ${memory_before_mb}MB -> ${memory_after_mb}MB"
    fi
    
    # Update package cache
    if command -v apt &> /dev/null; then
        apt update -qq 2>/dev/null || warning "Failed to update package cache"
        log "Updated package cache"
    fi
}

# Security audit
security_audit() {
    log "Starting security audit..."
    
    # Check file permissions
    local incorrect_perms=$(find "$PROJECT_DIR" -type f -not -perm 644 -not -perm 755 2>/dev/null | wc -l)
    if [ "$incorrect_perms" -gt 0 ]; then
        warning "Found $incorrect_perms files with incorrect permissions"
    else
        log "File permissions: OK"
    fi
    
    # Check for suspicious files
    local suspicious_files=$(find "$PROJECT_DIR" -name "*.php" -o -name "*.jsp" -o -name "*.asp" 2>/dev/null | wc -l)
    if [ "$suspicious_files" -gt 0 ]; then
        warning "Found $suspicious_files suspicious files"
    fi
    
    # Check for world-writable files
    local writable_files=$(find "$PROJECT_DIR" -type f -perm -002 2>/dev/null | wc -l)
    if [ "$writable_files" -gt 0 ]; then
        warning "Found $writable_files world-writable files"
    fi
    
    # Check SSL certificate expiry (if using HTTPS)
    if [ -f "/etc/ssl/certs/whatsapp-api.crt" ]; then
        local cert_expiry=$(openssl x509 -enddate -noout -in /etc/ssl/certs/whatsapp-api.crt | cut -d= -f2)
        local expiry_date=$(date -d "$cert_expiry" +%s)
        local current_date=$(date +%s)
        local days_left=$(( (expiry_date - current_date) / 86400 ))
        
        if [ "$days_left" -lt 30 ]; then
            warning "SSL certificate expires in $days_left days"
        else
            log "SSL certificate valid for $days_left days"
        fi
    fi
    
    log "Security audit completed"
}

# Generate maintenance report
generate_report() {
    local report_file="$PROJECT_DIR/maintenance-report-$(date +%Y%m%d).txt"
    
    cat > "$report_file" << EOF
WhatsApp Multi-Session API - Maintenance Report
===============================================
Date: $(date)
Server: $(hostname)

System Information:
- Uptime: $(uptime -p)
- Load Average: $(uptime | awk -F'load average:' '{print $2}')
- Memory Usage: $(free -h | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')
- Disk Usage: $(df -h "$PROJECT_DIR" | tail -1 | awk '{print $5}')

Application Status:
- PM2 Status: $(pm2 jlist | jq -r '.[] | select(.name=="whatsapp-api") | .pm2_env.status' 2>/dev/null || echo "unknown")
- Process Memory: $(pm2 jlist | jq -r '.[] | select(.name=="whatsapp-api") | .monit.memory' 2>/dev/null | awk '{printf "%.1fMB", $1/1024/1024}')
- Process CPU: $(pm2 jlist | jq -r '.[] | select(.name=="whatsapp-api") | .monit.cpu' 2>/dev/null || echo "0")%

Database:
- Size: $(du -h "$PROJECT_DIR/server/database/whatsapp_api.db" 2>/dev/null | cut -f1 || echo "N/A")
- Sessions Count: $(sqlite3 "$PROJECT_DIR/server/database/whatsapp_api.db" "SELECT COUNT(*) FROM sessions;" 2>/dev/null || echo "N/A")
- Messages Count: $(sqlite3 "$PROJECT_DIR/server/database/whatsapp_api.db" "SELECT COUNT(*) FROM messages;" 2>/dev/null || echo "N/A")

Maintenance Tasks Completed:
- Log cleanup
- Backup cleanup
- Temporary file cleanup
- Database maintenance
- System optimization
- Security audit

Next Maintenance: $(date -d "+1 week" +"%Y-%m-%d")
EOF
    
    log "Maintenance report generated: $report_file"
}

# Show maintenance status
show_status() {
    echo "WhatsApp API Maintenance Status"
    echo "==============================="
    echo
    
    # Last maintenance
    if [ -f "$LOG_FILE" ]; then
        local last_maintenance=$(tail -n 100 "$LOG_FILE" | grep "Maintenance completed" | tail -1 | awk '{print $1, $2}')
        echo "Last Maintenance: $last_maintenance"
    else
        echo "Last Maintenance: Never"
    fi
    
    # System status
    echo "System Status:"
    echo "  Uptime: $(uptime -p)"
    echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo "  Memory: $(free -h | grep Mem | awk '{printf "%.1f%% used", $3/$2 * 100.0}')"
    echo "  Disk: $(df -h "$PROJECT_DIR" | tail -1 | awk '{print $5 " used"}')"
    
    # Log sizes
    echo
    echo "Log File Sizes:"
    if [ -d "$PROJECT_DIR/server/logs" ]; then
        du -sh "$PROJECT_DIR/server/logs"/* 2>/dev/null | head -5
    fi
    
    # Backup count
    echo
    if [ -d "$BACKUP_DIR" ]; then
        local backup_count=$(find "$BACKUP_DIR" -name "backup_*" -o -name "auto_backup_*" | wc -l)
        echo "Backups Available: $backup_count"
    else
        echo "Backups Available: 0"
    fi
}

# Schedule maintenance
schedule_maintenance() {
    log "Setting up maintenance schedule..."
    
    # Add cron job for weekly maintenance
    local cron_entry="0 2 * * 0 $PROJECT_DIR/server/maintenance.sh auto"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "maintenance.sh"; then
        log "Maintenance cron job already exists"
    else
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        log "Added weekly maintenance cron job"
    fi
    
    # Add daily health check
    local health_cron="0 */6 * * * $PROJECT_DIR/server/health-check.sh silent"
    if ! crontab -l 2>/dev/null | grep -q "health-check.sh"; then
        (crontab -l 2>/dev/null; echo "$health_cron") | crontab -
        log "Added health check cron job"
    fi
}

# Main function
main() {
    case "${1:-full}" in
        "logs")
            cleanup_logs
            ;;
        "backups")
            cleanup_backups
            ;;
        "temp")
            cleanup_temp_files
            ;;
        "database")
            database_maintenance
            ;;
        "optimize")
            system_optimization
            ;;
        "security")
            security_audit
            ;;
        "auto")
            log "Starting automated maintenance..."
            cleanup_logs
            cleanup_backups
            cleanup_temp_files
            database_maintenance
            system_optimization
            security_audit
            generate_report
            log "Automated maintenance completed"
            ;;
        "full")
            log "Starting full maintenance..."
            cleanup_logs
            cleanup_backups
            cleanup_temp_files
            database_maintenance
            system_optimization
            security_audit
            generate_report
            log "Full maintenance completed"
            ;;
        "status")
            show_status
            ;;
        "schedule")
            schedule_maintenance
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [logs|backups|temp|database|optimize|security|auto|full|status|schedule|help]"
            echo "  logs     - Clean up log files only"
            echo "  backups  - Clean up old backups only"
            echo "  temp     - Clean up temporary files only"
            echo "  database - Database maintenance only"
            echo "  optimize - System optimization only"
            echo "  security - Security audit only"
            echo "  auto     - Automated maintenance (for cron)"
            echo "  full     - Full maintenance (default)"
            echo "  status   - Show maintenance status"
            echo "  schedule - Setup maintenance schedule"
            echo "  help     - Show this help"
            ;;
        *)
            error "Unknown command: $1. Use 'help' for usage information."
            ;;
    esac
}

# Check if running as root (required for some operations)
if [[ $EUID -ne 0 ]] && [[ "$1" != "status" ]] && [[ "$1" != "help" ]]; then
    error "This script must be run as root or with sudo (except 'status' and 'help')"
fi

# Load environment variables
if [ -f "$PROJECT_DIR/server/.env" ]; then
    source "$PROJECT_DIR/server/.env"
fi

# Create necessary directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Run main function
main "$@"