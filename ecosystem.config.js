/**
 * Deep Space - PM2 Ecosystem Configuration
 *
 * This file configures PM2 process management for production deployment
 *
 * Usage:
 *   pm2 start ecosystem.config.js
 *   pm2 reload ecosystem.config.js
 *   pm2 stop ecosystem.config.js
 *   pm2 delete ecosystem.config.js
 *
 * Documentation: https://pm2.keymetrics.io/docs/usage/application-declaration/
 */

module.exports = {
  apps: [
    /**
     * Backend API Server
     */
    {
      name: 'deepspace-backend',
      script: './backend/dist/index.js',
      cwd: '/opt/deepspace',  // Change to your deployment directory

      // Instance configuration
      instances: 1,  // Can be increased for clustering
      exec_mode: 'fork',  // Use 'cluster' for multiple instances

      // Environment variables
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },

      // Auto-restart configuration
      watch: false,  // Don't watch files in production
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      max_memory_restart: '1G',

      // Startup configuration
      wait_ready: true,
      listen_timeout: 10000,
      kill_timeout: 5000,

      // Logging
      log_file: '/var/log/deepspace/backend-combined.log',
      out_file: '/var/log/deepspace/backend-out.log',
      error_file: '/var/log/deepspace/backend-error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,

      // Advanced options
      time: true,  // Prefix logs with timestamp

      // Restart on file changes (dev only)
      ignore_watch: [
        'node_modules',
        'logs',
        '*.log',
        '.git'
      ],

      // Graceful shutdown
      shutdown_with_message: true,

      // Environment-specific config
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      env_staging: {
        NODE_ENV: 'staging',
        PORT: 3001,
      },
    },

    /**
     * Caddy Web Server (Frontend + Reverse Proxy)
     */
    {
      name: 'deepspace-caddy',
      script: 'caddy',
      args: 'run --config ./deploy/Caddyfile --adapter caddyfile',
      cwd: '/opt/deepspace',  // Change to your deployment directory

      // Instance configuration
      instances: 1,
      exec_mode: 'fork',

      // Interpreter
      interpreter: 'none',  // Caddy is a binary, not a script

      // Auto-restart configuration
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      max_memory_restart: '512M',

      // Startup configuration
      wait_ready: false,
      kill_timeout: 5000,

      // Logging
      log_file: '/var/log/deepspace/caddy-combined.log',
      out_file: '/var/log/deepspace/caddy-out.log',
      error_file: '/var/log/deepspace/caddy-error.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,

      // Advanced options
      time: true,

      // Environment
      env: {
        NODE_ENV: 'production',
      },
    },
  ],

  /**
   * Deployment Configuration
   */
  deploy: {
    production: {
      user: 'deploy',  // Change to your deployment user
      host: ['your-server.com'],  // Change to your server
      ref: 'origin/main',
      repo: 'https://github.com/your-org/deepspace.git',  // Change to your repo
      path: '/opt/deepspace',
      'post-deploy': './deploy/server-deploy.sh',
      env: {
        NODE_ENV: 'production',
      },
    },
  },
};

/**
 * PM2 Commands Reference:
 *
 * Start all apps:
 *   pm2 start ecosystem.config.js
 *
 * Restart all apps:
 *   pm2 restart ecosystem.config.js
 *
 * Reload apps (zero-downtime):
 *   pm2 reload ecosystem.config.js
 *
 * Stop all apps:
 *   pm2 stop ecosystem.config.js
 *
 * Delete all apps:
 *   pm2 delete ecosystem.config.js
 *
 * Monitor apps:
 *   pm2 monit
 *
 * View logs:
 *   pm2 logs
 *   pm2 logs deepspace-backend
 *   pm2 logs deepspace-caddy
 *
 * Save process list (auto-restart on reboot):
 *   pm2 save
 *
 * Setup startup script:
 *   pm2 startup
 *   (run the command it outputs with sudo)
 *   pm2 save
 *
 * View app details:
 *   pm2 show deepspace-backend
 *   pm2 show deepspace-caddy
 *
 * Flush logs:
 *   pm2 flush
 *
 * Update PM2:
 *   pm2 update
 */

/**
 * Production Checklist:
 *
 * 1. ✓ Update 'cwd' paths to your actual deployment directory
 * 2. ✓ Update 'user', 'host', 'repo' in deploy config
 * 3. ✓ Create log directory: mkdir -p /var/log/deepspace
 * 4. ✓ Set proper permissions: chown -R deploy:deploy /var/log/deepspace
 * 5. ✓ Configure environment variables in backend/.env
 * 6. ✓ Install Caddy: https://caddyserver.com/docs/install
 * 7. ✓ Test Caddyfile: caddy validate --config deploy/Caddyfile
 * 8. ✓ Setup PM2 startup: pm2 startup && pm2 save
 * 9. ✓ Configure firewall to allow ports 80, 443, 3000
 * 10. ✓ Set up SSL certificates (Caddy does this automatically)
 */
