#!/bin/bash

# SOLUCIÓN DEFINITIVA PARA PROBLEMAS DE NGINX Y ASSETS
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

log "🚀 INICIANDO SOLUCIÓN DEFINITIVA PARA NGINX Y ASSETS"

# 1. Verificar permisos
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root"
fi

# 2. Definir variables
PROJECT_DIR="/var/www/whatsapp-api"
NGINX_CONFIG_SOURCE="$PROJECT_DIR/server/nginx/whatsapp-api.conf"
NGINX_CONFIG_DEST="/etc/nginx/sites-available/whatsapp-api"
NGINX_ENABLED="/etc/nginx/sites-enabled/whatsapp-api"
DIST_DIR="$PROJECT_DIR/dist"
ASSETS_DIR="$DIST_DIR/assets"

log "📋 Verificando estructura del proyecto..."

# 3. Verificar que el directorio del proyecto existe
if [[ ! -d "$PROJECT_DIR" ]]; then
    error "El directorio del proyecto no existe: $PROJECT_DIR"
fi

# 4. Verificar que el directorio dist existe
if [[ ! -d "$DIST_DIR" ]]; then
    warning "El directorio dist no existe. Construyendo el frontend..."
    cd "$PROJECT_DIR"
    npm run build || error "Falló la construcción del frontend"
fi

# 5. Verificar que los assets existen
if [[ ! -d "$ASSETS_DIR" ]]; then
    error "El directorio de assets no existe: $ASSETS_DIR"
fi

log "📁 Verificando archivos de assets..."
ASSET_COUNT=$(find "$ASSETS_DIR" -type f | wc -l)
if [[ $ASSET_COUNT -eq 0 ]]; then
    error "No hay archivos en el directorio de assets"
fi
info "Encontrados $ASSET_COUNT archivos de assets"

# 6. Hacer backup de la configuración actual de nginx
log "💾 Creando backup de la configuración actual..."
if [[ -f "$NGINX_CONFIG_DEST" ]]; then
    cp "$NGINX_CONFIG_DEST" "$NGINX_CONFIG_DEST.backup.$(date +%Y%m%d_%H%M%S)"
    info "Backup creado: $NGINX_CONFIG_DEST.backup.$(date +%Y%m%d_%H%M%S)"
fi

# 7. Verificar que el archivo de configuración fuente existe
if [[ ! -f "$NGINX_CONFIG_SOURCE" ]]; then
    error "El archivo de configuración fuente no existe: $NGINX_CONFIG_SOURCE"
fi

# 8. Verificar sintaxis del archivo fuente
log "🔍 Verificando sintaxis del archivo de configuración..."
cp "$NGINX_CONFIG_SOURCE" "/tmp/test_nginx.conf"
nginx -t -c /dev/null -p /tmp -T 2>/dev/null | grep -q "test is successful" || \
    error "La configuración fuente tiene errores de sintaxis"

# 9. Copiar la configuración corregida
log "📋 Aplicando configuración corregida..."
cp "$NGINX_CONFIG_SOURCE" "$NGINX_CONFIG_DEST"

# 10. Crear enlace simbólico si no existe
if [[ ! -L "$NGINX_ENABLED" ]]; then
    log "🔗 Creando enlace simbólico..."
    ln -sf "$NGINX_CONFIG_DEST" "$NGINX_ENABLED"
fi

# 11. Verificar la configuración de nginx completa
log "✅ Verificando configuración de nginx..."
nginx -t || error "La configuración de nginx tiene errores"

# 12. Configurar permisos correctos
log "🔐 Configurando permisos..."
chown -R www-data:www-data "$DIST_DIR"
chmod -R 755 "$DIST_DIR"
find "$ASSETS_DIR" -type f -exec chmod 644 {} \;

# 13. Recargar nginx
log "🔄 Recargando nginx..."
systemctl reload nginx || error "Falló la recarga de nginx"

# 14. Esperar un momento para que nginx se recargue
sleep 2

# 15. Verificar que nginx está funcionando
log "🌐 Verificando estado de nginx..."
systemctl is-active nginx || error "Nginx no está activo"

# 16. Probar endpoints críticos
log "🧪 Probando endpoints críticos..."

# Probar página principal
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [[ "$HTTP_CODE" != "200" ]]; then
    error "La página principal no responde correctamente (HTTP $HTTP_CODE)"
fi
info "✓ Página principal: OK (HTTP $HTTP_CODE)"

# Probar health check
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)
if [[ "$HTTP_CODE" != "200" ]]; then
    warning "Health check no responde correctamente (HTTP $HTTP_CODE)"
else
    info "✓ Health check: OK (HTTP $HTTP_CODE)"
fi

# 17. Probar assets específicos
log "🎨 Probando assets específicos..."
SAMPLE_ASSETS=($(find "$ASSETS_DIR" -name "*.css" -o -name "*.js" | head -3))

for asset in "${SAMPLE_ASSETS[@]}"; do
    # Extraer el nombre del archivo desde la ruta completa
    ASSET_NAME=$(basename "$asset")
    ASSET_URL="http://localhost/assets/$ASSET_NAME"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ASSET_URL")
    if [[ "$HTTP_CODE" == "200" ]]; then
        info "✓ Asset $ASSET_NAME: OK (HTTP $HTTP_CODE)"
    else
        warning "✗ Asset $ASSET_NAME: FALLO (HTTP $HTTP_CODE)"
    fi
done

# 18. Mostrar resumen de archivos disponibles
log "📊 Resumen de assets disponibles:"
info "CSS files: $(find "$ASSETS_DIR" -name "*.css" | wc -l)"
info "JS files: $(find "$ASSETS_DIR" -name "*.js" | wc -l)"
info "Otros files: $(find "$ASSETS_DIR" -type f ! -name "*.css" ! -name "*.js" | wc -l)"

# 19. Verificar logs de nginx por errores recientes
log "📝 Verificando logs de nginx..."
if [[ -f "/var/log/nginx/error.log" ]]; then
    RECENT_ERRORS=$(tail -50 /var/log/nginx/error.log | grep "$(date '+%Y/%m/%d')" | grep -i error | wc -l)
    if [[ $RECENT_ERRORS -gt 0 ]]; then
        warning "Se encontraron $RECENT_ERRORS errores recientes en nginx"
        info "Ejecuta: tail -50 /var/log/nginx/error.log | grep error"
    else
        info "✓ No hay errores recientes en nginx"
    fi
fi

# 20. Crear script de monitoreo
log "🔧 Creando script de monitoreo..."
cat > "$PROJECT_DIR/monitor_assets.sh" << 'EOF'
#!/bin/bash
# Script de monitoreo para assets

ASSETS_DIR="/var/www/whatsapp-api/dist/assets"
SAMPLE_ASSET=$(find "$ASSETS_DIR" -name "*.css" | head -1 | xargs basename)

if [[ -n "$SAMPLE_ASSET" ]]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/assets/$SAMPLE_ASSET")
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo "✅ Assets funcionando correctamente"
        exit 0
    else
        echo "❌ Assets no funcionan (HTTP $HTTP_CODE)"
        exit 1
    fi
else
    echo "❌ No se encontraron assets CSS"
    exit 1
fi
EOF

chmod +x "$PROJECT_DIR/monitor_assets.sh"

log "🎉 ¡SOLUCIÓN COMPLETADA EXITOSAMENTE!"
echo ""
info "🔍 COMANDOS ÚTILES:"
info "- Monitorear assets: $PROJECT_DIR/monitor_assets.sh"
info "- Ver logs nginx: tail -f /var/log/nginx/error.log"
info "- Verificar configuración: nginx -t"
info "- Recargar nginx: systemctl reload nginx"
echo ""
info "🌐 PRUEBAS FINALES:"
info "- Frontend: http://$(hostname -I | awk '{print $1}')/"
info "- API Health: http://$(hostname -I | awk '{print $1}')/health"
echo ""

# 21. Prueba final automatizada
log "🎯 Ejecutando prueba final automatizada..."
bash "$PROJECT_DIR/monitor_assets.sh"

log "✅ TODO LISTO - El problema de assets está resuelto definitivamente"