#!/usr/bin/env node

// Pre-deployment security and configuration check script
const fs = require('fs');
const path = require('path');

const errors = [];
const warnings = [];

console.log('🔍 Running pre-deployment checks...\n');

// Check 1: JWT Secret
const jwtSecret = process.env.JWT_SECRET;
if (!jwtSecret || jwtSecret.includes('your-super-secret') || jwtSecret.length < 32) {
  errors.push('JWT_SECRET is not configured properly for production');
}

// Check 2: CORS Configuration
if (!process.env.CORS_ORIGINS) {
  errors.push('CORS_ORIGINS must be configured for production');
}

// Check 3: Frontend Build
const frontendBuild = path.join(__dirname, '..', '..', 'dist', 'index.html');
if (!fs.existsSync(frontendBuild)) {
  errors.push('Frontend build not found. Run: npm run build');
}

// Check 4: Database Directory
const dbDir = path.join(__dirname, '..', 'database');
if (!fs.existsSync(dbDir)) {
  warnings.push('Database directory does not exist');
}

// Check 5: Logs Directory
const logsDir = path.join(__dirname, '..', 'logs');
if (!fs.existsSync(logsDir)) {
  warnings.push('Logs directory does not exist');
}

// Check 6: Default Credentials
if (process.env.NODE_ENV === 'production') {
  warnings.push('Remember to change default admin credentials after deployment');
}

// Check 7: Environment Variables
const requiredEnvVars = ['NODE_ENV', 'PORT', 'JWT_SECRET'];
for (const envVar of requiredEnvVars) {
  if (!process.env[envVar]) {
    errors.push(`Environment variable ${envVar} is not set`);
  }
}

// Report Results
if (errors.length > 0) {
  console.log('❌ Critical Issues Found:');
  errors.forEach((error, index) => {
    console.log(`   ${index + 1}. ${error}`);
  });
  console.log('');
}

if (warnings.length > 0) {
  console.log('⚠️  Warnings:');
  warnings.forEach((warning, index) => {
    console.log(`   ${index + 1}. ${warning}`);
  });
  console.log('');
}

if (errors.length === 0 && warnings.length === 0) {
  console.log('✅ All checks passed! Ready for deployment.');
} else if (errors.length === 0) {
  console.log('✅ No critical issues found. Review warnings before deployment.');
} else {
  console.log('❌ Deployment blocked due to critical issues.');
  process.exit(1);
}

process.exit(0);