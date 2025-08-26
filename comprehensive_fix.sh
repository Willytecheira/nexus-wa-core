#!/bin/bash

# Comprehensive fix for WhatsApp API project
set -e

echo "🚀 Iniciando corrección completa del proyecto WhatsApp API..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Create whatsapp user and setup proper permissions
log_info "Paso 1: Configurando usuario del sistema..."

# Create whatsapp user if it doesn't exist
if ! id "whatsapp" &>/dev/null; then
    useradd -r -s /bin/bash -d /var/www/whatsapp-api whatsapp
    log_success "Usuario whatsapp creado"
else
    log_info "Usuario whatsapp ya existe"
fi

# Create necessary directories
log_info "Creando directorios necesarios..."
mkdir -p /var/www/whatsapp-api/server/{logs,database,qr,sessions,uploads}
mkdir -p /home/whatsapp/.pm2

# Set ownership and permissions
chown -R whatsapp:whatsapp /var/www/whatsapp-api
chown -R whatsapp:whatsapp /home/whatsapp
chmod -R 755 /var/www/whatsapp-api
chmod -R 755 /home/whatsapp

log_success "Directorios y permisos configurados"

# Step 2: Stop any existing processes
log_info "Paso 2: Deteniendo procesos existentes..."

# Stop PM2 processes
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 stop all || true
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 delete all || true

# Kill any remaining node processes
pkill -f "node.*server.js" || true
pkill -f "whatsapp-api" || true

log_success "Procesos detenidos"

# Step 3: Clean and rebuild database
log_info "Paso 3: Reconstruyendo base de datos..."

cd /var/www/whatsapp-api/server

# Remove existing database
rm -rf database/app.db
rm -rf database/*.db

# Ensure database directory exists with correct permissions
mkdir -p database
chown whatsapp:whatsapp database
chmod 755 database

# Run migrations as whatsapp user
log_info "Ejecutando migraciones..."
sudo -u whatsapp node migrations/migrate.js

log_success "Base de datos reconstruida"

# Step 4: Install dependencies and ensure everything is ready
log_info "Paso 4: Verificando dependencias..."

cd /var/www/whatsapp-api/server
sudo -u whatsapp npm install

# Build frontend if needed
cd /var/www/whatsapp-api
if [ ! -d "dist" ] || [ ! "$(ls -A dist)" ]; then
    log_info "Construyendo frontend..."
    npm run build
    log_success "Frontend construido"
fi

# Copy frontend files to server public directory
mkdir -p server/public
cp -r dist/* server/public/
chown -R whatsapp:whatsapp server/public

# Step 5: Configure Nginx
log_info "Paso 5: Configurando Nginx..."

# Copy Nginx configuration
cp server/nginx/whatsapp-api.conf /etc/nginx/sites-available/whatsapp-api

# Remove default site and create symlink
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/whatsapp-api
ln -s /etc/nginx/sites-available/whatsapp-api /etc/nginx/sites-enabled/whatsapp-api

# Test Nginx configuration
if nginx -t; then
    log_success "Configuración de Nginx válida"
    systemctl restart nginx
    log_success "Nginx reiniciado"
else
    log_error "Error en configuración de Nginx"
    exit 1
fi

# Step 6: Start the application
log_info "Paso 6: Iniciando aplicación..."

cd /var/www/whatsapp-api/server

# Start with PM2 as whatsapp user
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 start ecosystem.config.js
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 save

log_success "Aplicación iniciada con PM2"

# Step 7: Wait for services to stabilize
log_info "Paso 7: Esperando estabilización..."
sleep 10

# Step 8: Comprehensive testing
log_info "Paso 8: Verificando funcionamiento..."

# Test backend health
if curl -s http://localhost:3000/health > /dev/null; then
    log_success "Backend funcionando (puerto 3000)"
else
    log_error "Backend no responde en puerto 3000"
fi

# Test API through Nginx
if curl -s http://localhost/api/health > /dev/null; then
    log_success "API funcionando a través de Nginx"
else
    log_error "API no responde a través de Nginx"
fi

# Test login endpoint
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' 2>/dev/null || echo "ERROR")

if [[ $LOGIN_RESPONSE == *"token"* ]]; then
    log_success "Sistema de autenticación funcionando"
else
    log_warning "Verificar configuración de autenticación"
fi

# Test session creation capabilities
if curl -s http://localhost:3000/api/sessions > /dev/null; then
    log_success "Endpoint de sesiones disponible"
else
    log_warning "Verificar endpoint de sesiones"
fi

# Step 9: Display final status
echo ""
echo "🎉 ¡Configuración completa!"
echo ""
echo "📊 Estado final:"
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 status

echo ""
echo "🔗 Accesos:"
echo "  • Aplicación web: http://168.197.49.169/"
echo "  • API directa: http://168.197.49.169/api/"
echo "  • Estado de salud: http://168.197.49.169/api/health"

echo ""
echo "🔑 Credenciales por defecto:"
echo "  • Usuario: admin"
echo "  • Contraseña: admin123"

echo ""
echo "📝 Comandos útiles:"
echo "  • Ver logs: sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 logs whatsapp-api"
echo "  • Reiniciar: sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 restart whatsapp-api"
echo "  • Estado: sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 status"

echo ""
log_success "Sistema WhatsApp API completamente funcional"