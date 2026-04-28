#!/bin/bash

###############################################################################
# Deep Space - View Logs
#
# Interactive script to view logs from PM2 or Docker
#
# Usage: ./deploy/logs.sh [service]
#   service: backend, caddy, postgres, redis, all
###############################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVICE="$1"

# If no service specified, show menu
if [ -z "$SERVICE" ]; then
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}    Deep Space - Log Viewer${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}Select a service to view logs:${NC}"
    echo ""
    echo -e "  1) Backend API (PM2)"
    echo -e "  2) Caddy Web Server (PM2)"
    echo -e "  3) PostgreSQL Database (Docker)"
    echo -e "  4) Redis Cache (Docker)"
    echo -e "  5) All PM2 Logs"
    echo -e "  6) All Docker Logs"
    echo -e "  7) Exit"
    echo ""
    read -p "Enter choice [1-7]: " choice

    case $choice in
        1) SERVICE="backend" ;;
        2) SERVICE="caddy" ;;
        3) SERVICE="postgres" ;;
        4) SERVICE="redis" ;;
        5) SERVICE="pm2-all" ;;
        6) SERVICE="docker-all" ;;
        7) exit 0 ;;
        *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
    esac
fi

echo ""
echo -e "${BLUE}Viewing logs for: ${GREEN}$SERVICE${NC}"
echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
echo ""
sleep 1

case $SERVICE in
    backend)
        pm2 logs deepspace-backend
        ;;
    caddy)
        pm2 logs deepspace-caddy
        ;;
    postgres)
        cd "$PROJECT_ROOT"
        docker compose -f deploy/docker compose.production.yml logs -f postgres
        ;;
    redis)
        cd "$PROJECT_ROOT"
        docker compose -f deploy/docker compose.production.yml logs -f redis
        ;;
    pm2-all|all)
        pm2 logs
        ;;
    docker-all)
        cd "$PROJECT_ROOT"
        docker compose -f deploy/docker compose.production.yml logs -f
        ;;
    *)
        echo -e "${RED}Unknown service: $SERVICE${NC}"
        echo -e "Usage: $0 [backend|caddy|postgres|redis|all]"
        exit 1
        ;;
esac
