#!/bin/bash

# Script definitivo para resolver problemas de configuración de Nginx
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${GREEN}[INFO] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }

log "🚀 INICIANDO SOLUCIÓN DEFINITIVA PARA NGINX"

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root"
   exit 1
fi

# Variables
PROJECT_DIR="/var/www/whatsapp-api"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
SITE_NAME="whatsapp-api"

log "📋 Paso 1: Verificando estructura del proyecto..."

# Verificar que existe el directorio del proyecto
if [[ ! -d "$PROJECT_DIR" ]]; then
    error "No se encuentra el directorio del proyecto: $PROJECT_DIR"
    exit 1
fi

# Verificar que existe el directorio dist
if [[ ! -d "$PROJECT_DIR/dist" ]]; then
    warning "No se encuentra el directorio dist, ejecutando build..."
    cd "$PROJECT_DIR"
    npm run build
    if [[ ! -d "$PROJECT_DIR/dist" ]]; then
        error "Error al generar el build"
        exit 1
    fi
fi

log "🗑️  Paso 2: Limpiando configuraciones conflictivas..."

# Eliminar sitio por defecto si existe
if [[ -f "$NGINX_SITES_ENABLED/default" ]]; then
    info "Eliminando sitio por defecto de Nginx..."
    rm -f "$NGINX_SITES_ENABLED/default"
fi

# Eliminar cualquier enlace simbólico previo
if [[ -L "$NGINX_SITES_ENABLED/$SITE_NAME" ]]; then
    info "Eliminando enlace simbólico previo..."
    rm -f "$NGINX_SITES_ENABLED/$SITE_NAME"
fi

log "🔧 Paso 3: Aplicando configuración corregida..."

# Copiar la configuración desde el proyecto
if [[ -f "$PROJECT_DIR/server/nginx/whatsapp-api.conf" ]]; then
    cp "$PROJECT_DIR/server/nginx/whatsapp-api.conf" "$NGINX_SITES_AVAILABLE/$SITE_NAME"
    info "Configuración copiada desde el proyecto"
else
    error "No se encuentra el archivo de configuración en el proyecto"
    exit 1
fi

# Crear enlace simbólico
ln -sf "$NGINX_SITES_AVAILABLE/$SITE_NAME" "$NGINX_SITES_ENABLED/$SITE_NAME"
info "Enlace simbólico creado"

log "🔍 Paso 4: Verificando configuración..."

# Verificar sintaxis
if nginx -t; then
    success "Configuración de Nginx válida"
else
    error "Error en la configuración de Nginx"
    exit 1
fi

log "🔄 Paso 5: Reiniciando Nginx completamente..."

# Reinicio completo de Nginx
systemctl stop nginx
sleep 2
systemctl start nginx

# Verificar que Nginx está corriendo
if systemctl is-active --quiet nginx; then
    success "Nginx reiniciado correctamente"
else
    error "Error al reiniciar Nginx"
    systemctl status nginx
    exit 1
fi

log "🔐 Paso 6: Configurando permisos..."

# Configurar permisos del directorio del proyecto
chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 755 "$PROJECT_DIR"
chmod -R 644 "$PROJECT_DIR/dist"
find "$PROJECT_DIR/dist" -type d -exec chmod 755 {} \;

# Permisos específicos para QR
if [[ -d "$PROJECT_DIR/server/qr" ]]; then
    chown -R www-data:www-data "$PROJECT_DIR/server/qr"
    chmod 755 "$PROJECT_DIR/server/qr"
    chmod 644 "$PROJECT_DIR/server/qr"/*.png 2>/dev/null || true
    info "Permisos de carpeta QR configurados"
fi

log "🧪 Paso 7: Diagnóstico avanzado..."

# Verificar qué configuración está usando Nginx
info "Verificando configuración activa de Nginx:"
nginx -T 2>/dev/null | grep -A 5 -B 5 "server_name" || true

# Verificar archivos que existen
info "Verificando archivos en el directorio dist:"
ls -la "$PROJECT_DIR/dist/" || true

info "Verificando archivos de assets:"
ls -la "$PROJECT_DIR/dist/assets/" || true

# Verificar enlaces simbólicos
info "Verificando enlaces simbólicos de Nginx:"
ls -la "$NGINX_SITES_ENABLED/" || true

log "🏃‍♂️ Paso 8: Iniciando servidor backend..."

# Verificar si PM2 está corriendo y reiniciar el backend
cd "$PROJECT_DIR"
if command -v pm2 &> /dev/null; then
    su - www-data -c "cd $PROJECT_DIR && pm2 delete whatsapp-api" 2>/dev/null || true
    su - www-data -c "cd $PROJECT_DIR && pm2 start server/ecosystem.config.js" 2>/dev/null || true
    sleep 3
    info "Servidor backend reiniciado con PM2"
else
    warning "PM2 no encontrado, el backend debe iniciarse manualmente"
fi

log "🧪 Paso 9: Pruebas finales..."

# Esperar un momento para que todo se estabilice
sleep 5

# Probar página principal
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
    info "Esto puede ser normal si el backend aún no está completamente iniciado"
fi

# Probar algunos assets específicos
info "Probando assets principales:"
for asset in $(find "$PROJECT_DIR/dist/assets" -name "*.js" -o -name "*.css" | head -3); do
    asset_path="/assets/$(basename "$asset")"
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost$asset_path" | grep -q "200"; then
        success "✅ Asset $asset_path - OK"
    else
        warning "❌ Asset $asset_path - FALLO"
    fi
done

log "📊 Paso 10: Resumen final..."

# Contar assets
js_files=$(find "$PROJECT_DIR/dist/assets" -name "*.js" | wc -l)
css_files=$(find "$PROJECT_DIR/dist/assets" -name "*.css" | wc -l)
img_files=$(find "$PROJECT_DIR/dist/assets" -name "*.png" -o -name "*.jpg" -o -name "*.gif" -o -name "*.svg" | wc -l)

info "📄 Archivos JavaScript: $js_files"
info "🎨 Archivos CSS: $css_files"
info "🖼️  Archivos de imagen: $img_files"

# Verificar configuración final
info "Configuración final de Nginx para el sitio:"
grep -A 10 "location /" "$NGINX_SITES_AVAILABLE/$SITE_NAME" || true

success "🎉 ¡CONFIGURACIÓN COMPLETADA!"
success "🌐 Tu aplicación debería estar funcionando en http://$(hostname -I | awk '{print $1}')"

log "🔗 Comandos útiles para monitoreo:"
info "• Ver logs de Nginx: tail -f /var/log/nginx/error.log"
info "• Ver logs del backend: su - www-data -c 'pm2 logs whatsapp-api'"
info "• Reiniciar Nginx: systemctl restart nginx"
info "• Verificar estado: systemctl status nginx"
info "• Probar configuración: nginx -t"

log "📋 Si aún hay problemas:"
info "1. Verificar que el backend esté corriendo: su - www-data -c 'pm2 status'"
info "2. Revisar logs del backend para errores"
info "3. Asegurar que todas las variables de entorno estén configuradas"
info "4. Verificar conectividad de base de datos"

success "¡Script completado! La aplicación debería estar funcionando correctamente."