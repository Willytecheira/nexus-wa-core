#!/bin/bash

# Fix Nginx configuration completely
echo "🔧 Fixing Nginx configuration..."

# 1. Copy the correct configuration
cp /var/www/whatsapp-api/server/nginx/whatsapp-api.conf /etc/nginx/sites-available/whatsapp-api

# 2. Remove any existing symlink
rm -f /etc/nginx/sites-enabled/whatsapp-api

# 3. Create new symlink
ln -s /etc/nginx/sites-available/whatsapp-api /etc/nginx/sites-enabled/whatsapp-api

# 4. Remove default site if it exists
rm -f /etc/nginx/sites-enabled/default

# 5. Test configuration
nginx -t

# 6. Restart Nginx
systemctl restart nginx

# 7. Test everything
echo "Testing configuration..."
sleep 2

echo "✅ Testing backend health:"
curl http://localhost:3000/health

echo -e "\n✅ Testing API through Nginx:"
curl http://localhost/api/health

echo -e "\n✅ Testing assets:"
curl -I http://localhost/assets/index-f3IcJbXb.css | head -1

echo -e "\n✅ Testing main page:"
curl -I http://localhost/ | head -1

echo -e "\n🎉 Configuration complete!"