#!/bin/bash

# Script completo para arreglar las migraciones y configuración final
set -e

echo "🔧 Arreglando migraciones y configuración final..."

cd /var/www/whatsapp-api/server

# Paso 1: Detener servidor actual
echo "⏹️ Deteniendo servidor actual..."
sudo -u www-data -E PM2_HOME=/home/www-data/.pm2 pm2 stop whatsapp-api || true

# Paso 2: Eliminar base de datos conflictiva
echo "🗄️ Eliminando base de datos conflictiva..."
rm -f database/app.db
echo "✅ Base de datos eliminada"

# Paso 3: Ejecutar migraciones desde cero
echo "🗄️ Ejecutando migraciones desde cero..."
sudo -u www-data -E PM2_HOME=/home/www-data/.pm2 node migrations/migrate.js

# Paso 4: Reiniciar servidor
echo "🚀 Reiniciando servidor..."
sudo -u www-data -E PM2_HOME=/home/www-data/.pm2 pm2 restart whatsapp-api

# Paso 5: Esperar a que inicie
echo "⏳ Esperando a que el servidor inicie..."
sleep 5

# Paso 6: Verificar funcionamiento
echo "✅ Verificando funcionamiento..."

echo "📊 Estado de PM2:"
sudo -u www-data -E PM2_HOME=/home/www-data/.pm2 pm2 status

echo -e "\n🔍 Test de salud del backend directo:"
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
    echo "Intentando con endpoint directo..."
    LOGIN_RESPONSE2=$(curl -s -X POST http://localhost:3000/auth/login \
      -H "Content-Type: application/json" \
      -d '{"username":"admin","password":"admin123"}' || echo "ERROR")
    
    if [[ $LOGIN_RESPONSE2 == *"token"* ]]; then
        echo "✅ Login funcionando en endpoint directo (sin /api)"
    else
        echo "❌ Error en ambos endpoints de login"
    fi
fi

echo -e "\n🎉 Configuración completada!"
echo "🔑 Credenciales de login:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "🌐 Accede a tu aplicación en: http://168.197.49.169/"
echo "📝 Para monitorear logs: sudo -u www-data -E PM2_HOME=/home/www-data/.pm2 pm2 logs whatsapp-api"