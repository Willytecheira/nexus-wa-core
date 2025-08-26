#!/bin/bash

# Fix migration system and restart application
set -e

echo "🔧 Fixing migration system and restarting application..."

cd /var/www/whatsapp-api/server

# Stop any running processes
echo "⏹️ Stopping existing processes..."
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 stop whatsapp-api || true
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 delete whatsapp-api || true

# Clean database state
echo "🗄️ Cleaning database state..."
rm -f database/app.db
rm -f database/*.db

# Ensure database directory exists with correct permissions
mkdir -p database
chown whatsapp:whatsapp database
chmod 755 database

# Run migrations with fixed logic
echo "📦 Running corrected migrations..."
sudo -u whatsapp node migrations/migrate.js

# Verify database was created correctly
if [ -f "database/app.db" ]; then
    echo "✅ Database created successfully"
    
    # Check tables
    TABLES=$(sudo -u whatsapp sqlite3 database/app.db ".tables")
    echo "📋 Tables created: $TABLES"
    
    # Check migrations
    MIGRATIONS=$(sudo -u whatsapp sqlite3 database/app.db "SELECT migration_name FROM migration_log;" 2>/dev/null || echo "No migrations logged")
    echo "🔄 Migrations applied: $MIGRATIONS"
else
    echo "❌ Error: Database was not created"
    exit 1
fi

# Set correct permissions
chown whatsapp:whatsapp database/app.db
chmod 644 database/app.db

# Start application
echo "🚀 Starting application..."
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 start ecosystem.config.js
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 save

# Wait for startup
echo "⏳ Waiting for application to start..."
sleep 10

# Verify functionality
echo "✅ Verifying application..."

echo "📊 PM2 Status:"
sudo -u whatsapp PM2_HOME=/home/whatsapp/.pm2 pm2 status

echo -e "\n🔍 Health Checks:"
if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ Backend health check passed"
else
    echo "❌ Backend health check failed"
fi

if curl -s http://localhost/api/health > /dev/null; then
    echo "✅ Nginx health check passed"
else
    echo "❌ Nginx health check failed"
fi

# Test login
echo -e "\n🔐 Testing login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' 2>/dev/null || echo "ERROR")

if [[ $LOGIN_RESPONSE == *"token"* ]]; then
    echo "✅ Login system working"
else
    echo "⚠️ Login test: $LOGIN_RESPONSE"
fi

echo -e "\n🎉 Migration fix completed!"
echo "🌐 Application available at: http://168.197.49.169/"
echo "🔑 Login credentials: admin / admin123"