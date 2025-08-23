#!/usr/bin/env node

// Quick diagnostic script to check QR setup
const fs = require('fs');
const path = require('path');

console.log('🔍 Checking QR setup...');

// Check if QR directory exists
const qrDir = path.join(__dirname, 'qr');
console.log(`QR Directory: ${qrDir}`);

if (fs.existsSync(qrDir)) {
    console.log('✅ QR directory exists');
    const stats = fs.statSync(qrDir);
    console.log(`Permissions: ${stats.mode.toString(8)}`);
    
    // List QR files
    const files = fs.readdirSync(qrDir);
    console.log(`Files in QR directory: ${files.length}`);
    files.forEach(file => console.log(`  - ${file}`));
} else {
    console.log('❌ QR directory does not exist');
    console.log('Creating QR directory...');
    fs.mkdirSync(qrDir, { recursive: true });
    console.log('✅ QR directory created');
}

// Check session directory
const sessionDir = path.join(__dirname, 'sessions');
console.log(`\nSession Directory: ${sessionDir}`);

if (fs.existsSync(sessionDir)) {
    console.log('✅ Session directory exists');
    const files = fs.readdirSync(sessionDir);
    console.log(`Session files: ${files.length}`);
} else {
    console.log('❌ Session directory does not exist');
    fs.mkdirSync(sessionDir, { recursive: true });
    console.log('✅ Session directory created');
}

console.log('\n🎯 Setup check complete!');