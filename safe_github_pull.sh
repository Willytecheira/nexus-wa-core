#!/bin/bash

# Script para hacer pull seguro desde GitHub manteniendo fixes necesarios
set -e

echo "🔄 Iniciando pull seguro desde GitHub..."

cd /var/www/whatsapp-api

# Paso 1: Hacer backup de scripts de fix locales
echo "💾 Guardando scripts de fix locales..."
git stash push -m "Scripts de fix locales antes del pull" || true

# Paso 2: Hacer pull del repositorio
echo "📦 Haciendo pull desde GitHub..."
git fetch origin
git pull origin main

echo "✅ Pull desde GitHub completado"

# Paso 3: Verificar si necesitamos aplicar fixes de migración
echo "🔍 Verificando estado de migraciones..."
cd server

# Verificar si existen archivos rollback problemáticos
if ls migrations/*_rollback.sql 1> /dev/null 2>&1; then
    echo "⚠️ Se encontraron archivos rollback problemáticos"
    echo "🧹 Limpiando archivos rollback..."
    rm -f migrations/*_rollback.sql
    echo "✅ Archivos rollback eliminados"
fi

# Verificar estado de la base de datos
if [ -f "database/app.db" ]; then
    echo "🗄️ Verificando estado de migration_log..."
    MIGRATION_COUNT=$(sudo -u whatsapp sqlite3 database/app.db "SELECT COUNT(*) FROM migration_log WHERE migration_name LIKE '%002%';" 2>/dev/null || echo "0")
    
    if [ "$MIGRATION_COUNT" -gt 0 ]; then
        echo "🔧 Corrigiendo migration_log..."
        sudo -u whatsapp sqlite3 database/app.db << 'EOF'
DELETE FROM migration_log WHERE migration_name LIKE '%002%';
EOF
        echo "✅ Migration_log corregido"
    fi
fi

cd ..

# Paso 4: Ejecutar setup completo
echo "🚀 Ejecutando setup completo..."
chmod +x comprehensive_fix.sh
./comprehensive_fix.sh

echo -e "\n🎉 ¡Pull seguro desde GitHub completado!"
echo "🌐 Tu aplicación debería estar actualizada y funcionando en: http://168.197.49.169/"