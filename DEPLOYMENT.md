# Deep Space - Production Deployment Guide

Complete guide for deploying Deep Space cryptocurrency trading platform to production.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Initial Server Setup](#initial-server-setup)
- [First-Time Deployment](#first-time-deployment)
- [Update Deployment Workflow](#update-deployment-workflow)
- [Maintenance Operations](#maintenance-operations)
- [Monitoring & Logging](#monitoring--logging)
- [Backup & Recovery](#backup--recovery)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

---

## Overview

Deep Space uses a modern deployment stack:

- **PM2**: Process manager for Node.js applications with auto-restart
- **Docker**: Containerized PostgreSQL and Redis infrastructure
- **Caddy**: Automatic HTTPS reverse proxy and static file server
- **GitHub Releases**: Versioned zip file deployment distribution

### Deployment Philosophy

1. **Build locally** → Create production-ready zip
2. **Upload to GitHub** → Version control and distribution
3. **Pull on server** → Download and deploy
4. **Zero-downtime** → PM2 graceful reload

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Production Server                      │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   Caddy (Port 80/443)                   │ │
│  │  • Automatic HTTPS (Let's Encrypt)                      │ │
│  │  • Serves frontend static files                         │ │
│  │  • Reverse proxy /api/* → Backend                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                              ↓                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           PM2 Process Manager (Auto-restart)            │ │
│  ├─────────────────────────────────────────────────────────┤ │
│  │  deepspace-backend  │  Node.js API (Port 3000)          │ │
│  │  deepspace-caddy    │  Caddy Server Process             │ │
│  └────────────────────────────────────────────────────────┘ │
│                              ↓                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Docker Containers                           │ │
│  ├─────────────────────────────────────────────────────────┤ │
│  │  PostgreSQL 15      │  Port 5432 (persistent volumes)   │ │
│  │  Redis 7            │  Port 6379 (persistent volumes)   │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  Backend Services                        │ │
│  ├─────────────────────────────────────────────────────────┤ │
│  │  • JWT Authentication                                    │ │
│  │  • HD Wallet Management (BIP39/BIP44)                   │ │
│  │  • Base Blockchain Integration                           │ │
│  │  • Avantis Perpetuals Trading                            │ │
│  │  • P2P Marketplace & Escrow                              │ │
│  │  • Investment Vault (Custodial)                          │ │
│  │  • Referral System                                       │ │
│  │  • Notification Service                                  │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Server Requirements

**Minimum Specifications:**
- **OS**: Ubuntu 20.04 LTS or newer (or similar Linux distribution)
- **CPU**: 2 cores
- **RAM**: 4GB
- **Storage**: 40GB SSD
- **Network**: Public IP address with ports 80, 443 accessible

**Recommended Specifications:**
- **CPU**: 4+ cores
- **RAM**: 8GB+
- **Storage**: 80GB+ SSD
- **Network**: 1Gbps+ bandwidth

### Required Software

Install the following on your production server:

#### 1. Node.js (v18+)

```bash
# Using NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node -v  # Should be v18.x or higher
npm -v
```

#### 2. Docker & Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

#### 3. PM2 (Process Manager)

```bash
# Install PM2 globally
sudo npm install -g pm2

# Verify installation
pm2 --version
```

#### 4. Caddy Web Server

```bash
# Install Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

# Verify installation
caddy version
```

### DNS Configuration

Before deployment, ensure DNS is configured:

1. **A Record**: Point your domain to your server's IP
   ```
   your-domain.com → 123.45.67.89
   www.your-domain.com → 123.45.67.89
   ```

2. **Verify DNS propagation**:
   ```bash
   dig your-domain.com
   nslookup your-domain.com
   ```

3. **Wait for propagation** (can take up to 24 hours)

### Firewall Configuration

```bash
# Open required ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (for Let's Encrypt)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable

# Verify firewall rules
sudo ufw status
```

---

## Initial Server Setup

### 1. Create Deployment User

```bash
# Create dedicated deployment user
sudo adduser deploy
sudo usermod -aG sudo deploy
sudo usermod -aG docker deploy

# Switch to deployment user
su - deploy
```

### 2. Create Directory Structure

```bash
# Create deployment directories
sudo mkdir -p /opt/deepspace
sudo chown -R deploy:deploy /opt/deepspace
sudo mkdir -p /var/log/deepspace
sudo chown -R deploy:deploy /var/log/deepspace
sudo mkdir -p /opt/deepspace-backups
sudo chown -R deploy:deploy /opt/deepspace-backups

# Create log directory structure
mkdir -p /var/log/deepspace
mkdir -p /var/log/caddy
```

### 3. Configure PM2 Startup

```bash
# Setup PM2 to start on system boot
pm2 startup

# This will output a command like:
# sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u deploy --hp /home/deploy

# Run that command with sudo
```

### 4. Configure Docker to Start on Boot

```bash
# Enable Docker service
sudo systemctl enable docker

# Verify Docker starts on boot
sudo systemctl is-enabled docker
```

---

## First-Time Deployment

### Step 1: Prepare Release (Local Machine)

On your development machine:

```bash
# Navigate to project root
cd "/path/to/stitch (2)"

# Run the preparation script
./scripts/prepare-release.sh v1.0.0

# This will:
# - Build backend (TypeScript → JavaScript)
# - Build frontend (React → static files)
# - Generate Prisma client
# - Create deepspace-release-v1.0.0.zip
```

### Step 2: Upload to GitHub

1. Go to your GitHub repository
2. Create a new release: **Releases → Draft a new release**
3. Tag version: `v1.0.0`
4. Upload `deepspace-release-v1.0.0.zip`
5. Publish release

### Step 3: Initial Server Configuration

SSH into your production server:

```bash
ssh deploy@your-server-ip
cd /opt/deepspace
```

Copy deployment files to server (one-time):

```bash
# Option A: Clone just the deploy folder from GitHub
git clone --depth 1 --filter=blob:none --sparse https://github.com/your-org/deepspace.git temp-repo
cd temp-repo
git sparse-checkout set deploy
cp -r deploy/* /opt/deepspace/
cd /opt/deepspace
rm -rf temp-repo

# Option B: Manually copy files via SCP from your local machine
# scp -r "/path/to/stitch (2)/deploy" deploy@your-server:/opt/deepspace/
```

### Step 4: Configure Environment

```bash
cd /opt/deepspace

# Run interactive environment setup
./deploy/setup-env.sh

# This will guide you through:
# - Domain configuration
# - Database credentials
# - JWT secrets (auto-generated)
# - Wallet configuration
# - Email (SMTP) settings
```

**Important**: After running `setup-env.sh`, manually update these values in `backend/.env`:

```bash
nano backend/.env

# Update:
# - NEAR_INTENT_API_KEY
# - MASTER_SEED_MNEMONIC (BIP39 phrase)
# - TREASURY_WALLET_ADDRESS and TREASURY_WALLET_PRIVATE_KEY
# - ESCROW_WALLET_ADDRESS and ESCROW_WALLET_PRIVATE_KEY
```

### Step 5: Update Configuration Files

Update deployment paths in configuration files:

**1. Edit `deploy/ecosystem.config.js`:**

```bash
nano deploy/ecosystem.config.js

# Change:
cwd: '/opt/deepspace'  # Your actual deployment path

# Change in deploy config:
user: 'deploy'
host: ['your-domain.com']
repo: 'https://github.com/your-org/deepspace.git'
```

**2. Edit `deploy/Caddyfile`:**

```bash
nano deploy/Caddyfile

# Change:
your-domain.com www.your-domain.com {
  email admin@your-domain.com
  root * /opt/deepspace/frontend/dist
  # ...
}
```

**3. Edit `deploy/docker-compose.production.yml`:**

```bash
# Optionally create .env file for Docker Compose
nano deploy/.env

# Add:
POSTGRES_USER=deepspace
POSTGRES_PASSWORD=your-strong-password
POSTGRES_DB=deepspace
REDIS_PASSWORD=your-redis-password
```

### Step 6: Run First Deployment

```bash
cd /opt/deepspace

# Deploy the release
./deploy/server-deploy.sh v1.0.0 https://github.com/your-org/deepspace/releases/download/v1.0.0/deepspace-release-v1.0.0.zip

# This will:
# 1. Download and extract release
# 2. Install dependencies
# 3. Start Docker (PostgreSQL + Redis)
# 4. Run database migrations
# 5. Start PM2 processes (backend + Caddy)
# 6. Run health checks
```

### Step 7: Verify Deployment

```bash
# Run health checks
./deploy/health-check.sh

# Check PM2 status
pm2 status

# Check Docker containers
docker ps

# View logs
./deploy/logs.sh

# Test API
curl http://localhost:3000/health

# Test HTTPS (after DNS propagates)
curl https://your-domain.com
```

### Step 8: Save PM2 Process List

```bash
# Save PM2 processes for auto-restart on reboot
pm2 save
```

---

## Update Deployment Workflow

### Local Machine (Development)

```bash
# 1. Make your code changes
# 2. Test locally
# 3. Commit changes (optional)

# 4. Prepare new release
./scripts/prepare-release.sh v1.0.1

# 5. Upload deepspace-release-v1.0.1.zip to GitHub Releases
```

### Production Server

```bash
# SSH into server
ssh deploy@your-server-ip
cd /opt/deepspace

# Deploy the new version
./deploy/server-deploy.sh v1.0.1 https://github.com/your-org/deepspace/releases/download/v1.0.1/deepspace-release-v1.0.1.zip

# Or if URL follows pattern, just version:
./deploy/server-deploy.sh v1.0.1

# The script will:
# - Stop PM2 processes gracefully
# - Backup current deployment
# - Extract new release
# - Install dependencies
# - Run migrations
# - Restart services
# - Verify health

# Verify deployment
./deploy/health-check.sh
```

---

## Maintenance Operations

### Start/Stop/Restart Services

```bash
# Start all services
./deploy/start-all.sh

# Stop all services
./deploy/stop-all.sh

# Restart all services (zero-downtime reload)
./deploy/restart-all.sh

# Restart specific service
pm2 restart deepspace-backend
pm2 restart deepspace-caddy
```

### View Logs

```bash
# Interactive log viewer
./deploy/logs.sh

# Or directly:
pm2 logs                    # All PM2 logs
pm2 logs deepspace-backend  # Backend logs only
pm2 logs deepspace-caddy    # Caddy logs only

# Docker logs
docker-compose -f deploy/docker-compose.production.yml logs -f postgres
docker-compose -f deploy/docker-compose.production.yml logs -f redis

# System logs
tail -f /var/log/deepspace/app.log
tail -f /var/log/caddy/access.log
```

### Database Operations

```bash
# Access PostgreSQL
docker exec -it deepspace-postgres-prod psql -U deepspace -d deepspace

# Run migrations manually
cd /opt/deepspace/backend
npx prisma migrate deploy

# View migration status
npx prisma migrate status

# Create database backup
docker exec deepspace-postgres-prod pg_dump -U deepspace deepspace > backup-$(date +%Y%m%d).sql

# Restore database backup
docker exec -i deepspace-postgres-prod psql -U deepspace deepspace < backup-20260428.sql
```

### Redis Operations

```bash
# Access Redis CLI
docker exec -it deepspace-redis-prod redis-cli

# Inside Redis CLI:
AUTH your-redis-password
INFO
DBSIZE
KEYS *
FLUSHALL  # WARNING: Clears all data!
```

---

## Monitoring & Logging

### PM2 Monitoring

```bash
# Real-time monitoring
pm2 monit

# Process list
pm2 list

# Detailed info for a process
pm2 show deepspace-backend

# Memory and CPU usage
pm2 describe deepspace-backend

# Flush logs
pm2 flush
```

### Docker Monitoring

```bash
# Container stats
docker stats

# Container health
docker ps
docker inspect deepspace-postgres-prod
docker inspect deepspace-redis-prod

# Disk usage
docker system df

# Clean up unused resources
docker system prune -a
```

### System Monitoring

```bash
# Disk space
df -h

# Memory usage
free -h

# CPU usage
htop  # or top

# Network connections
netstat -tulpn | grep LISTEN

# Check open files
lsof -i :3000
lsof -i :80
lsof -i :443
```

### Log Rotation

Configure logrotate for Deep Space logs:

```bash
sudo nano /etc/logrotate.d/deepspace

# Add:
/var/log/deepspace/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 deploy deploy
    sharedscripts
    postrotate
        pm2 reloadLogs
    endscript
}

/var/log/caddy/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 deploy deploy
}
```

---

## Backup & Recovery

### Automated Backup Strategy

#### Database Backups

```bash
# Create daily backup script
nano /opt/deepspace/deploy/backup-database.sh

#!/bin/bash
BACKUP_DIR="/opt/deepspace-backups/database"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
docker exec deepspace-postgres-prod pg_dump -U deepspace deepspace | gzip > "$BACKUP_DIR/deepspace-db-$TIMESTAMP.sql.gz"
# Keep only last 30 days
find "$BACKUP_DIR" -name "deepspace-db-*.sql.gz" -mtime +30 -delete

chmod +x /opt/deepspace/deploy/backup-database.sh

# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /opt/deepspace/deploy/backup-database.sh
```

#### Application Backups

```bash
# Backups are automatically created during deployment
# Location: /opt/deepspace-backups/deepspace-backup-*.tar.gz

# Manual backup
cd /opt/deepspace
tar -czf /opt/deepspace-backups/manual-backup-$(date +%Y%m%d).tar.gz .
```

### Recovery Procedures

#### Rollback to Previous Version

```bash
# List available backups
ls -lh /opt/deepspace-backups/

# Stop services
./deploy/stop-all.sh

# Restore backup
cd /opt/deepspace
tar -xzf /opt/deepspace-backups/deepspace-backup-20260428_120000.tar.gz

# Start services
./deploy/start-all.sh

# Verify
./deploy/health-check.sh
```

#### Restore Database

```bash
# Stop backend to prevent connections
pm2 stop deepspace-backend

# Restore database
gunzip < /opt/deepspace-backups/database/deepspace-db-20260428_020000.sql.gz | \
  docker exec -i deepspace-postgres-prod psql -U deepspace deepspace

# Start backend
pm2 start deepspace-backend

# Verify
./deploy/health-check.sh
```

---

## Troubleshooting

### Common Issues

#### 1. Backend Won't Start

```bash
# Check logs
pm2 logs deepspace-backend --lines 100

# Common causes:
# - Database connection failed → Check DATABASE_URL in .env
# - Redis connection failed → Check REDIS_URL in .env
# - Port 3000 already in use → lsof -i :3000
# - Missing environment variables → Check .env file

# Restart with fresh logs
pm2 delete deepspace-backend
pm2 start deploy/ecosystem.config.js
```

#### 2. Database Connection Issues

```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Check PostgreSQL logs
docker logs deepspace-postgres-prod

# Test connection
docker exec deepspace-postgres-prod pg_isready -U deepspace

# Restart PostgreSQL
docker restart deepspace-postgres-prod
```

#### 3. Caddy HTTPS Issues

```bash
# Check Caddyfile syntax
caddy validate --config deploy/Caddyfile --adapter caddyfile

# Check Caddy logs
pm2 logs deepspace-caddy

# Verify DNS is pointing to server
dig your-domain.com

# Check firewall allows ports 80 and 443
sudo ufw status

# Restart Caddy
pm2 restart deepspace-caddy
```

#### 4. PM2 Processes Keep Restarting

```bash
# Check restart count
pm2 list

# View error logs
pm2 logs deepspace-backend --err --lines 50

# Common causes:
# - Unhandled exceptions → Check application logs
# - Memory limit exceeded → Increase max_memory_restart in ecosystem.config.js
# - Port conflicts → Check for other processes on port 3000

# Reset restart count
pm2 reset deepspace-backend
```

#### 5. Migration Failures

```bash
# Check migration status
cd /opt/deepspace/backend
npx prisma migrate status

# View failed migration details
npx prisma migrate resolve

# Reset migration (CAREFUL - dev only)
# npx prisma migrate reset

# Apply migrations manually
npx prisma migrate deploy
```

#### 6. Out of Disk Space

```bash
# Check disk usage
df -h

# Find large files
du -sh /* | sort -h

# Clean Docker
docker system prune -a --volumes

# Clean PM2 logs
pm2 flush

# Remove old backups
find /opt/deepspace-backups -mtime +30 -delete
```

### Debug Mode

```bash
# Enable debug logging
pm2 stop deepspace-backend

# Edit .env
nano /opt/deepspace/backend/.env
# Change: LOG_LEVEL=debug

pm2 start deepspace-backend
pm2 logs deepspace-backend
```

---

## Security Considerations

### 1. Environment Variables

- ✅ Never commit `.env` files to version control
- ✅ Use strong, randomly generated secrets (min 32 characters)
- ✅ Rotate JWT secrets regularly
- ✅ Store backups of `.env` in encrypted location

### 2. Wallet Security

- ✅ Use dedicated wallets for production (separate from testnet)
- ✅ Store private keys in hardware security module (HSM) or key vault
- ✅ Use multi-sig for treasury wallet
- ✅ Monitor wallet balances with alerts
- ✅ Never log private keys or mnemonics

### 3. Database Security

- ✅ Use strong PostgreSQL password
- ✅ Database only accessible from localhost (not exposed to internet)
- ✅ Enable PostgreSQL audit logging
- ✅ Encrypt backups
- ✅ Regular security updates

### 4. API Security

- ✅ Rate limiting enabled (configured in `.env`)
- ✅ CORS properly configured for your domain only
- ✅ Helmet security headers enabled
- ✅ Input validation with Zod
- ✅ SQL injection prevention (Prisma parameterized queries)

### 5. HTTPS & TLS

- ✅ Caddy automatically handles HTTPS with Let's Encrypt
- ✅ TLS 1.2+ only
- ✅ HSTS header enabled (after SSL works)
- ✅ Certificate auto-renewal

### 6. Server Hardening

```bash
# Disable root SSH login
sudo nano /etc/ssh/sshd_config
# Set: PermitRootLogin no
sudo systemctl restart sshd

# Setup fail2ban
sudo apt install fail2ban
sudo systemctl enable fail2ban

# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Setup SSH key authentication (disable password auth)
# 1. Copy your public key to server
# 2. Edit /etc/ssh/sshd_config
# 3. Set: PasswordAuthentication no
```

### 7. Monitoring & Alerts

Set up alerts for:

- Failed login attempts
- High memory/CPU usage
- Database connection failures
- Low wallet balances
- Failed transactions
- API error rates > threshold

### 8. Secrets Management (Recommended)

For production, consider using a secrets manager:

- **HashiCorp Vault**: Self-hosted secrets management
- **AWS Secrets Manager**: AWS-hosted solution
- **Azure Key Vault**: Azure-hosted solution

---

## Performance Optimization

### Database Optimization

```sql
-- Add indexes for frequently queried fields
-- Connect to database and run:

CREATE INDEX idx_users_email ON "User"(email);
CREATE INDEX idx_transactions_user ON "Transaction"("userId");
CREATE INDEX idx_positions_user ON "AvantisPosition"("userId");

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM "User" WHERE email = 'test@example.com';
```

### Redis Optimization

```bash
# Edit docker-compose.production.yml
# Adjust maxmemory based on your server
maxmemory 1gb
maxmemory-policy allkeys-lru
```

### PM2 Clustering (for higher traffic)

```javascript
// Edit deploy/ecosystem.config.js
{
  name: 'deepspace-backend',
  script: './backend/dist/index.js',
  instances: 'max',  // Use all CPU cores
  exec_mode: 'cluster',  // Enable clustering
  // ...
}
```

---

## Appendix

### Quick Reference Commands

```bash
# Service Management
./deploy/start-all.sh         # Start all services
./deploy/stop-all.sh          # Stop all services
./deploy/restart-all.sh       # Restart all services
./deploy/logs.sh              # View logs
./deploy/health-check.sh      # Run health checks

# PM2 Commands
pm2 list                      # List processes
pm2 logs                      # View logs
pm2 monit                     # Real-time monitoring
pm2 restart all               # Restart all
pm2 save                      # Save process list

# Docker Commands
docker ps                     # List containers
docker stats                  # Resource usage
docker logs [container]       # View logs
docker restart [container]    # Restart container

# Database Commands
npx prisma migrate deploy     # Run migrations
npx prisma migrate status     # Check migration status
npx prisma studio             # Open database GUI (dev only)
```

### File Locations

```
/opt/deepspace/                          # Main deployment directory
├── backend/                             # Backend application
│   ├── dist/                            # Compiled JavaScript
│   ├── prisma/                          # Database schema & migrations
│   └── .env                             # Environment variables
├── frontend/                            # Frontend static files
│   └── dist/                            # Built React app
└── deploy/                              # Deployment scripts
    ├── ecosystem.config.js              # PM2 config
    ├── docker-compose.production.yml    # Docker config
    ├── Caddyfile                        # Caddy config
    ├── server-deploy.sh                 # Deployment script
    └── *.sh                             # Utility scripts

/var/log/deepspace/                      # Application logs
/opt/deepspace-backups/                  # Backup storage
```

### Support & Documentation

- **Backend API Docs**: `http://your-domain.com/api/docs` (if configured)
- **Prisma Docs**: https://www.prisma.io/docs
- **PM2 Docs**: https://pm2.keymetrics.io/docs
- **Caddy Docs**: https://caddyserver.com/docs
- **Docker Docs**: https://docs.docker.com

---

**Last Updated**: January 2025
**Version**: 1.0.0

For issues or questions, please contact your system administrator or open an issue on GitHub.
