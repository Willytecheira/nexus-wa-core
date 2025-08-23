#!/bin/bash

# Complete asset fix for WhatsApp API
echo "🔧 Starting complete asset fix..."

# Step 1: Check dist directory
echo "📁 Checking dist directory..."
if [ ! -d "/var/www/whatsapp-api/dist" ]; then
    echo "❌ Dist directory missing"
    NEED_BUILD=true
else
    echo "✅ Dist directory exists"
    ls -la /var/www/whatsapp-api/dist/
    
    # Check if assets exist
    if [ ! -d "/var/www/whatsapp-api/dist/assets" ] || [ -z "$(ls -A /var/www/whatsapp-api/dist/assets 2>/dev/null)" ]; then
        echo "❌ Assets directory missing or empty"
        NEED_BUILD=true
    else
        echo "✅ Assets directory exists with content"
        ls -la /var/www/whatsapp-api/dist/assets/ | head -10
    fi
fi

# Step 2: Rebuild frontend if needed
if [ "$NEED_BUILD" = true ]; then
    echo "🔨 Building frontend..."
    cd /var/www/whatsapp-api
    npm run build
    
    echo "📦 Checking build output..."
    ls -la dist/
    ls -la dist/assets/ | head -10
fi

# Step 3: Fix Nginx configuration
echo "🌐 Applying Nginx configuration..."
cp /var/www/whatsapp-api/server/nginx/whatsapp-api.conf /etc/nginx/sites-available/whatsapp-api
rm -f /etc/nginx/sites-enabled/whatsapp-api
ln -s /etc/nginx/sites-available/whatsapp-api /etc/nginx/sites-enabled/whatsapp-api
rm -f /etc/nginx/sites-enabled/default

# Test Nginx config
nginx -t
if [ $? -ne 0 ]; then
    echo "❌ Nginx configuration error"
    exit 1
fi

# Step 4: Fix permissions
echo "🔐 Setting correct permissions..."
chown -R www-data:www-data /var/www/whatsapp-api/
chmod -R 755 /var/www/whatsapp-api/dist/
chmod -R 644 /var/www/whatsapp-api/dist/assets/*

# Step 5: Restart Nginx
echo "🔄 Restarting Nginx..."
systemctl restart nginx

# Wait for services to stabilize
sleep 3

# Step 6: Final tests
echo "🧪 Running final tests..."

echo "Backend direct:"
curl -s http://localhost:3000/health | jq '.status' 2>/dev/null || curl -s http://localhost:3000/health

echo -e "\nAPI through Nginx:"
curl -s http://localhost/api/health

echo -e "\nMain page:"
curl -I http://localhost/ 2>/dev/null | head -1

echo -e "\nTesting specific assets..."
ASSETS=$(find /var/www/whatsapp-api/dist/assets/ -name "*.css" -o -name "*.js" | head -3)
for asset in $ASSETS; do
    asset_path="/assets/$(basename $asset)"
    echo "Testing $asset_path:"
    curl -I http://localhost$asset_path 2>/dev/null | head -1
done

echo -e "\nExisting asset summary:"
echo "CSS files: $(find /var/www/whatsapp-api/dist/assets/ -name "*.css" | wc -l)"
echo "JS files: $(find /var/www/whatsapp-api/dist/assets/ -name "*.js" | wc -l)"
echo "Other files: $(find /var/www/whatsapp-api/dist/assets/ ! -name "*.css" ! -name "*.js" | wc -l)"

echo -e "\n🎉 Asset fix complete!"
echo "✅ You can now access your app at: http://168.197.49.169/"