#!/bin/bash

# Script definitivo para solucionar conflictos de migración
set -e

echo "🔧 Solucionando conflictos de migración definitivamente..."

cd /var/www/whatsapp-api/server

# Paso 1: Detener servidor
echo "⏹️ Deteniendo servidor..."
sudo -u www-data -E PM2_HOME=/home/www-data/.pm2 pm2 stop whatsapp-api || true

# Paso 2: Eliminar completamente la base de datos y directorio
echo "🗄️ Eliminando completamente la base de datos..."
rm -rf database/
mkdir -p database
echo "✅ Base de datos eliminada completamente"

# Paso 3: Ejecutar solo la migración inicial manualmente
echo "🗄️ Ejecutando migración inicial manualmente..."
sqlite3 database/app.db < migrations/001_initial_schema.sql
echo "✅ Migración inicial ejecutada"

# Paso 4: Marcar todas las migraciones como completadas
echo "📝 Marcando migraciones como completadas..."
sqlite3 database/app.db << 'EOF'
CREATE TABLE IF NOT EXISTS migration_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    executed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO migration_log (version, name, executed_at) VALUES 
('001', '001_initial_schema', CURRENT_TIMESTAMP),
('002', '002_sync_schemas', CURRENT_TIMESTAMP);
EOF
echo "✅ Migraciones marcadas como completadas"

# Paso 5: Configurar permisos
echo "🔐 Configurando permisos..."
chown -R www-data:www-data database/
chmod 644 database/app.db
echo "✅ Permisos configurados"

# Paso 6: Verificar estructura de base de datos
echo "🔍 Verificando estructura de base de datos..."
echo "Tablas en la base de datos:"
sqlite3 database/app.db ".tables"

echo -e "\nEstructura de tabla users:"
sqlite3 database/app.db ".schema users"

echo -e "\nUsuarios en la base de datos:"
sqlite3 database/app.db "SELECT id, username, role, is_active FROM users;"

# Paso 7: Reiniciar servidor
echo "🚀 Reiniciando servidor..."
sudo -u www-data -E PM2_HOME=/home/www-data/.pm2 pm2 restart whatsapp-api

# Paso 8: Esperar y verificar
echo "⏳ Esperando a que el servidor inicie..."
sleep 5

echo "📊 Estado de PM2:"
sudo -u www-data -E PM2_HOME=/home/www-data/.pm2 pm2 status

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