// Environment configuration utility
const { validateProductionConfig } = require('../config/production');

const isDevelopment = process.env.NODE_ENV !== 'production';
const isProduction = process.env.NODE_ENV === 'production';

// Initialize environment
const initializeEnvironment = () => {
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  
  if (isProduction) {
    console.log('🔒 Running in production mode');
    validateProductionConfig();
  } else {
    console.log('🔧 Running in development mode');
  }
  
  // Log critical configuration (safely)
  console.log(`📡 Port: ${process.env.PORT || 3000}`);
  console.log(`🔐 JWT Secret: ${process.env.JWT_SECRET ? 'configured' : 'using default (development only)'}`);
  console.log(`🌐 CORS Origins: ${process.env.CORS_ORIGINS || 'localhost (development)'}`);
};

// Get environment-specific configuration
const getEnvironmentConfig = () => ({
  isDevelopment,
  isProduction,
  port: parseInt(process.env.PORT) || 3000,
  logLevel: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),
  enableDetailedLogs: isDevelopment,
  enableCors: true,
  enableRateLimit: true,
  maxFileSize: process.env.MAX_FILE_SIZE || '10mb',
  uploadPath: process.env.UPLOAD_PATH || './uploads',
});

module.exports = {
  initializeEnvironment,
  getEnvironmentConfig,
  isDevelopment,
  isProduction
};