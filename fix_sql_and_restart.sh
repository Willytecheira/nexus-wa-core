#!/bin/bash

# Fix SQL error and restart PM2 with corrected ecosystem.config.js
set -e

echo "🔧 Fixing SQL error and restarting PM2..."

cd /var/www/whatsapp-api/server

# Stop PM2 process
echo "⏹️ Stopping PM2..."
pm2 stop whatsapp-api || true

# Run database migrations to ensure tables exist
echo "🗄️ Running database migrations..."
node migrations/migrate.js

# Start PM2 with the corrected ecosystem.config.js
echo "🚀 Starting PM2 with production environment..."
pm2 start ecosystem.config.js --env production

# Save PM2 configuration
echo "💾 Saving PM2 configuration..."
pm2 save

# Wait for service to stabilize
echo "⏳ Waiting for service to stabilize..."
sleep 5

# Check PM2 status
echo "📊 Checking PM2 status..."
pm2 status

# Test server health
echo "🔍 Testing server health..."
curl -s http://localhost:3000/health | jq . || echo "❌ Health check failed"

# Test sessions endpoint (the one that was failing)
echo "🔍 Testing sessions endpoint..."
curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' > /tmp/login_response.json

if grep -q "token" /tmp/login_response.json; then
    echo "✅ Login successful, testing sessions..."
    TOKEN=$(cat /tmp/login_response.json | jq -r '.token')
    curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/sessions | jq . || echo "❌ Sessions endpoint failed"
else
    echo "❌ Login failed"
    cat /tmp/login_response.json
fi

# Check recent logs for any remaining errors
echo "📝 Recent PM2 logs:"
pm2 logs whatsapp-api --lines 5

echo "✅ Fix completed!"
echo "🌐 Access your application at: http://168.197.49.169/"