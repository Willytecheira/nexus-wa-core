#!/bin/bash

# Quick test script to verify all services are working
echo "🔍 Verificación rápida del sistema..."

echo ""
echo "📊 Estado de PM2:"
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 status

echo ""
echo "🔍 Tests de conectividad:"

# Test backend direct
echo -n "Backend directo (3000): "
if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ OK"
else
    echo "❌ FAIL"
fi

# Test API through Nginx
echo -n "API via Nginx (/api/health): "
if curl -s http://localhost/api/health > /dev/null; then
    echo "✅ OK"
else
    echo "❌ FAIL"
fi

# Test frontend
echo -n "Frontend (/): "
if curl -s http://localhost/ > /dev/null; then
    echo "✅ OK"
else
    echo "❌ FAIL"
fi

# Test login
echo -n "Login endpoint: "
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' 2>/dev/null || echo "ERROR")

if [[ $LOGIN_RESPONSE == *"token"* ]]; then
    echo "✅ OK"
else
    echo "❌ FAIL"
fi

# Test sessions endpoint
echo -n "Sessions endpoint: "
if curl -s http://localhost:3000/api/sessions > /dev/null; then
    echo "✅ OK"
else
    echo "❌ FAIL"
fi

echo ""
echo "📁 Verificación de directorios:"
echo "Database: $(ls -la /var/www/whatsapp-api/server/database/ 2>/dev/null | wc -l) archivos"
echo "QR: $(ls -la /var/www/whatsapp-api/server/qr/ 2>/dev/null | wc -l) archivos"
echo "Sessions: $(ls -la /var/www/whatsapp-api/server/sessions/ 2>/dev/null | wc -l) archivos"

echo ""
echo "🌐 Acceso externo: http://168.197.49.169/"