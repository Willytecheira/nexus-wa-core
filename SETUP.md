# WhatsApp Multi-Session API - Guía de Instalación Paso a Paso

## **PASO 1: PREPARAR EL REPOSITORIO EN GITHUB**

### 1.1 Crear el repositorio
1. Ve a GitHub y crea un nuevo repositorio
2. Copia la URL del repositorio (ej: `https://github.com/tu-usuario/whatsapp-api.git`)
3. Sube todo el código de este proyecto al repositorio

```bash
# En tu máquina local (si no está en GitHub aún)
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/TU_USUARIO/TU_REPO.git
git push -u origin main
```

### 1.2 Configurar variables importantes
Antes de hacer deployment, actualiza estos archivos con tus datos reales:

**server/.env.example:**
```bash
FRONTEND_URL=https://tu-dominio.com  # Tu dominio real
```

**server/deploy.sh (línea 21):**
```bash
GITHUB_REPO="https://github.com/TU_USUARIO/TU_REPO.git"
```

## **PASO 2: PREPARAR EL SERVIDOR UBUNTU**

### 2.1 Requisitos del servidor
- **Mínimo**: Ubuntu 20.04+, 2GB RAM, 2 CPU cores, 20GB disco
- **Recomendado**: Ubuntu 22.04 LTS, 4GB RAM, 4 CPU cores, 50GB SSD
- Acceso SSH con usuario sudo

### 2.2 Conectarse al servidor
```bash
# Conectarse via SSH
ssh root@TU_IP_SERVIDOR
# o
ssh tu-usuario@TU_IP_SERVIDOR
```

### 2.3 Preparación inicial
```bash
# Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# Instalar herramientas básicas
sudo apt install -y curl wget git unzip nano

# Verificar que Git esté instalado
git --version
```

## **PASO 3: INSTALACIÓN AUTOMÁTICA**

### 3.1 Instalación en un solo comando (RECOMENDADO)
```bash
# Opción 1: Instalación completa automática
curl -sSL https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/server/quick-start.sh | sudo bash

# Opción 2: Clonar manualmente y ejecutar
git clone https://github.com/TU_USUARIO/TU_REPO.git
cd TU_REPO
chmod +x server/*.sh
sudo ./server/quick-start.sh
```

### 3.2 Instalación manual paso a paso
```bash
# Si prefieres control total sobre cada paso:
git clone https://github.com/TU_USUARIO/TU_REPO.git
cd TU_REPO
chmod +x server/*.sh
sudo ./server/install.sh
sudo ./server/configure.sh
```

Este script automáticamente:
- ✅ Instala Node.js y npm
- ✅ Instala PM2 para gestión de procesos
- ✅ Instala Google Chrome (para WhatsApp Web)
- ✅ Instala y configura Nginx
- ✅ Configura el firewall UFW
- ✅ Instala y configura Fail2Ban (seguridad)
- ✅ Crea el usuario del sistema
- ✅ Configura directorios y permisos
- ✅ Configura logs y rotación
- ✅ Configura backups automáticos
- ✅ Aplica optimizaciones del sistema

## **PASO 4: CONFIGURACIÓN POST-INSTALACIÓN**

### 4.1 Configurar variables de entorno
```bash
# Editar el archivo de configuración
sudo nano /var/www/whatsapp-api/server/.env

# Configurar al menos estas variables:
FRONTEND_URL=https://tu-dominio.com
JWT_SECRET=tu-clave-secreta-muy-segura
LOG_LEVEL=info
```

### 4.2 Configurar el dominio (si tienes uno)
```bash
# Editar configuración de Nginx
sudo nano /etc/nginx/sites-available/whatsapp-api

# Cambiar 'localhost' por tu dominio
server_name tu-dominio.com www.tu-dominio.com;
```

### 4.3 Instalar SSL (si tienes dominio)
```bash
# Instalar Certbot
sudo apt install certbot python3-certbot-nginx

# Obtener certificado SSL GRATIS
sudo certbot --nginx -d tu-dominio.com -d www.tu-dominio.com

# Configurar renovación automática
sudo crontab -e
# Agregar esta línea:
0 12 * * * /usr/bin/certbot renew --quiet
```

## **PASO 5: INICIAR LA APLICACIÓN**

### 5.1 Copiar el código y instalar dependencias
```bash
# Ir al directorio del proyecto
cd /var/www/whatsapp-api

# Copiar el código (si no se hizo automáticamente)
sudo cp -r /ruta/del/repo/* .

# Instalar dependencias del servidor
cd server
sudo npm install --production

# Instalar dependencias del frontend
cd ..
sudo npm install

# Construir el frontend
sudo npm run build

# Configurar permisos
sudo chown -R www-data:www-data /var/www/whatsapp-api
```

### 5.2 Iniciar con PM2
```bash
cd /var/www/whatsapp-api/server

# Iniciar la aplicación
sudo pm2 start ecosystem.config.js

# Guardar configuración PM2
sudo pm2 save

# Configurar PM2 para inicio automático
sudo pm2 startup
```

## **PASO 6: VERIFICACIÓN**

### 6.1 Health check completo
```bash
# Verificar que todo funcione
sudo ./server/health-check.sh full
```

### 6.2 Verificar servicios
```bash
# Estado de PM2
sudo pm2 status

# Estado de Nginx
sudo systemctl status nginx

# Logs de la aplicación
sudo pm2 logs whatsapp-api

# Verificar puertos
sudo netstat -tlnp | grep -E ':(80|443|3000)'
```

### 6.3 Probar la aplicación
```bash
# Test local
curl http://localhost:3000/health

# Test externo (reemplaza con tu IP)
curl http://TU_IP_SERVIDOR/health
```

## **PASO 7: ACCESO A LA APLICACIÓN**

### 7.1 URLs de acceso
- **Aplicación principal**: `http://tu-ip-o-dominio/`
- **Panel de administración**: `http://tu-ip-o-dominio/admin`
- **Health check**: `http://tu-ip-o-dominio/health`
- **API**: `http://tu-ip-o-dominio/api/`

### 7.2 Credenciales por defecto
```
Usuario: admin
Contraseña: admin123
```

**⚠️ IMPORTANTE: Cambiar estas credenciales inmediatamente**

## **PASO 8: CONFIGURACIÓN DE SEGURIDAD**

### 8.1 Cambiar credenciales por defecto
```bash
# Acceder a la aplicación y cambiar:
# - Password del admin
# - JWT_SECRET en .env
# - Cualquier otra credencial por defecto
```

### 8.2 Configurar firewall
```bash
# El install.sh ya configuró UFW, pero verifica:
sudo ufw status

# Debe mostrar:
# 22/tcp (SSH) - ALLOW
# 80/tcp (HTTP) - ALLOW  
# 443/tcp (HTTPS) - ALLOW
```

## **ACTUALIZACIONES FUTURAS**

### Actualizar desde GitHub
```bash
# Para actualizar la aplicación
sudo ./server/update.sh manual

# Para rollback si hay problemas
sudo ./server/rollback.sh

# Para mantenimiento rutinario
sudo ./server/maintenance.sh
```

### Backups automáticos
El sistema ya está configurado para:
- ✅ Backups diarios automáticos
- ✅ Health checks cada 5 minutos
- ✅ Rotación de logs automática
- ✅ Alertas en caso de problemas

## **COMANDOS ÚTILES**

```bash
# Ver logs en tiempo real
sudo pm2 logs whatsapp-api --lines 100

# Reiniciar aplicación
sudo pm2 restart whatsapp-api

# Ver estado del sistema
sudo ./server/health-check.sh

# Ver métricas del servidor
htop
df -h
free -h

# Backup manual
sudo ./server/maintenance.sh backup
```

## **TROUBLESHOOTING**

### Si la aplicación no inicia:
```bash
# Verificar logs
sudo pm2 logs whatsapp-api

# Verificar proceso
sudo pm2 list

# Reiniciar PM2
sudo pm2 restart all
```

### Si Nginx no funciona:
```bash
# Verificar configuración
sudo nginx -t

# Reiniciar Nginx
sudo systemctl restart nginx

# Ver logs de Nginx
sudo tail -f /var/log/nginx/error.log
```

### Si Chrome falla:
```bash
# Reinstalar Chrome
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
sudo apt update
sudo apt install google-chrome-stable
```

## **SOPORTE**

Si tienes problemas:
1. Ejecuta `sudo ./server/health-check.sh full`
2. Revisa los logs con `sudo pm2 logs`
3. Verifica el estado con `sudo pm2 status`
4. Consulta `/var/log/whatsapp-api-*.log`

**¡Tu WhatsApp Multi-Session API está listo para producción!** 🚀