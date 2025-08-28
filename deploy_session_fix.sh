#!/bin/bash

# Deploy session synchronization fix
set -e

echo "🚀 Deploying session synchronization fix..."

# Check if we're on the server or need to copy files
if [ -d "/var/www/whatsapp-api" ]; then
    echo "📁 Detected server environment, copying files directly..."
    
    # Copy updated files
    echo "📝 Copying WhatsAppSessionManager.js..."
    cp server/managers/WhatsAppSessionManager.js /var/www/whatsapp-api/server/managers/
    
    echo "📝 Copying server.js..."
    cp server/server.js /var/www/whatsapp-api/server/
    
    # Set proper permissions
    echo "🔐 Setting permissions..."
    chown -R www-data:www-data /var/www/whatsapp-api/server/managers/WhatsAppSessionManager.js
    chown -R www-data:www-data /var/www/whatsapp-api/server/server.js
    
    # Restart PM2 service
    echo "🔄 Restarting PM2 service..."
    cd /var/www/whatsapp-api/server
    sudo -u www-data pm2 restart whatsapp-api
    
    # Wait for service to start
    echo "⏳ Waiting for service to start..."
    sleep 5
    
    # Verify service status
    echo "✅ Checking service status..."
    sudo -u www-data pm2 status whatsapp-api
    
    echo "🎉 Session synchronization fix deployed successfully!"
    echo "📊 Sessions should now appear correctly in the frontend"
    
else
    echo "❌ Not on server environment. Please run this script on your server."
    echo "💡 Or copy these files manually to your server:"
    echo "   - server/managers/WhatsAppSessionManager.js"
    echo "   - server/server.js"
    echo "   Then restart PM2: sudo -u www-data pm2 restart whatsapp-api"
fi