# Deep Space - Quick Deployment Guide

**TL;DR**: Build → Zip → GitHub → Server Deploy

---

## 📦 Local Machine (Development)

### 1. Prepare Release

```bash
# Build and create release zip
./scripts/prepare-release.sh v1.0.1

# Output: deepspace-release-v1.0.1.zip
```

### 2. Upload to GitHub

1. Go to: **GitHub Repository → Releases → Draft new release**
2. **Tag**: `v1.0.1`
3. **Upload**: `deepspace-release-v1.0.1.zip`
4. **Publish**

---

## 🚀 Production Server

### First Time Setup (One-Time Only)

```bash
# Install requirements
sudo apt update
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
sudo npm install -g pm2
sudo apt install caddy

# Setup PM2 startup
pm2 startup
# Run the command it outputs

# Create directories
sudo mkdir -p /opt/deepspace /var/log/deepspace /opt/deepspace-backups
sudo chown -R $USER:$USER /opt/deepspace /var/log/deepspace /opt/deepspace-backups

# Copy deployment files (from repo)
cd /opt/deepspace
# ... copy deploy/ folder here ...

# Configure environment
./deploy/setup-env.sh

# Edit configuration files
nano deploy/ecosystem.config.js  # Update paths
nano deploy/Caddyfile           # Update domain
```

### Deploy/Update

```bash
cd /opt/deepspace

# Deploy new version
./deploy/server-deploy.sh v1.0.1

# Verify
./deploy/health-check.sh
```

---

## 🛠️ Common Operations

```bash
# Start services
./deploy/start-all.sh

# Stop services
./deploy/stop-all.sh

# Restart services
./deploy/restart-all.sh

# View logs
./deploy/logs.sh

# Health check
./deploy/health-check.sh

# PM2 status
pm2 list
pm2 logs

# Docker status
docker ps
docker-compose -f deploy/docker-compose.production.yml ps
```

---

## 📁 File Structure

```
/opt/deepspace/
├── backend/
│   ├── dist/           # Compiled backend
│   ├── prisma/         # Database schema
│   └── .env            # Environment variables
├── frontend/
│   └── dist/           # Built React app
└── deploy/
    ├── ecosystem.config.js
    ├── docker-compose.production.yml
    ├── Caddyfile
    ├── server-deploy.sh
    └── *.sh
```

---

## 🔧 Configuration Files to Update

1. **`deploy/ecosystem.config.js`**
   - `cwd`: `/opt/deepspace`
   - `user`, `host`, `repo`

2. **`deploy/Caddyfile`**
   - Domain: `your-domain.com`
   - Email: `admin@your-domain.com`
   - Root path: `/opt/deepspace/frontend/dist`

3. **`backend/.env`**
   - Domain, database credentials
   - JWT secrets (auto-generated)
   - Wallet private keys
   - SMTP configuration

---

## ✅ Deployment Checklist

- [ ] Server has Node.js 18+, Docker, PM2, Caddy installed
- [ ] DNS A record points to server IP
- [ ] Firewall allows ports 80, 443
- [ ] `.env` file configured with all secrets
- [ ] Wallet private keys added to `.env`
- [ ] Configuration files updated (domain, paths)
- [ ] PM2 startup configured (`pm2 startup`)
- [ ] First deployment successful
- [ ] Health checks passing
- [ ] HTTPS working (Caddy auto-SSL)

---

## 📖 Full Documentation

See [DEPLOYMENT.md](./DEPLOYMENT.md) for complete documentation including:
- Detailed server setup
- Architecture overview
- Security best practices
- Monitoring & logging
- Backup & recovery
- Troubleshooting guide

---

## 🆘 Quick Troubleshooting

**Backend won't start?**
```bash
pm2 logs deepspace-backend
# Check .env file, database connection
```

**Database connection failed?**
```bash
docker ps  # Check postgres is running
docker logs deepspace-postgres-prod
```

**Caddy HTTPS issues?**
```bash
pm2 logs deepspace-caddy
caddy validate --config deploy/Caddyfile
dig your-domain.com  # Verify DNS
```

**Services keep restarting?**
```bash
pm2 list  # Check restart count
pm2 logs --err  # View error logs
```

---

**Need Help?** Check full documentation in [DEPLOYMENT.md](./DEPLOYMENT.md)
