#!/bin/bash

###############################################################################
# Deep Space - Restart All Services
#
# Restarts PM2 processes and Docker containers
#
# Usage: ./deploy/restart-all.sh
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Deep Space - Restarting All Services${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Restart PM2 processes
echo -e "${YELLOW}[1/2]${NC} Restarting PM2 processes..."

if pm2 list | grep -q "deepspace"; then
    pm2 reload deploy/ecosystem.config.js --update-env
    echo -e "  ${GREEN}✓${NC} PM2 processes reloaded (zero-downtime)"
else
    pm2 start deploy/ecosystem.config.js
    echo -e "  ${GREEN}✓${NC} PM2 processes started"
fi

pm2 save

# Step 2: Restart Docker containers
echo ""
echo -e "${YELLOW}[2/2]${NC} Restarting Docker containers..."
cd "$PROJECT_ROOT"

if [ -f "deploy/docker compose.production.yml" ]; then
    docker compose -f deploy/docker compose.production.yml restart
    echo -e "  ${GREEN}✓${NC} Docker containers restarted"
else
    echo -e "  ${YELLOW}⚠${NC} docker compose.production.yml not found"
fi

# Wait for services to be ready
echo -e "  ${BLUE}→${NC} Waiting for services to be ready..."
sleep 5

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ All services restarted successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Service Status:${NC}"
pm2 list
echo ""
echo -e "${BLUE}Docker Status:${NC}"
docker compose -f deploy/docker compose.production.yml ps
echo ""
