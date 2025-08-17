# WhatsApp Multi-Session API - Backend

Enterprise-grade WhatsApp Multi-Session API built with Node.js, Express, and whatsapp-web.js.

## 🚀 Features

- **Multi-Session Management**: Create and manage multiple WhatsApp sessions simultaneously
- **Real-time Communication**: Socket.IO for live updates and notifications
- **Authentication & Authorization**: JWT-based auth with role-based access control
- **Message Management**: Send/receive text, images, and multimedia messages
- **Session Monitoring**: Real-time session status tracking and QR code generation
- **User Management**: Complete CRUD operations for user administration
- **Metrics & Analytics**: System performance monitoring and usage statistics
- **Secure File Handling**: Multer-based file upload with validation
- **Production Ready**: PM2 ecosystem, Nginx configuration, and Docker support

## 📋 System Requirements

### Minimum Requirements
- **OS**: Ubuntu 18.04+ / CentOS 7+ / Debian 9+
- **CPU**: 2 cores, 2.4 GHz
- **RAM**: 4 GB (recommended 8 GB)
- **Storage**: 20 GB SSD
- **Node.js**: 18.x or higher
- **Chrome/Chromium**: Latest stable version

### Recommended for Production
- **CPU**: 4+ cores, 3.0+ GHz
- **RAM**: 8+ GB
- **Storage**: 50+ GB SSD
- **Network**: 100 Mbps+ connection

## 🛠️ Quick Installation (Ubuntu)

### Automated Installation
```bash
# Download and run the installation script
wget https://raw.githubusercontent.com/yourusername/whatsapp-multi-session-api/main/server/install.sh
sudo chmod +x install.sh
sudo ./install.sh
```

### Manual Installation

1. **Install Node.js 18.x**
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

2. **Install Chrome dependencies**
```bash
sudo apt-get update
sudo apt-get install -y \
    gconf-service libasound2 libatk1.0-0 libatk-bridge2.0-0 \
    libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 \
    libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 \
    libnspr4 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 \
    libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 \
    libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 \
    libxtst6 ca-certificates fonts-liberation libappindicator1 \
    libnss3 lsb-release xdg-utils wget
```

3. **Install Google Chrome**
```bash
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt-get update
sudo apt-get install -y google-chrome-stable
```

4. **Install PM2 globally**
```bash
sudo npm install -g pm2
pm2 startup
```

5. **Clone and setup project**
```bash
git clone https://github.com/yourusername/whatsapp-multi-session-api.git
cd whatsapp-multi-session-api/server
npm install
```

6. **Configure environment**
```bash
cp .env.example .env
nano .env  # Edit configuration
```

7. **Start the application**
```bash
pm2 start ecosystem.config.js
pm2 save
```

## ⚙️ Configuration

### Environment Variables (.env)

```env
# Server Configuration
NODE_ENV=production
PORT=3000

# Security
JWT_SECRET=your-super-secret-jwt-key-change-this

# Frontend URL
FRONTEND_URL=https://your-domain.com

# Logging
LOG_LEVEL=info

# WhatsApp Configuration
WHATSAPP_SESSION_TIMEOUT=300000
WHATSAPP_MAX_SESSIONS=50

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
```

### PM2 Configuration (ecosystem.config.js)

The PM2 ecosystem file is pre-configured for production deployment:

```javascript
module.exports = {
  apps: [{
    name: 'whatsapp-api',
    script: 'server.js',
    instances: 1,
    exec_mode: 'fork',
    max_memory_restart: '2G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
```

## 🌐 Nginx Configuration

The installation script includes a complete Nginx configuration with:

- **Reverse Proxy**: Routes API calls to the Node.js server
- **Static File Serving**: Serves React frontend and uploaded files
- **WebSocket Support**: Enables Socket.IO real-time communication
- **Security Headers**: Comprehensive security headers
- **Rate Limiting**: Protects against DDoS and brute force attacks
- **Gzip Compression**: Optimizes bandwidth usage

## 📡 API Documentation

### Authentication

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin123",
  "rememberMe": true
}
```

#### Logout
```http
POST /api/auth/logout
Authorization: Bearer <token>
```

### Session Management

#### Get All Sessions
```http
GET /api/sessions
Authorization: Bearer <token>
```

#### Create Session
```http
POST /api/sessions
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "My WhatsApp Session"
}
```

#### Delete Session
```http
DELETE /api/sessions/{sessionId}
Authorization: Bearer <token>
```

#### Restart Session
```http
POST /api/sessions/{sessionId}/restart
Authorization: Bearer <token>
```

#### Get QR Code
```http
GET /api/sessions/{sessionId}/qr
Authorization: Bearer <token>
```

### Message Management

#### Send Message
```http
POST /api/messages/send
Authorization: Bearer <token>
Content-Type: application/json

{
  "sessionId": "session-uuid",
  "to": "1234567890",
  "message": "Hello World!",
  "type": "text"
}
```

#### Get Messages
```http
GET /api/messages?sessionId={sessionId}&page=1&limit=50
Authorization: Bearer <token>
```

### User Management (Admin Only)

#### Get All Users
```http
GET /api/users
Authorization: Bearer <token>
```

#### Create User
```http
POST /api/users
Authorization: Bearer <token>
Content-Type: application/json

{
  "username": "newuser",
  "password": "password123",
  "role": "operator"
}
```

#### Update User
```http
PUT /api/users/{userId}
Authorization: Bearer <token>
Content-Type: application/json

{
  "role": "viewer",
  "status": "active"
}
```

#### Delete User
```http
DELETE /api/users/{userId}
Authorization: Bearer <token>
```

### System Metrics

#### Get Metrics
```http
GET /api/metrics
Authorization: Bearer <token>
```

### Health Check

#### Health Status
```http
GET /health
```

## 🔒 Security Features

### Authentication & Authorization
- **JWT Tokens**: Secure token-based authentication
- **Role-Based Access**: Admin, Operator, and Viewer roles
- **Password Hashing**: bcrypt with salt rounds
- **Token Expiration**: Configurable token lifetime

### Network Security
- **Rate Limiting**: Express rate limiter with configurable windows
- **CORS Protection**: Configured for specific origins
- **Security Headers**: Helmet.js for comprehensive headers
- **Request Validation**: Express validator for input sanitization

### Application Security
- **SQL Injection Protection**: Parameterized queries
- **File Upload Validation**: Multer with file type restrictions
- **Error Handling**: Comprehensive error handling without information leakage
- **Logging**: Winston for structured logging

## 📊 Monitoring & Logging

### Application Monitoring
```bash
# View real-time logs
pm2 logs whatsapp-api

# Monitor resources
pm2 monit

# View process status
pm2 status
```

### Log Files
- **Combined Logs**: `logs/combined.log`
- **Error Logs**: `logs/error.log`
- **Access Logs**: `logs/out.log`

### System Metrics
The API provides built-in metrics:
- Active session count
- Total message count
- Memory and CPU usage
- System uptime
- Message delivery statistics

## 🔧 Production Deployment

### 1. Domain and SSL Setup

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### 2. Database Backup

```bash
# Manual backup
/usr/local/bin/whatsapp-backup.sh

# Automated daily backup (already configured)
# Backups stored in: /var/backups/whatsapp-api/
```

### 3. Performance Optimization

```bash
# Increase file limits
echo "fs.file-max = 65536" >> /etc/sysctl.conf

# Network optimizations
echo "net.core.somaxconn = 1024" >> /etc/sysctl.conf
sysctl -p
```

## 🚨 Troubleshooting

### Common Issues

#### Chrome/Puppeteer Issues
```bash
# Check Chrome installation
google-chrome --version

# Fix missing dependencies
sudo apt-get install -f

# Clear Chrome cache
rm -rf /tmp/.com.google.Chrome.*
```

#### Permission Issues
```bash
# Fix file permissions
sudo chown -R whatsapp:whatsapp /var/www/whatsapp-api
sudo chmod -R 755 /var/www/whatsapp-api
```

#### Session Creation Fails
```bash
# Check available memory
free -h

# Restart PM2
pm2 restart whatsapp-api

# Clear session data
rm -rf /var/www/whatsapp-api/server/sessions/*
```

#### Port Already in Use
```bash
# Find process using port 3000
sudo netstat -tlnp | grep :3000
sudo kill -9 <PID>
```

### Log Analysis

```bash
# Check application logs
tail -f /var/www/whatsapp-api/server/logs/combined.log

# Check Nginx logs
tail -f /var/log/nginx/error.log

# Check PM2 logs
pm2 logs whatsapp-api --lines 100
```

### Performance Issues

```bash
# Monitor system resources
htop

# Check disk space
df -h

# Monitor network connections
netstat -an | grep :3000 | wc -l
```

## 🔄 Updates and Maintenance

### Application Updates
```bash
# Navigate to project directory
cd /var/www/whatsapp-api

# Run deployment script
./deploy.sh
```

### Manual Update Process
```bash
# Stop the application
pm2 stop whatsapp-api

# Backup current version
cp -r server server_backup_$(date +%Y%m%d)

# Pull latest changes
git pull origin main

# Update dependencies
cd server && npm install

# Restart application
pm2 start ecosystem.config.js
```

### Database Maintenance
```bash
# Cleanup old data (30+ days)
# This is handled automatically by the application

# Manual database backup
tar -czf database_backup_$(date +%Y%m%d).tar.gz -C /var/www/whatsapp-api/server database/
```

## 📈 Scaling

### Horizontal Scaling
- Use a load balancer (HAProxy/Nginx)
- Configure session persistence with Redis
- Implement database clustering

### Vertical Scaling
- Increase server resources (CPU/RAM)
- Optimize PM2 configuration
- Tune database parameters

## 🆘 Support

### Default Credentials
- **Username**: admin
- **Password**: admin123
- **Role**: admin

⚠️ **Change default credentials immediately after installation!**

### Useful Commands
```bash
# Service management
pm2 start whatsapp-api
pm2 stop whatsapp-api
pm2 restart whatsapp-api
pm2 reload whatsapp-api

# Monitoring
pm2 monit
pm2 logs whatsapp-api
pm2 show whatsapp-api

# Nginx
sudo nginx -t
sudo systemctl reload nginx
sudo systemctl status nginx

# System health
systemctl status whatsapp-api
journalctl -u whatsapp-api -f
```

### Contact Information
- **GitHub Issues**: [Report bugs and feature requests](https://github.com/yourusername/whatsapp-multi-session-api/issues)
- **Documentation**: [Complete API documentation](https://docs.your-domain.com)
- **Support Email**: support@your-domain.com

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**🚀 Ready for production deployment!**