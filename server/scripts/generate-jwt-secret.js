#!/usr/bin/env node

// Generate a secure JWT secret for production use
const crypto = require('crypto');

const generateSecureSecret = () => {
  return crypto.randomBytes(64).toString('hex');
};

const secret = generateSecureSecret();

console.log('Generated secure JWT secret:');
console.log(secret);
console.log('\nAdd this to your .env file:');
console.log(`JWT_SECRET=${secret}`);
console.log('\n⚠️  Keep this secret secure and never commit it to version control!');

process.exit(0);