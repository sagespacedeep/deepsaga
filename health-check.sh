#!/bin/bash

###############################################################################
# Deep Space - Health Check Script
#
# Verifies all services are running correctly
#
# Usage: ./deploy/health-check.sh
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

PASSED=0
FAILED=0
WARNINGS=0

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Deep Space - Health Check${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Check Docker Containers
###############################################################################
echo -e "${YELLOW}Checking Docker Containers...${NC}"
echo ""

# PostgreSQL
if docker ps | grep -q "deepspace-postgres-prod"; then
    if docker exec deepspace-postgres-prod pg_isready -U deepspace > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} PostgreSQL: Running and healthy"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} PostgreSQL: Running but not ready"
        ((FAILED++))
    fi
else
    echo -e "  ${RED}✗${NC} PostgreSQL: Container not running"
    ((FAILED++))
fi

# Redis
if docker ps | grep -q "deepspace-redis-prod"; then
    if docker exec deepspace-redis-prod redis-cli ping > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Redis: Running and healthy"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} Redis: Running but not responding"
        ((FAILED++))
    fi
else
    echo -e "  ${RED}✗${NC} Redis: Container not running"
    ((FAILED++))
fi

echo ""

###############################################################################
# Check PM2 Processes
###############################################################################
echo -e "${YELLOW}Checking PM2 Processes...${NC}"
echo ""

# Backend
if pm2 list | grep -q "deepspace-backend.*online"; then
    echo -e "  ${GREEN}✓${NC} Backend API: Running"
    ((PASSED++))
elif pm2 list | grep -q "deepspace-backend.*stopped"; then
    echo -e "  ${RED}✗${NC} Backend API: Stopped"
    ((FAILED++))
elif pm2 list | grep -q "deepspace-backend.*errored"; then
    echo -e "  ${RED}✗${NC} Backend API: Errored"
    ((FAILED++))
else
    echo -e "  ${YELLOW}⚠${NC} Backend API: Not found in PM2"
    ((WARNINGS++))
fi

# Caddy
if pm2 list | grep -q "deepspace-caddy.*online"; then
    echo -e "  ${GREEN}✓${NC} Caddy Server: Running"
    ((PASSED++))
elif pm2 list | grep -q "deepspace-caddy.*stopped"; then
    echo -e "  ${RED}✗${NC} Caddy Server: Stopped"
    ((FAILED++))
elif pm2 list | grep -q "deepspace-caddy.*errored"; then
    echo -e "  ${RED}✗${NC} Caddy Server: Errored"
    ((FAILED++))
else
    echo -e "  ${YELLOW}⚠${NC} Caddy Server: Not found in PM2"
    ((WARNINGS++))
fi

echo ""

###############################################################################
# Check API Endpoints
###############################################################################
echo -e "${YELLOW}Checking API Endpoints...${NC}"
echo ""

# Backend Health Endpoint
if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
    HEALTH_DATA=$(curl -s http://localhost:3000/health)
    echo -e "  ${GREEN}✓${NC} Backend API Health: OK"
    echo -e "     Response: $HEALTH_DATA"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} Backend API Health: Failed to respond"
    ((FAILED++))
fi

echo ""

###############################################################################
# Check Database Connection
###############################################################################
echo -e "${YELLOW}Checking Database Connection...${NC}"
echo ""

if docker exec deepspace-postgres-prod psql -U deepspace -d deepspace -c "SELECT 1;" > /dev/null 2>&1; then
    TABLE_COUNT=$(docker exec deepspace-postgres-prod psql -U deepspace -d deepspace -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';")
    echo -e "  ${GREEN}✓${NC} Database Connection: OK"
    echo -e "     Tables: $TABLE_COUNT"
    ((PASSED++))
else
    echo -e "  ${RED}✗${NC} Database Connection: Failed"
    ((FAILED++))
fi

echo ""

###############################################################################
# Check Disk Space
###############################################################################
echo -e "${YELLOW}Checking Disk Space...${NC}"
echo ""

DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "  ${GREEN}✓${NC} Disk Space: ${DISK_USAGE}% used"
    ((PASSED++))
elif [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "  ${YELLOW}⚠${NC} Disk Space: ${DISK_USAGE}% used (warning)"
    ((WARNINGS++))
else
    echo -e "  ${RED}✗${NC} Disk Space: ${DISK_USAGE}% used (critical)"
    ((FAILED++))
fi

echo ""

###############################################################################
# Check Memory Usage
###############################################################################
echo -e "${YELLOW}Checking Memory Usage...${NC}"
echo ""

if command -v free > /dev/null 2>&1; then
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100}')

    if [ "$MEM_USAGE" -lt 80 ]; then
        echo -e "  ${GREEN}✓${NC} Memory Usage: ${MEM_USAGE}%"
        ((PASSED++))
    elif [ "$MEM_USAGE" -lt 90 ]; then
        echo -e "  ${YELLOW}⚠${NC} Memory Usage: ${MEM_USAGE}% (warning)"
        ((WARNINGS++))
    else
        echo -e "  ${RED}✗${NC} Memory Usage: ${MEM_USAGE}% (critical)"
        ((FAILED++))
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Memory check skipped (free command not available)"
    ((WARNINGS++))
fi

echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Health Check Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC}   $FAILED"
echo ""

if [ "$FAILED" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ All systems operational!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    exit 0
elif [ "$FAILED" -eq 0 ]; then
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}⚠ System operational with warnings${NC}"
    echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}✗ System has failures - please investigate${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    exit 1
fi
