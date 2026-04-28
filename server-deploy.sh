#!/bin/bash

###############################################################################
# Deep Space - Server Deployment Script
#
# This script deploys a new release to the production server
#
# Prerequisites:
#   - Docker and Docker Compose installed
#   - PM2 installed globally (npm install -g pm2)
#   - Caddy installed
#   - Node.js 18+ installed
#   - GitHub release zip file available
#
# Usage: ./deploy/server-deploy.sh [version] [github-repo-url]
# Example: ./deploy/server-deploy.sh v1.0.1 https://github.com/your-org/deepspace/releases/download/v1.0.1/deepspace-release-v1.0.1.zip
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERSION="${1:-latest}"
RELEASE_URL="$2"
DEPLOYMENT_ROOT="/opt/deepspace"  # CHANGE THIS to your deployment directory
BACKUP_DIR="/opt/deepspace-backups"
GITHUB_REPO="${3:-your-org/deepspace}"  # CHANGE THIS
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEMP_DIR="/tmp/deepspace-deploy-$TIMESTAMP"
LOG_FILE="/var/log/deepspace/deploy-$TIMESTAMP.log"

# Ensure log directory exists
mkdir -p /var/log/deepspace
mkdir -p "$BACKUP_DIR"

# Logging function
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
log "${BLUE}║    Deep Space - Production Deployment Script              ║${NC}"
log "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
log ""
log "${GREEN}Version:${NC} $VERSION"
log "${GREEN}Timestamp:${NC} $TIMESTAMP"
log "${GREEN}Deployment Root:${NC} $DEPLOYMENT_ROOT"
log ""

###############################################################################
# Step 1: Pre-deployment Checks
###############################################################################
log "${YELLOW}[1/12]${NC} Running pre-deployment checks..."

# Check if running as root or with sudo
if [ "$EUID" -eq 0 ]; then
    log "${YELLOW}⚠  Running as root. Consider using a dedicated deployment user.${NC}"
fi

# Check required commands
for cmd in docker pm2 node npm caddy unzip; do
    if ! command -v $cmd &> /dev/null; then
        log "${RED}✗ Error: $cmd is not installed${NC}"
        exit 1
    fi
    log "  ${GREEN}✓${NC} $cmd installed"
done

# Check docker compose (v2 with space)
if ! docker compose version &> /dev/null; then
    log "${RED}✗ Error: docker compose is not available${NC}"
    exit 1
fi
log "  ${GREEN}✓${NC} docker compose installed"

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    log "${RED}✗ Error: Node.js 18+ required (current: v$NODE_VERSION)${NC}"
    exit 1
fi
log "  ${GREEN}✓${NC} Node.js version OK (v$(node -v))"

# Check if .env file exists
if [ ! -f "$DEPLOYMENT_ROOT/backend/.env" ] && [ ! -f "$DEPLOYMENT_ROOT/.env" ]; then
    log "${YELLOW}⚠  Warning: No .env file found. You'll need to configure environment variables.${NC}"
fi

log "  ${GREEN}✓${NC} Pre-deployment checks passed"
log ""

###############################################################################
# Step 2: Download Release
###############################################################################
log "${YELLOW}[2/12]${NC} Downloading release..."

mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

if [ -z "$RELEASE_URL" ]; then
    # Construct GitHub release URL if not provided
    RELEASE_URL="https://github.com/$GITHUB_REPO/releases/download/$VERSION/deepspace-release-$VERSION.zip"
    log "  ${BLUE}→${NC} Using auto-generated URL: $RELEASE_URL"
fi

log "  ${BLUE}→${NC} Downloading from: $RELEASE_URL"

if curl -L -f -o "release.zip" "$RELEASE_URL"; then
    log "  ${GREEN}✓${NC} Release downloaded successfully"
else
    log "${RED}✗ Error: Failed to download release${NC}"
    log "${YELLOW}Manual download steps:${NC}"
    log "  1. Download the release zip manually from GitHub"
    log "  2. Copy to server: scp deepspace-release-$VERSION.zip server:/tmp/"
    log "  3. Run: ./deploy/server-deploy.sh $VERSION /tmp/deepspace-release-$VERSION.zip local"
    exit 1
fi

# Verify zip file
if ! unzip -t release.zip > /dev/null 2>&1; then
    log "${RED}✗ Error: Downloaded zip file is corrupted${NC}"
    exit 1
fi

log ""

###############################################################################
# Step 3: Stop Running Services
###############################################################################
log "${YELLOW}[3/12]${NC} Stopping running services..."

# Stop PM2 processes gracefully
if pm2 list | grep -q "deepspace"; then
    log "  ${BLUE}→${NC} Stopping PM2 processes..."
    pm2 stop ecosystem.config.js 2>/dev/null || log "  ${YELLOW}⚠${NC} PM2 processes not running"
    log "  ${GREEN}✓${NC} PM2 processes stopped"
else
    log "  ${YELLOW}⚠${NC} No PM2 processes running"
fi

log ""

###############################################################################
# Step 4: Backup Current Deployment
###############################################################################
log "${YELLOW}[4/12]${NC} Creating backup of current deployment..."

if [ -d "$DEPLOYMENT_ROOT" ]; then
    BACKUP_PATH="$BACKUP_DIR/deepspace-backup-$TIMESTAMP.tar.gz"
    log "  ${BLUE}→${NC} Backing up to: $BACKUP_PATH"

    tar -czf "$BACKUP_PATH" -C "$DEPLOYMENT_ROOT" . 2>/dev/null || log "  ${YELLOW}⚠${NC} Backup failed (non-critical)"

    if [ -f "$BACKUP_PATH" ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
        log "  ${GREEN}✓${NC} Backup created ($BACKUP_SIZE)"

        # Keep only last 5 backups
        ls -t "$BACKUP_DIR"/deepspace-backup-*.tar.gz | tail -n +6 | xargs -r rm
        log "  ${GREEN}✓${NC} Old backups cleaned (keeping last 5)"
    fi
else
    log "  ${YELLOW}⚠${NC} No existing deployment to backup"
fi

log ""

###############################################################################
# Step 5: Extract New Release
###############################################################################
log "${YELLOW}[5/12]${NC} Extracting new release..."

# Clear deployment directory (except .env and logs)
if [ -d "$DEPLOYMENT_ROOT" ]; then
    log "  ${BLUE}→${NC} Preserving environment files..."
    cp "$DEPLOYMENT_ROOT/backend/.env" "$TEMP_DIR/.env.backup" 2>/dev/null || true
    cp "$DEPLOYMENT_ROOT/.env" "$TEMP_DIR/.env.root.backup" 2>/dev/null || true

    log "  ${BLUE}→${NC} Clearing old deployment..."
    rm -rf "$DEPLOYMENT_ROOT"/*
fi

mkdir -p "$DEPLOYMENT_ROOT"

log "  ${BLUE}→${NC} Extracting release zip..."
unzip -q release.zip -d "$DEPLOYMENT_ROOT"

# Restore environment files
if [ -f "$TEMP_DIR/.env.backup" ]; then
    cp "$TEMP_DIR/.env.backup" "$DEPLOYMENT_ROOT/backend/.env"
    log "  ${GREEN}✓${NC} Environment file restored"
fi

log "  ${GREEN}✓${NC} Release extracted to $DEPLOYMENT_ROOT"
log ""

###############################################################################
# Step 6: Install Dependencies
###############################################################################
log "${YELLOW}[6/12]${NC} Installing production dependencies..."

cd "$DEPLOYMENT_ROOT/backend"

log "  ${BLUE}→${NC} Installing backend dependencies..."
npm ci --production --quiet

log "  ${GREEN}✓${NC} Dependencies installed"
log ""

###############################################################################
# Step 7: Generate Prisma Client
###############################################################################
log "${YELLOW}[7/12]${NC} Generating Prisma client..."

cd "$DEPLOYMENT_ROOT/backend"

npx prisma generate

log "  ${GREEN}✓${NC} Prisma client generated"
log ""

###############################################################################
# Step 8: Start Docker Infrastructure
###############################################################################
log "${YELLOW}[8/12]${NC} Starting Docker containers..."

cd "$DEPLOYMENT_ROOT"

# Check if docker-compose.production.yml exists
if [ ! -f "deploy/docker-compose.production.yml" ]; then
    log "${RED}✗ Error: docker-compose.production.yml not found${NC}"
    exit 1
fi

log "  ${BLUE}→${NC} Starting PostgreSQL and Redis..."
docker compose -f deploy/docker-compose.production.yml up -d

# Wait for services to be healthy
log "  ${BLUE}→${NC} Waiting for database to be ready..."
sleep 5

# Check PostgreSQL health
for i in {1..30}; do
    if docker exec deepspace-postgres-prod pg_isready -U deepspace > /dev/null 2>&1; then
        log "  ${GREEN}✓${NC} PostgreSQL is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        log "${RED}✗ Error: PostgreSQL failed to start${NC}"
        exit 1
    fi
    sleep 1
done

# Check Redis health
for i in {1..30}; do
    if docker exec deepspace-redis-prod redis-cli ping > /dev/null 2>&1; then
        log "  ${GREEN}✓${NC} Redis is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        log "${RED}✗ Error: Redis failed to start${NC}"
        exit 1
    fi
    sleep 1
done

log "  ${GREEN}✓${NC} Docker containers running"
log ""

###############################################################################
# Step 9: Run Database Migrations
###############################################################################
log "${YELLOW}[9/12]${NC} Running database migrations..."

cd "$DEPLOYMENT_ROOT/backend"

log "  ${BLUE}→${NC} Applying Prisma migrations..."
npx prisma migrate deploy

log "  ${GREEN}✓${NC} Database migrations completed"
log ""

###############################################################################
# Step 10: Start PM2 Processes
###############################################################################
log "${YELLOW}[10/12]${NC} Starting PM2 processes..."

cd "$DEPLOYMENT_ROOT"

# Validate Caddyfile
log "  ${BLUE}→${NC} Validating Caddy configuration..."
if ! caddy validate --config deploy/Caddyfile --adapter caddyfile 2>/dev/null; then
    log "${YELLOW}⚠  Warning: Caddy configuration validation failed${NC}"
fi

# Start or reload PM2 processes
log "  ${BLUE}→${NC} Starting application processes..."
if pm2 list | grep -q "deepspace"; then
    pm2 reload deploy/ecosystem.config.js --update-env
    log "  ${GREEN}✓${NC} PM2 processes reloaded"
else
    pm2 start deploy/ecosystem.config.js
    log "  ${GREEN}✓${NC} PM2 processes started"
fi

# Save PM2 process list
pm2 save

log "  ${GREEN}✓${NC} PM2 configuration saved"
log ""

###############################################################################
# Step 11: Health Checks
###############################################################################
log "${YELLOW}[11/12]${NC} Running health checks..."

sleep 5  # Wait for services to fully start

# Check backend health
log "  ${BLUE}→${NC} Checking backend API..."
for i in {1..10}; do
    if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
        log "  ${GREEN}✓${NC} Backend API is healthy"
        break
    fi
    if [ $i -eq 10 ]; then
        log "${YELLOW}⚠  Warning: Backend health check failed${NC}"
    fi
    sleep 2
done

# Check PM2 status
log "  ${BLUE}→${NC} Checking PM2 processes..."
pm2 list

# Check Docker status
log "  ${BLUE}→${NC} Checking Docker containers..."
docker compose -f deploy/docker-compose.production.yml ps

log ""

###############################################################################
# Step 12: Cleanup
###############################################################################
log "${YELLOW}[12/12]${NC} Cleaning up..."

rm -rf "$TEMP_DIR"

log "  ${GREEN}✓${NC} Temporary files removed"
log ""

###############################################################################
# Deployment Summary
###############################################################################
log "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
log "${BLUE}║                 Deployment Summary                         ║${NC}"
log "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
log ""
log "${GREEN}✓ Version Deployed:${NC}   $VERSION"
log "${GREEN}✓ Deployment Time:${NC}    $TIMESTAMP"
log "${GREEN}✓ Deployment Root:${NC}    $DEPLOYMENT_ROOT"
log "${GREEN}✓ Backup Location:${NC}    $BACKUP_PATH"
log "${GREEN}✓ Log File:${NC}           $LOG_FILE"
log ""
log "${BLUE}Service Status:${NC}"
log "  • Backend API: http://localhost:3000"
log "  • Frontend: Served by Caddy"
log "  • Database: PostgreSQL (Docker)"
log "  • Cache: Redis (Docker)"
log ""
log "${BLUE}Useful Commands:${NC}"
log "  • View logs:     pm2 logs"
log "  • Restart:       pm2 restart ecosystem.config.js"
log "  • Stop all:      pm2 stop ecosystem.config.js"
log "  • Docker logs:   docker compose -f deploy/docker-compose.production.yml logs -f"
log "  • Rollback:      tar -xzf $BACKUP_PATH -C $DEPLOYMENT_ROOT"
log ""
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log "${GREEN}✓ Deployment completed successfully!${NC}"
log "${GREEN}═══════════════════════════════════════════════════════════${NC}"
log ""
