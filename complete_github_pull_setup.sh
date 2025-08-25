#!/bin/bash

# Script completo para hacer pull del repositorio y configurar todo desde cero
set -e

echo "🔄 Iniciando pull completo del repositorio GitHub..."

# Paso 1: Backup del archivo .env actual
echo "💾 Haciendo backup del archivo .env actual..."
cd /var/www/whatsapp-api/server
if [ -f ".env" ]; then
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Backup del .env creado"
fi

# Paso 2: Detener servicios actuales
echo "⏹️ Deteniendo servicios actuales..."
sudo -u www-data pm2 stop whatsapp-api || true
sudo -u www-data pm2 delete whatsapp-api || true

# Paso 3: Hacer pull completo del repositorio
echo "📦 Haciendo pull completo del repositorio..."
cd /var/www/whatsapp-api

# Limpiar cualquier cambio local
git stash push -m "Backup antes del pull completo" || true

# Hacer fetch y reset completo
git fetch origin
git reset --hard origin/main

echo "✅ Pull completo realizado"

# Paso 4: Restaurar configuración del servidor
echo "⚙️ Restaurando configuración del servidor..."
cd server

# Restaurar .env si existe backup
if [ -f ".env.backup.*" ]; then
    LATEST_BACKUP=$(ls -t .env.backup.* | head -1)
    cp "$LATEST_BACKUP" .env
    echo "✅ Archivo .env restaurado desde backup"
else
    # Crear .env básico si no existe
    cat > .env << 'EOF'
# Server Configuration
NODE_ENV=production
PORT=3000

# Security - Secure JWT Secret for production
JWT_SECRET=a8f5f167f44f4964e6c998dee827110c00226a8a8b4f1a9c1e1c1e4ef3a2a4d8b8e5e8b8f4c9e7f5c1e1c1e4e8b8f4c9e7f5

# Frontend Configuration
FRONTEND_URL=http://168.197.49.169
CORS_ORIGINS=http://168.197.49.169,http://localhost,http://localhost:5173,http://127.0.0.1:5173

# Database Configuration (if using external database)
# DATABASE_URL=postgresql://user:password@localhost:5432/whatsapp_api

# Logging
LOG_LEVEL=info

# WhatsApp Configuration
WHATSAPP_SESSION_TIMEOUT=300000
WHATSAPP_MAX_SESSIONS=50

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# File Upload
MAX_FILE_SIZE=10485760
UPLOAD_PATH=./uploads

# Backup Configuration
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION_DAYS=30

# Monitoring
HEALTH_CHECK_INTERVAL=30000

# Production Settings
PM2_INSTANCES=1
PM2_MAX_MEMORY=2048MB
EOF
    echo "✅ Archivo .env creado"
fi

# Paso 5: Instalar dependencias y construir
echo "📦 Instalando dependencias del frontend..."
cd /var/www/whatsapp-api
npm install

echo "🔨 Construyendo frontend..."
npm run build

echo "📦 Instalando dependencias del backend..."
cd server
npm install --production

# Paso 6: Preparar directorios y copiar archivos
echo "📁 Preparando directorios..."
mkdir -p public logs qr sessions uploads database

echo "📂 Copiando archivos del frontend construido..."
cp -r ../dist/* public/

# Paso 7: Configurar permisos
echo "🔐 Configurando permisos..."
cd /var/www/whatsapp-api
chown -R www-data:www-data .
chmod -R 755 .
chmod +x *.sh server/*.sh

# Paso 8: Ejecutar el script de fix login (ahora disponible desde GitHub)
echo "🔧 Ejecutando script de fix de login..."
if [ -f "fix_login_complete.sh" ]; then
    chmod +x fix_login_complete.sh
    ./fix_login_complete.sh
else
    echo "❌ Script fix_login_complete.sh no encontrado en el repositorio"
    echo "Intentando iniciar servidor manualmente..."
    
    cd server
    # Ejecutar migraciones
    sudo -u www-data node migrations/migrate.js || true
    
    # Iniciar servidor
    sudo -u www-data pm2 start ecosystem.config.js
    sudo -u www-data pm2 save
    
    echo "⏳ Esperando a que el servidor inicie..."
    sleep 5
    
    # Verificar funcionamiento
    echo "🔍 Verificando funcionamiento..."
    curl -s http://localhost:3000/health || echo "❌ Backend no responde"
    curl -s http://localhost/api/health || echo "❌ API a través de Nginx no responde"
fi

echo -e "\n🎉 ¡Setup completo desde GitHub realizado!"
echo "🔑 Credenciales de login por defecto:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "🌐 Accede a tu aplicación en: http://168.197.49.169/"
echo "📝 Para monitorear logs: sudo -u www-data pm2 logs whatsapp-api"
echo "📊 Para ver estado: sudo -u www-data pm2 status"