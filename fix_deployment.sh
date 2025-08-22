#!/bin/bash

# Script para resolver todos los problemas de despliegue
set -e

echo "🔧 Iniciando solución completa..."

# 1. Resolver conflicto de Git
echo "📦 Resolviendo conflicto de Git..."
cd /var/www/whatsapp-api
git stash push -m "Local changes before update"
git pull origin main
git stash pop || echo "No hay cambios locales para aplicar"

# 2. Configurar archivo .env
echo "⚙️ Configurando archivo .env..."
cd server
cp .env.example .env

# Configurar variables críticas
cat > .env << EOF
# Server Configuration
NODE_ENV=production
PORT=3000

# Security - CHANGE THIS IN PRODUCTION!
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production-please

# Frontend Configuration
FRONTEND_URL=http://localhost
CORS_ORIGINS=http://localhost,http://localhost:5173,http://127.0.0.1:5173

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
BACKUP_SCHEDULE=0 2 * * *
BACKUP_RETENTION_DAYS=30

# Monitoring
HEALTH_CHECK_INTERVAL=30000

# Production Settings
PM2_INSTANCES=1
PM2_MAX_MEMORY=2048MB
EOF

# 3. Actualizar dependencias del backend
echo "📦 Actualizando dependencias del backend..."
npm install --production

# 4. Copiar archivos del frontend construido
echo "📂 Copiando archivos del frontend..."
mkdir -p public
cp -r ../dist/* public/

# 5. Corregir permisos
echo "🔐 Corrigiendo permisos..."
cd /var/www/whatsapp-api
sudo chown -R whatsapp:whatsapp .
sudo chmod -R 755 .
sudo chmod +x server/*.sh

# 6. Reiniciar servicios
echo "🔄 Reiniciando servicios..."
sudo -u whatsapp pm2 delete whatsapp-api || true
sudo -u whatsapp pm2 start server/ecosystem.config.js

# 7. Verificar Nginx
echo "🌐 Verificando Nginx..."
sudo nginx -t
sudo systemctl reload nginx

# 8. Esperar a que el servidor inicie
echo "⏳ Esperando a que el servidor inicie..."
sleep 5

# 9. Verificar funcionamiento
echo "✅ Verificando funcionamiento..."
curl -s http://localhost/ | head -10
echo ""
curl -s http://localhost/api/health || echo "API health check falló"

echo "🎉 ¡Solución completa aplicada!"
echo "📝 Puedes verificar los logs con: sudo -u whatsapp pm2 logs whatsapp-api"