#!/bin/bash

# Complete database schema fix and server restart
set -e

echo "🔧 Ejecutando arreglo completo de base de datos..."

cd /var/www/whatsapp-api/server

# Paso 1: Detener cualquier proceso PM2 existente
echo "⏹️ Deteniendo procesos PM2..."
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 stop all || true
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 delete all || true

# Paso 2: Verificar esquema actual de la base de datos real
echo "🔍 Verificando esquema actual de whatsapp_api.db..."
echo "Estructura actual de sessions:"
sudo -u whatsapp sqlite3 database/whatsapp_api.db "PRAGMA table_info(sessions);" || echo "Error al leer tabla sessions"

echo -e "\nTablas existentes:"
sudo -u whatsapp sqlite3 database/whatsapp_api.db ".tables" || echo "Error al listar tablas"

# Paso 3: Ejecutar migración usando el sistema de migración existente
echo "📦 Ejecutando migración con el sistema existente..."
sudo -u whatsapp node migrations/migrate.js

# Paso 4: Verificar que la migración se aplicó correctamente
echo "✅ Verificando migración aplicada..."
echo "Nueva estructura de sessions:"
sudo -u whatsapp sqlite3 database/whatsapp_api.db "PRAGMA table_info(sessions);"

echo -e "\nMigraciones aplicadas:"
sudo -u whatsapp sqlite3 database/whatsapp_api.db "SELECT * FROM migrations ORDER BY id;"

echo -e "\nUsuarios en la base de datos:"
sudo -u whatsapp sqlite3 database/whatsapp_api.db "SELECT id, username, role FROM users;"

# Paso 5: Iniciar PM2 con configuración correcta
echo "🚀 Iniciando servidor con PM2..."
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 start ecosystem.config.js --env production
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 save

# Paso 6: Esperar a que el servidor inicie
echo "⏳ Esperando inicio del servidor..."
sleep 10

# Paso 7: Verificar funcionamiento completo
echo "🔍 Verificando funcionamiento..."

echo "📊 Estado de PM2:"
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 status

echo -e "\n🔍 Test de salud del backend:"
if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ Backend funcionando"
    curl -s http://localhost:3000/health | jq .
else
    echo "❌ Backend no responde"
fi

echo -e "\n🔍 Test de login:"
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' 2>/dev/null || echo "ERROR")

if [[ $LOGIN_RESPONSE == *"token"* ]]; then
    echo "✅ Login funcionando correctamente"
    
    # Extraer token y probar endpoints
    TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token' 2>/dev/null)
    if [ "$TOKEN" != "null" ] && [ "$TOKEN" != "" ]; then
        echo -e "\n🔍 Test de sesiones:"
        curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/sessions | jq . || echo "❌ Error en endpoint de sesiones"
        
        echo -e "\n🔍 Test de mensajes:"
        curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/messages | jq . || echo "❌ Error en endpoint de mensajes"
    fi
else
    echo "❌ Error en login: $LOGIN_RESPONSE"
fi

echo -e "\n🎉 Arreglo completo terminado!"
echo "🌐 Aplicación disponible en: http://168.197.49.169/"
echo "🔑 Credenciales: admin / admin123"
echo "📝 Logs: sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 logs whatsapp-api"