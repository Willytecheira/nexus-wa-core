// Production environment configuration
const fs = require('fs');
const path = require('path');

// Production validation checks
const validateProductionConfig = () => {
  const errors = [];
  
  // Check critical environment variables
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.includes('your-super-secret')) {
    errors.push('JWT_SECRET must be set to a secure random string in production');
  }
  
  if (!process.env.CORS_ORIGINS) {
    errors.push('CORS_ORIGINS must be configured for production');
  }
  
  // Check file permissions
  const criticalDirs = ['logs', 'uploads', 'qr', 'sessions', 'database'];
  for (const dir of criticalDirs) {
    const dirPath = path.join(__dirname, '..', dir);
    try {
      fs.accessSync(dirPath, fs.constants.W_OK);
    } catch (error) {
      errors.push(`Directory ${dir} is not writable`);
    }
  }
  
  // Check frontend build
  const frontendPath = path.join(__dirname, '..', '..', 'dist', 'index.html');
  if (!fs.existsSync(frontendPath)) {
    errors.push('Frontend build not found. Run npm run build first.');
  }
  
  if (errors.length > 0) {
    console.error('❌ Production configuration errors:');
    errors.forEach(error => console.error(`   - ${error}`));
    process.exit(1);
  }
  
  console.log('✅ Production configuration validated');
};

// Optimize production settings
const getProductionConfig = () => ({
  // Disable debug features
  enableDebugLogs: false,
  enableDetailedErrors: false,
  
  // Security settings
  sessionTimeout: 24 * 60 * 60 * 1000, // 24 hours
  maxConcurrentSessions: parseInt(process.env.WHATSAPP_MAX_SESSIONS) || 50,
  
  // Performance settings
  rateLimitStrict: true,
  enableCompression: true,
  enableCaching: true,
  
  // Monitoring
  enableMetrics: true,
  healthCheckInterval: parseInt(process.env.HEALTH_CHECK_INTERVAL) || 30000,
});

module.exports = {
  validateProductionConfig,
  getProductionConfig
};