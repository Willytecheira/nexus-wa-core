#!/bin/bash

# Script para solucionar definitivamente los problemas de assets y Nginx
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función de logging con timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    log "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    log "${YELLOW}[WARNING] $1${NC}"
}

info() {
    log "${BLUE}[INFO] $1${NC}"
}

success() {
    log "${GREEN}[SUCCESS] $1${NC}"
}

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root (sudo)"
fi

log "🚀 INICIANDO SOLUCIÓN DEFINITIVA PARA NGINX Y ASSETS"

# 1. Verificar estructura del proyecto
log "📋 Verificando estructura del proyecto..."
PROJECT_DIR="/var/www/whatsapp-api"
if [[ ! -d "$PROJECT_DIR" ]]; then
    error "Directorio del proyecto no encontrado: $PROJECT_DIR"
fi

cd "$PROJECT_DIR"

# Verificar que existe el directorio dist
if [[ ! -d "dist" ]]; then
    warning "Directorio dist no encontrado. Construyendo el frontend..."
    npm run build || error "Error al construir el frontend"
fi

# Verificar que existen los assets
log "📁 Verificando archivos de assets..."
ASSETS_COUNT=$(find dist -name "*.js" -o -name "*.css" -o -name "*.png" -o -name "*.jpg" -o -name "*.svg" | wc -l)
info "Encontrados $ASSETS_COUNT archivos de assets"

# 2. Backup de configuración actual
log "💾 Creando backup de la configuración actual..."
BACKUP_FILE="/etc/nginx/sites-available/whatsapp-api.backup.$(date +%Y%m%d_%H%M%S)"
if [[ -f "/etc/nginx/sites-available/whatsapp-api" ]]; then
    cp "/etc/nginx/sites-available/whatsapp-api" "$BACKUP_FILE"
    info "Backup creado: $BACKUP_FILE"
fi

# 3. Verificar y corregir configuración de Nginx
log "🔧 Aplicando configuración corregida de Nginx..."
if [[ -f "server/nginx/whatsapp-api.conf" ]]; then
    # Copiar la configuración corregida
    cp "server/nginx/whatsapp-api.conf" "/etc/nginx/sites-available/whatsapp-api"
    
    # Verificar sintaxis
    log "🔍 Verificando sintaxis de Nginx..."
    if nginx -t; then
        success "Configuración de Nginx válida"
    else
        error "Error en la configuración de Nginx"
    fi
    
    # Habilitar el sitio si no está habilitado
    if [[ ! -L "/etc/nginx/sites-enabled/whatsapp-api" ]]; then
        ln -sf "/etc/nginx/sites-available/whatsapp-api" "/etc/nginx/sites-enabled/whatsapp-api"
        info "Sitio habilitado en Nginx"
    fi
    
    # Deshabilitar sitio por defecto si existe
    if [[ -L "/etc/nginx/sites-enabled/default" ]]; then
        rm -f "/etc/nginx/sites-enabled/default"
        info "Sitio por defecto deshabilitado"
    fi
else
    error "Archivo de configuración no encontrado: server/nginx/whatsapp-api.conf"
fi

# 4. Configurar permisos correctos
log "🔐 Configurando permisos..."
chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 755 "$PROJECT_DIR"
chmod -R 644 "$PROJECT_DIR/dist"
find "$PROJECT_DIR/dist" -type d -exec chmod 755 {} \;

# Permisos especiales para QR
if [[ -d "server/qr" ]]; then
    chmod 755 server/qr
    chmod 644 server/qr/* 2>/dev/null || true
    info "Permisos de carpeta QR configurados"
fi

# 5. Recargar Nginx
log "🔄 Recargando Nginx..."
systemctl reload nginx || error "Error al recargar Nginx"
success "Nginx recargado correctamente"

# 6. Verificar que Nginx está activo
log "🔍 Verificando estado de Nginx..."
if systemctl is-active --quiet nginx; then
    success "Nginx está activo y ejecutándose"
else
    error "Nginx no está ejecutándose"
fi

# 7. Probar endpoints críticos
log "🧪 Probando endpoints..."

# Probar la página principal
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
    success "✅ Página principal (/) - OK"
else
    warning "❌ Página principal (/) - FALLO"
fi

# Probar health check
if curl -s -o /dev/null -w "%{http_code}" http://localhost/api/health | grep -q "200"; then
    success "✅ Health check (/api/health) - OK"
else
    warning "❌ Health check (/api/health) - FALLO"
fi

# Probar assets específicos
log "🎨 Probando archivos de assets..."
for asset in $(find dist -name "*.css" -o -name "*.js" | head -5); do
    asset_path="/${asset}"
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost$asset_path" | grep -q "200"; then
        success "✅ Asset $asset - OK"
    else
        warning "❌ Asset $asset - FALLO"
    fi
done

# 8. Resumen de assets
log "📊 Resumen de assets encontrados:"
JS_COUNT=$(find dist -name "*.js" | wc -l)
CSS_COUNT=$(find dist -name "*.css" | wc -l)
IMG_COUNT=$(find dist -name "*.png" -o -name "*.jpg" -o -name "*.svg" -o -name "*.ico" | wc -l)

info "📄 Archivos JavaScript: $JS_COUNT"
info "🎨 Archivos CSS: $CSS_COUNT"
info "🖼️  Archivos de imagen: $IMG_COUNT"

# 9. Verificar logs de error recientes
log "📝 Analizando logs de error de Nginx..."
if [[ -f "/var/log/nginx/error.log" ]]; then
    RECENT_ERRORS=$(tail -20 /var/log/nginx/error.log | grep -c "$(date +%Y/%m/%d)" || echo "0")
    if [[ $RECENT_ERRORS -gt 0 ]]; then
        warning "Se encontraron $RECENT_ERRORS errores recientes en Nginx"
        info "Últimos errores:"
        tail -10 /var/log/nginx/error.log | grep "$(date +%Y/%m/%d)" || true
    else
        success "No se encontraron errores recientes en Nginx"
    fi
fi

# 10. Crear script de monitoreo
log "📈 Creando script de monitoreo de assets..."
cat > monitor_assets.sh << 'EOF'
#!/bin/bash
echo "🔍 Monitoreando disponibilidad de assets..."
echo "Timestamp: $(date)"
echo "----------------------------------------"

# Probar endpoints principales
for endpoint in "/" "/api/health"; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost$endpoint")
    if [[ $status == "200" ]]; then
        echo "✅ $endpoint - OK ($status)"
    else
        echo "❌ $endpoint - FALLO ($status)"
    fi
done

# Probar algunos assets
echo "----------------------------------------"
echo "📄 Probando assets principales:"
for asset in $(find /var/www/whatsapp-api/dist -name "*.css" -o -name "*.js" | head -3); do
    asset_path="/${asset#/var/www/whatsapp-api/dist/}"
    status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost$asset_path")
    if [[ $status == "200" ]]; then
        echo "✅ $asset_path - OK ($status)"
    else
        echo "❌ $asset_path - FALLO ($status)"
    fi
done
echo "----------------------------------------"
EOF

chmod +x monitor_assets.sh
info "Script de monitoreo creado: ./monitor_assets.sh"

# 11. Información útil para debugging
log "🛠️  Comandos útiles para monitoreo:"
info "• Verificar estado de Nginx: systemctl status nginx"
info "• Ver logs de Nginx: tail -f /var/log/nginx/error.log"
info "• Probar configuración: nginx -t"
info "• Recargar Nginx: systemctl reload nginx"
info "• Monitorear assets: ./monitor_assets.sh"

# 12. Test final automatizado
log "🎯 Ejecutando test final automatizado..."
./monitor_assets.sh

success "🎉 ¡CONFIGURACIÓN COMPLETADA!"
success "🌐 Tu aplicación debería estar funcionando correctamente en http://$(hostname -I | awk '{print $1}')"
success "📱 Ahora puedes acceder a la interfaz web para gestionar sesiones de WhatsApp"

log "🔗 Próximos pasos sugeridos:"
info "1. Verificar que puedes acceder a la interfaz web"
info "2. Intentar crear una nueva sesión de WhatsApp"
info "3. Verificar que el QR code se muestra correctamente"
info "4. Monitorear los logs si encuentras algún problema"