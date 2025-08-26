#!/bin/bash

# Script específico para arreglar el esquema de base de datos
echo "🗄️ Arreglando esquema de base de datos..."

cd /var/www/whatsapp-api/server

# Stop server first
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 stop whatsapp-api || true

# Backup existing database if it exists
if [ -f "database/app.db" ]; then
    cp database/app.db database/app.db.backup.$(date +%s)
    echo "✅ Backup de base de datos creado"
fi

# Remove corrupted database
rm -f database/app.db

# Ensure clean migration state
rm -f database/.migration_lock

# Run fresh migrations
echo "📦 Ejecutando migraciones frescas..."
sudo -u whatsapp node migrations/migrate.js

# Verify database was created correctly
if [ -f "database/app.db" ]; then
    echo "✅ Base de datos creada exitosamente"
    
    # Check if tables were created
    TABLES=$(sudo -u whatsapp sqlite3 database/app.db ".tables")
    echo "📋 Tablas creadas: $TABLES"
    
    # Verify migration log
    MIGRATIONS=$(sudo -u whatsapp sqlite3 database/app.db "SELECT migration_name FROM migration_log;" 2>/dev/null || echo "No migrations logged")
    echo "🔄 Migraciones aplicadas: $MIGRATIONS"
    
else
    echo "❌ Error: Base de datos no se pudo crear"
    exit 1
fi

# Set correct permissions
chown whatsapp:whatsapp database/app.db
chmod 644 database/app.db

# Restart server
echo "🚀 Reiniciando servidor..."
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 start whatsapp-api

echo "✅ Esquema de base de datos corregido"