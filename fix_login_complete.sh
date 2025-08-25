#!/bin/bash

# Script completo para arreglar el problema de login después del pull
set -e

echo "🔧 Arreglando problema de login..."

# 1. Verificar y iniciar servidor con PM2
echo "📦 Verificando estado del servidor..."
cd /var/www/whatsapp-api/server

# Detener cualquier proceso existente
sudo -u www-data pm2 stop whatsapp-api || true
sudo -u www-data pm2 delete whatsapp-api || true

# 2. Ejecutar migraciones de base de datos
echo "🗄️ Ejecutando migraciones de base de datos..."
sudo -u www-data node migrations/migrate.js

# 3. Verificar que los archivos del frontend estén en su lugar
echo "📂 Verificando archivos del frontend..."
if [ ! -d "public" ]; then
    mkdir -p public
fi

# Copiar archivos del frontend construido
if [ -d "../dist" ]; then
    cp -r ../dist/* public/
    echo "✅ Archivos del frontend copiados"
else
    echo "⚠️ No se encontró la carpeta dist, construyendo frontend..."
    cd ..
    npm run build
    cd server
    cp -r ../dist/* public/
fi

# 4. Asegurar permisos correctos
echo "🔐 Configurando permisos..."
chown -R www-data:www-data /var/www/whatsapp-api
chmod -R 755 /var/www/whatsapp-api

# 5. Iniciar servidor con PM2
echo "🚀 Iniciando servidor..."
sudo -u www-data pm2 start ecosystem.config.js
sudo -u www-data pm2 save

# 6. Esperar a que el servidor inicie
echo "⏳ Esperando a que el servidor inicie..."
sleep 5

# 7. Verificar funcionamiento
echo "✅ Verificando funcionamiento..."

echo "📊 Estado de PM2:"
sudo -u www-data pm2 status

echo -e "\n🔍 Test de salud del backend:"
curl -s http://localhost:3000/health || echo "❌ Backend no responde"

echo -e "\n🔍 Test de salud a través de Nginx:"
curl -s http://localhost/api/health || echo "❌ API a través de Nginx no responde"

echo -e "\n🔍 Test de login:"
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' || echo "ERROR")

if [[ $LOGIN_RESPONSE == *"token"* ]]; then
    echo "✅ Login funcionando correctamente"
else
    echo "❌ Error en login: $LOGIN_RESPONSE"
fi

echo -e "\n🎉 Configuración completa!"
echo "🔑 Credenciales de login:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📝 Para monitorear logs: sudo -u www-data pm2 logs whatsapp-api"