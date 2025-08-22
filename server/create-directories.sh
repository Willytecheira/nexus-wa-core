#!/bin/bash

# Script para crear todos los directorios necesarios para la aplicación WhatsApp API
set -e

echo "🔧 Creando directorios necesarios..."

# Definir el directorio base del servidor
SERVER_DIR="/var/www/whatsapp-api/server"

# Crear directorios críticos
echo "📁 Creando directorios críticos..."
mkdir -p "$SERVER_DIR/database"
mkdir -p "$SERVER_DIR/logs"
mkdir -p "$SERVER_DIR/uploads"
mkdir -p "$SERVER_DIR/qr"
mkdir -p "$SERVER_DIR/sessions"

# Establecer permisos correctos
echo "🔐 Configurando permisos..."
chmod 755 "$SERVER_DIR/database"
chmod 755 "$SERVER_DIR/logs"
chmod 755 "$SERVER_DIR/uploads"
chmod 755 "$SERVER_DIR/qr"
chmod 755 "$SERVER_DIR/sessions"

# Crear archivos .gitkeep para mantener los directorios en Git
echo "📄 Creando archivos .gitkeep..."
touch "$SERVER_DIR/database/.gitkeep"
touch "$SERVER_DIR/logs/.gitkeep"
touch "$SERVER_DIR/uploads/.gitkeep"
touch "$SERVER_DIR/qr/.gitkeep"
touch "$SERVER_DIR/sessions/.gitkeep"

# Verificar que los directorios fueron creados correctamente
echo "✅ Verificando directorios..."
for dir in database logs uploads qr sessions; do
    if [ -d "$SERVER_DIR/$dir" ] && [ -w "$SERVER_DIR/$dir" ]; then
        echo "   ✓ $dir - OK (writable)"
    else
        echo "   ❌ $dir - ERROR (not writable)"
        exit 1
    fi
done

echo "🎉 Todos los directorios fueron creados exitosamente!"
echo "📝 Ahora puedes reiniciar PM2 con: pm2 restart whatsapp-api"