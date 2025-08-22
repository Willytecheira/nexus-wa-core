const crypto = require('crypto');

// Generate a secure JWT secret if not provided
const generateSecureSecret = () => {
  return crypto.randomBytes(64).toString('hex');
};

// Validate JWT secret strength
const validateJWTSecret = (secret) => {
  if (!secret || secret === 'your-super-secret-jwt-key' || secret === 'your-super-secret-jwt-key-change-this-in-production-please') {
    console.warn('⚠️  WARNING: Using default or weak JWT secret in production!');
    console.warn('   Generate a secure secret with: node -e "console.log(require(\'crypto\').randomBytes(64).toString(\'hex\'))"');
    return false;
  }
  
  if (secret.length < 32) {
    console.warn('⚠️  WARNING: JWT secret is too short. Minimum 32 characters recommended.');
    return false;
  }
  
  return true;
};

// Get secure JWT secret
const getJWTSecret = () => {
  const secret = process.env.JWT_SECRET;
  
  if (process.env.NODE_ENV === 'production') {
    if (!validateJWTSecret(secret)) {
      console.error('❌ CRITICAL: Invalid JWT secret in production. Application will not start.');
      console.error('   Set JWT_SECRET environment variable to a secure random string.');
      process.exit(1);
    }
  } else {
    // Development: use provided secret or generate one
    if (!secret || secret === 'your-super-secret-jwt-key' || secret === 'your-super-secret-jwt-key-change-this-in-production-please') {
      console.log('🔧 Development: Using generated JWT secret');
      return generateSecureSecret();
    }
  }
  
  return secret;
};

// CORS configuration
const getCORSConfig = () => {
  const corsOrigins = process.env.CORS_ORIGINS;
  
  if (process.env.NODE_ENV === 'production') {
    if (!corsOrigins) {
      console.error('❌ CRITICAL: CORS_ORIGINS not configured for production');
      process.exit(1);
    }
    
    return {
      origin: corsOrigins.split(',').map(origin => origin.trim()),
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      maxAge: 86400 // 24 hours
    };
  }
  
  // Development: Allow localhost
  return {
    origin: ['http://localhost:5173', 'http://localhost:3000', 'http://127.0.0.1:5173'],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
  };
};

// Rate limiting configuration
const getRateLimitConfig = () => ({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 900000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || (process.env.NODE_ENV === 'production' ? 50 : 100),
  message: { error: 'Too many requests, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
  trustProxy: process.env.NODE_ENV === 'production'
});

module.exports = {
  generateSecureSecret,
  validateJWTSecret,
  getJWTSecret,
  getCORSConfig,
  getRateLimitConfig
};