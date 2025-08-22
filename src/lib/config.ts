// Application configuration
export const config = {
  // API Configuration
  apiUrl: import.meta.env.VITE_API_URL || (
    window.location.hostname === 'localhost' 
      ? 'http://localhost:3000'
      : window.location.origin
  ),
  
  // Environment
  isDevelopment: import.meta.env.DEV,
  isProduction: import.meta.env.PROD,
  
  // Security
  tokenStorageKey: 'auth_token',
  userStorageKey: 'auth_user',
  
  // API timeouts (in ms)
  requestTimeout: 30000,
  
  // Rate limiting
  maxRetries: 3,
  retryDelay: 1000,
} as const;