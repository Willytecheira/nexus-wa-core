#!/bin/bash

# Script para arreglar permisos y configuración del QR Code
set -e

echo "🔧 Arreglando permisos y configuración del QR Code..."

# 1. Arreglar permisos de la carpeta QR
echo "📁 Arreglando permisos de la carpeta QR..."
cd /var/www/whatsapp-api
chown -R www-data:www-data server/qr/
chmod 755 server/qr/
chmod 644 server/qr/*.png 2>/dev/null || true

# 2. Verificar que nginx tenga la configuración actualizada
echo "🌐 Copiando configuración de Nginx..."
cp server/nginx/whatsapp-api.conf /etc/nginx/sites-available/whatsapp-api
nginx -t

# 3. Recargar nginx
echo "🔄 Recargando Nginx..."
systemctl reload nginx

# 4. Reiniciar PM2 con el usuario correcto
echo "🚀 Reiniciando PM2 con usuario correcto..."
su - www-data -c "cd /var/www/whatsapp-api && pm2 delete whatsapp-api || true"
su - www-data -c "cd /var/www/whatsapp-api && pm2 start server/ecosystem.config.js"

# 5. Verificar funcionamiento
echo "⏳ Esperando a que el servidor inicie..."
sleep 5

echo "✅ Verificando funcionamiento..."
curl -s http://localhost/api/health && echo " - API funcionando"
ls -la /var/www/whatsapp-api/server/qr/ && echo " - Carpeta QR con permisos correctos"

echo "🎉 ¡QR Code configurado correctamente!"
echo "📝 Puedes verificar los logs con: su - www-data -c 'pm2 logs whatsapp-api'"
echo "🔗 Ahora puedes crear una nueva sesión desde la web y el QR debería aparecer"