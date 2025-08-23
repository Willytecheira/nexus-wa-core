#!/bin/bash

# Complete fix for PM2 and QR Code issues
set -e

echo "🔧 Starting complete PM2 and QR fix..."

# Step 1: Fix PM2 directories and permissions for www-data
echo "📁 Setting up PM2 directories for www-data user..."
mkdir -p /home/www-data/.pm2/{logs,pids,modules}
chown -R www-data:www-data /home/www-data/.pm2/
chmod -R 755 /home/www-data/.pm2/

# Create www-data home directory if it doesn't exist
if [ ! -d "/home/www-data" ]; then
    mkdir -p /home/www-data
    chown www-data:www-data /home/www-data
    chmod 755 /home/www-data
fi

# Set PM2_HOME environment variable for www-data
echo 'export PM2_HOME=/home/www-data/.pm2' >> /home/www-data/.bashrc || true

# Step 2: Stop any existing PM2 processes
echo "🛑 Stopping existing PM2 processes..."
pkill -f "PM2" || true
pkill -f "whatsapp-api" || true
sleep 2

# Step 3: Fix project permissions
echo "🔐 Setting correct project permissions..."
cd /var/www/whatsapp-api
chown -R www-data:www-data .
chmod -R 755 .
chmod -R 755 server/qr/
chmod 644 server/qr/*.png 2>/dev/null || true

# Step 4: Start PM2 as www-data with correct environment
echo "🚀 Starting PM2 as www-data user..."
export PM2_HOME=/home/www-data/.pm2
su - www-data -s /bin/bash -c "
    export PM2_HOME=/home/www-data/.pm2
    cd /var/www/whatsapp-api
    pm2 delete whatsapp-api 2>/dev/null || true
    pm2 start server/ecosystem.config.js
    pm2 save
"

# Step 5: Verify Nginx QR configuration
echo "🌐 Verifying Nginx configuration for QR..."
nginx -t

# Step 6: Test backend is running
echo "⏳ Waiting for backend to start..."
sleep 5

# Step 7: Run comprehensive tests
echo "🧪 Running comprehensive tests..."

echo "Backend direct health check:"
curl -s http://localhost:3000/health && echo " ✅" || echo " ❌"

echo "API through Nginx:"
curl -s http://localhost/api/health && echo " ✅" || echo " ❌"

echo "PM2 status:"
su - www-data -s /bin/bash -c "export PM2_HOME=/home/www-data/.pm2 && pm2 list"

echo "QR directory contents:"
ls -la server/qr/

echo "Testing direct QR file access:"
if ls server/qr/*.png 1> /dev/null 2>&1; then
    QR_FILE=$(ls server/qr/*.png | head -1 | xargs basename)
    echo "Testing QR file: $QR_FILE"
    curl -I http://localhost/qr/$QR_FILE 2>/dev/null | head -1
else
    echo "No QR files found"
fi

echo "Backend logs (last 10 lines):"
su - www-data -s /bin/bash -c "export PM2_HOME=/home/www-data/.pm2 && pm2 logs whatsapp-api --lines 10 --nostream"

echo "🎉 PM2 and QR fix complete!"
echo "📝 Monitor with: sudo -u www-data PM2_HOME=/home/www-data/.pm2 pm2 logs whatsapp-api"
echo "🔗 Try creating a new session now - QR should work!"