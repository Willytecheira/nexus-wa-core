module.exports = {
  apps: [{
    name: 'whatsapp-api',
    script: 'server.js',
    cwd: '/var/www/whatsapp-api/server',
    instances: 1,
    exec_mode: 'fork', // Use fork mode for WhatsApp Web sessions
    watch: false,
    max_memory_restart: '2G',
    min_uptime: '10s',
    max_restarts: 5,
    autorestart: true,
    restart_delay: 4000,
    
    // Environment variables
    env: {
      NODE_ENV: 'production',
      PORT: 80,
      LOG_LEVEL: 'info'
    },
    
    // Logging
    log_file: './logs/combined.log',
    out_file: './logs/out.log',
    error_file: './logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    
    // Advanced PM2 options
    kill_timeout: 5000,
    listen_timeout: 8000,
    
    // Health monitoring
    health_check_grace_period: 3000,
    
    // Process management
    ignore_watch: [
      'node_modules',
      'logs',
      'uploads',
      'qr',
      'sessions',
      'database'
    ],
    
    // Auto-restart conditions
    node_args: [
      '--max-old-space-size=2048'
    ]
  }],

  deploy: {
    production: {
      user: 'ubuntu',
      host: ['your-server-ip'],
      ref: 'origin/main',
      repo: process.env.GITHUB_REPO || 'git@github.com:yourusername/whatsapp-multi-session-api.git',
      path: '/var/www/whatsapp-api',
      'pre-deploy-local': '',
      'post-deploy': 'cd server && npm install --production && pm2 reload ecosystem.config.js --env production',
      'pre-setup': '',
      'ssh_options': 'StrictHostKeyChecking=no'
    }
  }
};