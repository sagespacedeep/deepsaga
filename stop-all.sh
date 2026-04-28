#!/bin/bash

###############################################################################
# Deep Space - Stop All Services
#
# Stops PM2 processes and Docker containers
#
# Usage: ./deploy/stop-all.sh
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Deep Space - Stopping All Services${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Stop PM2 processes
echo -e "${YELLOW}[1/2]${NC} Stopping PM2 processes..."

if pm2 list | grep -q "deepspace"; then
    pm2 stop ecosystem.config.js 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} PM2 processes stopped"
else
    echo -e "  ${YELLOW}⚠${NC} No PM2 processes running"
fi

# Step 2: Stop Docker containers
echo ""
echo -e "${YELLOW}[2/2]${NC} Stopping Docker containers..."
cd "$PROJECT_ROOT"

if [ -f "deploy/docker compose.production.yml" ]; then
    docker compose -f deploy/docker compose.production.yml stop
    echo -e "  ${GREEN}✓${NC} Docker containers stopped"
else
    echo -e "  ${YELLOW}⚠${NC} docker compose.production.yml not found"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ All services stopped successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Note:${NC} Docker containers are stopped but not removed."
echo -e "${BLUE}Data volumes are preserved.${NC}"
echo ""
echo -e "${BLUE}To completely remove containers:${NC}"
echo -e "  docker compose -f deploy/docker compose.production.yml down"
echo ""
echo -e "${BLUE}To restart services:${NC}"
echo -e "  ./deploy/start-all.sh"
echo ""
