#!/bin/bash

# Complete fix for all identified issues
set -e

echo "🔧 Starting comprehensive fix for all issues..."

# Step 1: Resolve Git conflicts
echo "📝 Resolving Git conflicts..."
cd /var/www/whatsapp-api

# Stash any local changes
git stash push -m "Auto-stash before update $(date)"

# Pull latest changes
git pull origin main

echo "✅ Git conflicts resolved"

# Step 2: Install Puppeteer dependencies
echo "📦 Installing Puppeteer dependencies..."
apt-get update
apt-get install -y \
    libnss3-dev \
    libatk-bridge2.0-dev \
    libdrm2 \
    libgtk-3-dev \
    libgbm-dev \
    libasound2-dev

echo "✅ Puppeteer dependencies installed"

# Step 3: Create necessary directories with correct permissions
echo "📁 Creating necessary directories..."
mkdir -p server/qr server/sessions server/logs uploads
chown -R www-data:www-data server/qr server/sessions server/logs uploads
chmod -R 755 server/qr server/sessions server/logs uploads

echo "✅ Directories created"

# Step 4: Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
cd server
npm install --production
cd ..

echo "✅ Node.js dependencies installed"

# Step 5: Build frontend
echo "🔨 Building frontend..."
npm install
npm run build

echo "✅ Frontend built"

# Step 6: Fix Nginx configuration
echo "🌐 Fixing Nginx configuration..."
# Remove existing configuration
rm -f /etc/nginx/sites-enabled/whatsapp-api
rm -f /etc/nginx/sites-enabled/default

# Copy and enable our configuration
cp server/nginx/whatsapp-api.conf /etc/nginx/sites-available/whatsapp-api
ln -s /etc/nginx/sites-available/whatsapp-api /etc/nginx/sites-enabled/whatsapp-api

# Test and reload Nginx
nginx -t
systemctl reload nginx

echo "✅ Nginx configuration fixed"

# Step 7: Set correct permissions for the entire project
echo "🔐 Setting correct permissions..."
chown -R www-data:www-data /var/www/whatsapp-api
chmod -R 755 /var/www/whatsapp-api

echo "✅ Permissions set"

# Step 8: Restart PM2
echo "🚀 Restarting PM2..."
export PM2_HOME=/home/www-data/.pm2
su - www-data -s /bin/bash -c "
    export PM2_HOME=/home/www-data/.pm2
    cd /var/www/whatsapp-api
    pm2 delete whatsapp-api 2>/dev/null || true
    pm2 start server/ecosystem.config.js
    pm2 save
"

echo "✅ PM2 restarted"

# Step 9: Wait for services to start
echo "⏳ Waiting for services to stabilize..."
sleep 10

# Step 10: Run comprehensive tests
echo "🧪 Running comprehensive tests..."

echo "Testing backend health:"
curl -s http://localhost:3000/health && echo " ✅ Backend health OK" || echo " ❌ Backend health failed"

echo "Testing API through Nginx:"
curl -s http://localhost/api/health && echo " ✅ API through Nginx OK" || echo " ❌ API through Nginx failed"

echo "Testing main page:"
curl -I http://localhost/ 2>/dev/null | head -1

echo "PM2 status:"
su - www-data -s /bin/bash -c "export PM2_HOME=/home/www-data/.pm2 && pm2 list"

echo "QR directory status:"
ls -la server/qr/ || echo "QR directory doesn't exist yet"

echo "Running QR setup check:"
cd server && node check-qr-setup.js

echo "Backend logs (last 10 lines):"
su - www-data -s /bin/bash -c "export PM2_HOME=/home/www-data/.pm2 && pm2 logs whatsapp-api --lines 10 --nostream"

echo ""
echo "🎉 Complete fix finished!"
echo "📝 Monitor with: sudo -u www-data PM2_HOME=/home/www-data/.pm2 pm2 logs whatsapp-api"
echo "🔗 Try creating a new session now - all issues should be resolved!"
echo ""
echo "Next steps:"
echo "1. Go to http://168.197.49.169/"
echo "2. Login with your credentials"
echo "3. Create a new WhatsApp session"
echo "4. The QR code should now display correctly"