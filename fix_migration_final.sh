#!/bin/bash

# Script final para arreglar migraciones completamente
set -e

echo "🔧 Ejecutando plan de corrección definitiva de migraciones..."

cd /var/www/whatsapp-api/server

# Paso 1: Detener servidor completamente
echo "⏹️ Deteniendo servidor..."
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 stop whatsapp-api || true
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 delete whatsapp-api || true

# Paso 2: Limpieza completa de base de datos
echo "🗄️ Limpieza completa de base de datos..."
rm -rf database/
mkdir -p database
chown whatsapp:whatsapp database/

# Paso 3: Ejecutar solo esquema inicial
echo "📦 Ejecutando esquema inicial..."
sudo -u whatsapp sqlite3 database/app.db < migrations/001_initial_schema.sql
echo "✅ Esquema inicial ejecutado"

# Paso 4: Configurar permisos
echo "🔐 Configurando permisos..."
chown whatsapp:whatsapp database/app.db
chmod 644 database/app.db

# Paso 5: Marcar migración como completada
echo "📝 Marcando migración como completada..."
sudo -u whatsapp sqlite3 database/app.db << 'EOF'
CREATE TABLE IF NOT EXISTS migration_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    migration_name VARCHAR(255) NOT NULL UNIQUE,
    executed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO migration_log (migration_name, executed_at) VALUES 
('001_initial_schema', CURRENT_TIMESTAMP);
EOF
echo "✅ Migración marcada como completada"

# Paso 6: Verificar estructura
echo "🔍 Verificando estructura de base de datos..."
echo "Tablas creadas:"
sudo -u whatsapp sqlite3 database/app.db ".tables"

echo -e "\nUsuarios en la base de datos:"
sudo -u whatsapp sqlite3 database/app.db "SELECT id, username, role, is_active FROM users;" || echo "Tabla users vacía"

echo -e "\nMigraciones registradas:"
sudo -u whatsapp sqlite3 database/app.db "SELECT migration_name, executed_at FROM migration_log;"

echo "✅ Base de datos preparada correctamente"
echo "🚀 Ahora puedes continuar con: ./comprehensive_fix.sh"