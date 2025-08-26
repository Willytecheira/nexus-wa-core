#!/bin/bash

# Script para limpiar archivos de migración problemáticos
set -e

echo "🧹 Limpiando archivos de migración problemáticos..."

cd /var/www/whatsapp-api/server

# Paso 1: Eliminar archivos rollback que causan conflictos
echo "🗑️ Eliminando archivos rollback..."
rm -f migrations/*_rollback.sql
echo "✅ Archivos rollback eliminados"

# Paso 2: Limpiar y corregir migration_log
echo "🔄 Corrigiendo migration_log..."
sudo -u whatsapp sqlite3 database/app.db << 'EOF'
DELETE FROM migration_log;
INSERT INTO migration_log (migration_name, executed_at) VALUES 
('001_initial_schema', CURRENT_TIMESTAMP);
EOF
echo "✅ Migration_log corregido"

# Paso 3: Verificar estado limpio
echo "🔍 Verificando estado limpio..."
echo "Archivos de migración disponibles:"
ls migrations/*.sql

echo -e "\nMigraciones registradas en base de datos:"
sudo -u whatsapp sqlite3 database/app.db "SELECT migration_name, executed_at FROM migration_log;"

echo -e "\n✅ Estado de migración limpio"
echo "🚀 Ahora puedes ejecutar: ./comprehensive_fix.sh"