#!/bin/bash

echo "🔄 Actualizando código desde GitHub..."

# Ir al directorio del proyecto
cd /var/www/whatsapp-api

# Hacer el script ejecutable
chmod +x safe_github_pull.sh

# Ejecutar el script de actualización segura
./safe_github_pull.sh

echo "✅ Actualización completada. Revisa la página de Sessions y los logs del navegador."