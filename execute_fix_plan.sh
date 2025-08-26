#!/bin/bash

# Complete fix plan execution
set -e

echo "🚀 Ejecutando plan de arreglo completo..."

# Paso 1: Arreglar PM2 y permisos
echo "📦 Paso 1: Arreglando PM2 y permisos..."
chmod +x fix_pm2_qr_complete.sh
./fix_pm2_qr_complete.sh

# Esperar un momento entre pasos
sleep 3

# Paso 2: Arreglar migración de base de datos
echo "🗄️ Paso 2: Arreglando migración de base de datos..."
chmod +x fix_migration_definitive.sh
./fix_migration_definitive.sh

# Paso 3: Verificación final
echo "✅ Paso 3: Verificación final..."
echo "🔍 Verificando endpoint de métricas..."
curl -s http://localhost:3000/api/metrics/dashboard && echo " - Endpoint directo ✅" || echo " - Endpoint directo ❌"
curl -s http://localhost/api/metrics/dashboard && echo " - Endpoint via Nginx ✅" || echo " - Endpoint via Nginx ❌"

echo "🎉 Plan de arreglo completado!"
echo "🌐 Tu aplicación debería estar funcionando en: http://168.197.49.169/"