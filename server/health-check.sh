#!/bin/bash

# WhatsApp Multi-Session API - Health Check Script
# Comprehensive system health monitoring

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="/var/www/whatsapp-api"
LOG_FILE="/var/log/whatsapp-api-health.log"
ALERT_WEBHOOK=""
EMAIL_ALERT=""

# Health check results
HEALTH_STATUS="OK"
ISSUES=()
WARNINGS=()

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    HEALTH_STATUS="CRITICAL"
    ISSUES+=("$1")
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
    if [ "$HEALTH_STATUS" != "CRITICAL" ]; then
        HEALTH_STATUS="WARNING"
    fi
    WARNINGS+=("$1")
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Check system resources
check_system_resources() {
    log "Checking system resources..."
    
    # Memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    if (( $(echo "$mem_usage > 90" | bc -l) )); then
        error "High memory usage: ${mem_usage}%"
    elif (( $(echo "$mem_usage > 80" | bc -l) )); then
        warning "Memory usage: ${mem_usage}%"
    else
        log "Memory usage: ${mem_usage}% - OK"
    fi
    
    # Disk usage
    local disk_usage=$(df "$PROJECT_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        error "High disk usage: ${disk_usage}%"
    elif [ "$disk_usage" -gt 80 ]; then
        warning "Disk usage: ${disk_usage}%"
    else
        log "Disk usage: ${disk_usage}% - OK"
    fi
    
    # CPU load
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores=$(nproc)
    local cpu_usage=$(echo "scale=1; $cpu_load / $cpu_cores * 100" | bc)
    
    if (( $(echo "$cpu_usage > 90" | bc -l) )); then
        error "High CPU load: ${cpu_usage}%"
    elif (( $(echo "$cpu_usage > 70" | bc -l) )); then
        warning "CPU load: ${cpu_usage}%"
    else
        log "CPU load: ${cpu_usage}% - OK"
    fi
}

# Check application status
check_application() {
    log "Checking application status..."
    
    # Check if PM2 is running
    if ! command -v pm2 &> /dev/null; then
        error "PM2 is not installed"
        return
    fi
    
    # Check PM2 process
    local pm2_status=$(pm2 jlist | jq -r '.[] | select(.name=="whatsapp-api") | .pm2_env.status' 2>/dev/null || echo "not_found")
    
    case "$pm2_status" in
        "online")
            log "PM2 process: online - OK"
            ;;
        "stopped")
            error "PM2 process: stopped"
            ;;
        "errored")
            error "PM2 process: errored"
            ;;
        "not_found")
            error "PM2 process: not found"
            ;;
        *)
            warning "PM2 process: unknown status ($pm2_status)"
            ;;
    esac
    
    # Check memory usage of the process
    if [ "$pm2_status" = "online" ]; then
        local app_memory=$(pm2 jlist | jq -r '.[] | select(.name=="whatsapp-api") | .monit.memory' 2>/dev/null || echo "0")
        local app_memory_mb=$((app_memory / 1024 / 1024))
        
        if [ "$app_memory_mb" -gt 1500 ]; then
            warning "High application memory usage: ${app_memory_mb}MB"
        else
            log "Application memory usage: ${app_memory_mb}MB - OK"
        fi
        
        # Check CPU usage of the process
        local app_cpu=$(pm2 jlist | jq -r '.[] | select(.name=="whatsapp-api") | .monit.cpu' 2>/dev/null || echo "0")
        if [ "$app_cpu" -gt 80 ]; then
            warning "High application CPU usage: ${app_cpu}%"
        else
            log "Application CPU usage: ${app_cpu}% - OK"
        fi
    fi
}

# Check network connectivity
check_network() {
    log "Checking network connectivity..."
    
    # Check if application port is listening
    if netstat -tlnp | grep -q ":3000 "; then
        log "Port 3000: listening - OK"
    else
        error "Port 3000: not listening"
    fi
    
    # Check HTTP response
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health 2>/dev/null || echo "000")
    
    case "$http_status" in
        "200")
            log "HTTP health check: 200 OK"
            ;;
        "000")
            error "HTTP health check: connection failed"
            ;;
        *)
            error "HTTP health check: status $http_status"
            ;;
    esac
    
    # Check response time
    local response_time=$(curl -s -o /dev/null -w "%{time_total}" http://localhost:3000/health 2>/dev/null || echo "999")
    local response_ms=$(echo "$response_time * 1000" | bc)
    
    if (( $(echo "$response_time > 5" | bc -l) )); then
        warning "Slow response time: ${response_ms}ms"
    else
        log "Response time: ${response_ms}ms - OK"
    fi
}

# Check database
check_database() {
    log "Checking database..."
    
    local db_file="$PROJECT_DIR/server/database/whatsapp_api.db"
    
    if [ -f "$db_file" ]; then
        # Check database file permissions
        if [ -r "$db_file" ] && [ -w "$db_file" ]; then
            log "Database file: accessible - OK"
        else
            error "Database file: permission issues"
        fi
        
        # Check database size
        local db_size=$(du -h "$db_file" | cut -f1)
        log "Database size: $db_size"
        
        # Check if database is locked
        if lsof "$db_file" | grep -q "WRITE"; then
            log "Database: active connections - OK"
        else
            warning "Database: no active connections"
        fi
    else
        error "Database file not found: $db_file"
    fi
}

# Check log files
check_logs() {
    log "Checking log files..."
    
    local log_dir="$PROJECT_DIR/server/logs"
    
    if [ -d "$log_dir" ]; then
        # Check for recent errors
        local error_count=$(find "$log_dir" -name "*.log" -mtime -1 -exec grep -c "ERROR" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
        
        if [ "$error_count" -gt 50 ]; then
            warning "High error count in logs: $error_count errors in last 24h"
        elif [ "$error_count" -gt 0 ]; then
            log "Error count: $error_count errors in last 24h"
        else
            log "No errors in recent logs - OK"
        fi
        
        # Check log file sizes
        for logfile in "$log_dir"/*.log; do
            if [ -f "$logfile" ]; then
                local size=$(du -h "$logfile" | cut -f1)
                local size_bytes=$(du -b "$logfile" | cut -f1)
                
                if [ "$size_bytes" -gt 104857600 ]; then  # 100MB
                    warning "Large log file: $(basename "$logfile") - $size"
                fi
            fi
        done
    else
        warning "Log directory not found: $log_dir"
    fi
}

# Check file permissions
check_permissions() {
    log "Checking file permissions..."
    
    if [ -d "$PROJECT_DIR" ]; then
        local owner=$(stat -c "%U:%G" "$PROJECT_DIR")
        if [ "$owner" = "www-data:www-data" ]; then
            log "File ownership: $owner - OK"
        else
            warning "File ownership: $owner (expected www-data:www-data)"
        fi
        
        # Check critical directories
        local dirs=("server" "server/sessions" "server/database" "server/logs" "server/uploads")
        for dir in "${dirs[@]}"; do
            if [ -d "$PROJECT_DIR/$dir" ]; then
                local perms=$(stat -c "%a" "$PROJECT_DIR/$dir")
                if [ "$perms" = "755" ] || [ "$perms" = "775" ]; then
                    log "Directory permissions ($dir): $perms - OK"
                else
                    warning "Directory permissions ($dir): $perms"
                fi
            fi
        done
    else
        error "Project directory not found: $PROJECT_DIR"
    fi
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    # Check Node.js
    if command -v node &> /dev/null; then
        local node_version=$(node -v)
        log "Node.js version: $node_version - OK"
    else
        error "Node.js not found"
    fi
    
    # Check npm packages
    if [ -f "$PROJECT_DIR/server/package.json" ]; then
        cd "$PROJECT_DIR/server"
        if npm list --depth=0 &>/dev/null; then
            log "Server dependencies: OK"
        else
            warning "Server dependencies: some packages missing"
        fi
    fi
    
    # Check Chrome/Chromium for WhatsApp Web
    if command -v google-chrome &> /dev/null || command -v chromium &> /dev/null; then
        log "Chrome/Chromium: available - OK"
    else
        error "Chrome/Chromium not found (required for WhatsApp Web)"
    fi
}

# Send alerts
send_alerts() {
    if [ "$HEALTH_STATUS" != "OK" ]; then
        local alert_message="WhatsApp API Health Check Alert
Status: $HEALTH_STATUS
Server: $(hostname)
Time: $(date)

Issues:
$(printf '%s\n' "${ISSUES[@]}")

Warnings:
$(printf '%s\n' "${WARNINGS[@]}")
"
        
        # Send webhook alert
        if [ -n "$ALERT_WEBHOOK" ]; then
            curl -X POST "$ALERT_WEBHOOK" \
                -H "Content-Type: application/json" \
                -d "{\"text\":\"$alert_message\"}" \
                2>/dev/null || warning "Failed to send webhook alert"
        fi
        
        # Send email alert
        if [ -n "$EMAIL_ALERT" ] && command -v mail &> /dev/null; then
            echo "$alert_message" | mail -s "WhatsApp API Health Alert - $HEALTH_STATUS" "$EMAIL_ALERT" \
                2>/dev/null || warning "Failed to send email alert"
        fi
    fi
}

# Generate health report
generate_report() {
    echo
    echo "============================================"
    echo "WhatsApp Multi-Session API - Health Report"
    echo "============================================"
    echo "Status: $HEALTH_STATUS"
    echo "Time: $(date)"
    echo "Server: $(hostname)"
    echo
    
    if [ ${#ISSUES[@]} -gt 0 ]; then
        echo "Critical Issues:"
        printf '  - %s\n' "${ISSUES[@]}"
        echo
    fi
    
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo "Warnings:"
        printf '  - %s\n' "${WARNINGS[@]}"
        echo
    fi
    
    if [ "$HEALTH_STATUS" = "OK" ]; then
        echo "All systems are running normally."
    fi
    
    echo "============================================"
}

# Main health check
main() {
    case "${1:-full}" in
        "system")
            check_system_resources
            ;;
        "app")
            check_application
            ;;
        "network")
            check_network
            ;;
        "database")
            check_database
            ;;
        "quick")
            check_application
            check_network
            ;;
        "full")
            check_system_resources
            check_application
            check_network
            check_database
            check_logs
            check_permissions
            check_dependencies
            ;;
        "silent")
            check_system_resources &>/dev/null
            check_application &>/dev/null
            check_network &>/dev/null
            exit $([ "$HEALTH_STATUS" = "OK" ] && echo 0 || echo 1)
            ;;
        *)
            echo "Usage: $0 [system|app|network|database|quick|full|silent]"
            echo "  system   - Check system resources only"
            echo "  app      - Check application status only"
            echo "  network  - Check network connectivity only"
            echo "  database - Check database status only"
            echo "  quick    - Quick check (app + network)"
            echo "  full     - Full health check (default)"
            echo "  silent   - Silent check (exit code only)"
            exit 1
            ;;
    esac
    
    if [ "$1" != "silent" ]; then
        generate_report
        send_alerts
    fi
    
    # Exit with appropriate code
    case "$HEALTH_STATUS" in
        "OK") exit 0 ;;
        "WARNING") exit 1 ;;
        "CRITICAL") exit 2 ;;
    esac
}

# Load environment variables
if [ -f "$PROJECT_DIR/server/.env" ]; then
    source "$PROJECT_DIR/server/.env"
fi

# Run main function
main "$@"