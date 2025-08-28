#!/bin/bash

# Fix PM2 startup as root with ecosystem.config.js
set -e

echo "🔧 Fixing PM2 startup issue..."

cd /var/www/whatsapp-api/server

# Stop any existing PM2 processes
echo "⏹️ Stopping existing PM2 processes..."
pm2 stop whatsapp-api || true
pm2 delete whatsapp-api || true

# Start PM2 as root with ecosystem.config.js
echo "🚀 Starting PM2 as root with ecosystem.config.js..."
pm2 start ecosystem.config.js --env production

# Save PM2 configuration
echo "💾 Saving PM2 configuration..."
pm2 save

# Wait for service to stabilize
echo "⏳ Waiting for service to stabilize..."
sleep 10

# Verify PM2 status
echo "📊 Checking PM2 status..."
pm2 status

# Check if server is responding
echo "🔍 Testing server health..."
curl -s http://localhost:3000/health || echo "❌ Health check failed"

echo "🔍 Testing API through Nginx..."
curl -s http://localhost/api/health || echo "❌ API health check failed"

# Check PM2 logs for any errors
echo "📝 Recent PM2 logs:"
pm2 logs whatsapp-api --lines 10

echo "✅ PM2 fix completed!"
echo "🌐 Try accessing your application at: http://168.197.49.169/"