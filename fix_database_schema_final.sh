#!/bin/bash

# Script final para arreglar el esquema de base de datos y foreign key constraints
set -e

echo "🔧 Arreglando esquema de base de datos definitivamente..."

cd /var/www/whatsapp-api/server

# Paso 1: Detener servidor
echo "⏹️ Deteniendo servidor..."
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 stop whatsapp-api || true

# Paso 2: Hacer backup de la base de datos
echo "💾 Creando backup de la base de datos..."
if [ -f "database/app.db" ]; then
    cp database/app.db database/app.db.backup.$(date +%s)
    echo "✅ Backup creado"
fi

# Paso 3: Ejecutar la nueva migración
echo "📦 Ejecutando migración de corrección de esquema..."
sudo -u whatsapp sqlite3 database/app.db < migrations/002_fix_schema_constraints.sql

# Paso 4: Marcar migración como ejecutada
echo "📝 Marcando migración como ejecutada..."
sudo -u whatsapp sqlite3 database/app.db << 'EOF'
INSERT OR IGNORE INTO migration_log (migration_name, executed_at) VALUES 
('002_fix_schema_constraints', CURRENT_TIMESTAMP);
EOF

# Paso 5: Verificar el esquema actualizado
echo "🔍 Verificando esquema actualizado..."
echo "Estructura de la tabla sessions:"
sudo -u whatsapp sqlite3 database/app.db "PRAGMA table_info(sessions);"

echo -e "\nUsuarios en la base de datos:"
sudo -u whatsapp sqlite3 database/app.db "SELECT id, username, role FROM users;"

echo -e "\nMigraciones aplicadas:"
sudo -u whatsapp sqlite3 database/app.db "SELECT migration_name, executed_at FROM migration_log ORDER BY executed_at;"

# Paso 6: Reiniciar servidor
echo "🚀 Reiniciando servidor..."
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 start whatsapp-api

# Paso 7: Esperar y verificar
echo "⏳ Esperando a que el servidor inicie..."
sleep 5

echo "📊 Estado del servidor:"
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 status

echo "✅ Esquema de base de datos corregido!"
echo "🎯 Los mensajes ahora deberían enviarse Y guardarse correctamente en la base de datos"