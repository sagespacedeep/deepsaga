#!/bin/bash

###############################################################################
# Deep Space - Start All Services
#
# Starts Docker containers and PM2 processes
#
# Usage: ./deploy/start-all.sh
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
echo -e "${BLUE}    Deep Space - Starting All Services${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Start Docker containers
echo -e "${YELLOW}[1/3]${NC} Starting Docker containers..."
cd "$PROJECT_ROOT"

if [ -f "deploy/docker-compose.production.yml" ]; then
    docker-compose -f deploy/docker-compose.production.yml up -d
    echo -e "  ${GREEN}✓${NC} PostgreSQL and Redis started"
else
    echo -e "  ${YELLOW}⚠${NC} docker-compose.production.yml not found"
fi

# Wait for services to be ready
echo -e "  ${BLUE}→${NC} Waiting for services to be ready..."
sleep 5

# Step 2: Check Docker status
echo ""
echo -e "${YELLOW}[2/3]${NC} Checking Docker containers..."
docker-compose -f deploy/docker-compose.production.yml ps
echo ""

# Step 3: Start PM2 processes
echo -e "${YELLOW}[3/3]${NC} Starting PM2 processes..."

if [ -f "deploy/ecosystem.config.js" ]; then
    pm2 start deploy/ecosystem.config.js
    pm2 save
    echo -e "  ${GREEN}✓${NC} PM2 processes started"
else
    echo -e "  ${YELLOW}⚠${NC} ecosystem.config.js not found"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ All services started successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Service Status:${NC}"
pm2 list
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo -e "  • View logs:     pm2 logs"
echo -e "  • Stop all:      ./deploy/stop-all.sh"
echo -e "  • Restart all:   ./deploy/restart-all.sh"
echo ""
