#!/bin/bash

###############################################################################
# Deep Space - Environment Setup Script
#
# Interactive script to generate production .env file from template
#
# Usage: ./deploy/setup-env.sh
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/.env.production.example"
OUTPUT_FILE="$SCRIPT_DIR/../backend/.env"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Deep Space - Environment Configuration Setup           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}✗ Error: Template file not found: $TEMPLATE_FILE${NC}"
    exit 1
fi

# Check if .env already exists
if [ -f "$OUTPUT_FILE" ]; then
    echo -e "${YELLOW}⚠  Warning: .env file already exists at: $OUTPUT_FILE${NC}"
    read -p "Do you want to overwrite it? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        echo -e "${YELLOW}Setup cancelled.${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${GREEN}This script will help you create a production .env file.${NC}"
echo -e "${YELLOW}You can skip any field by pressing Enter (will use placeholder).${NC}"
echo ""

# Generate JWT secrets
generate_secret() {
    openssl rand -base64 64 | tr -d '\n'
}

echo -e "${BLUE}Generating secure secrets...${NC}"
JWT_ACCESS_SECRET=$(generate_secret)
JWT_REFRESH_SECRET=$(generate_secret)
SESSION_SECRET=$(generate_secret)
echo -e "${GREEN}✓ Secrets generated${NC}"
echo ""

# Collect user input
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                  Basic Configuration                   ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

read -p "Domain name (e.g., deepspace.example.com): " DOMAIN
DOMAIN=${DOMAIN:-your-domain.com}

read -p "Admin email address: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@your-domain.com}

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}               Database Configuration                   ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

read -p "PostgreSQL user (default: deepspace): " POSTGRES_USER
POSTGRES_USER=${POSTGRES_USER:-deepspace}

read -sp "PostgreSQL password (will be generated if empty): " POSTGRES_PASSWORD
echo ""
if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)
    echo -e "${GREEN}✓ Generated password for PostgreSQL${NC}"
fi

read -p "PostgreSQL database name (default: deepspace): " POSTGRES_DB
POSTGRES_DB=${POSTGRES_DB:-deepspace}

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                Redis Configuration                      ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

read -sp "Redis password (will be generated if empty): " REDIS_PASSWORD
echo ""
if [ -z "$REDIS_PASSWORD" ]; then
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)
    echo -e "${GREEN}✓ Generated password for Redis${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}              Blockchain Configuration                  ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

read -p "Use Base Mainnet? (yes/no, default: no): " USE_MAINNET
if [[ $USE_MAINNET =~ ^[Yy]es$ ]]; then
    BASE_NETWORK="mainnet"
    BASE_RPC_URL="https://mainnet.base.org"
    BASE_CHAIN_ID="8453"
else
    BASE_NETWORK="testnet"
    BASE_RPC_URL="https://sepolia.base.org"
    BASE_CHAIN_ID="84532"
fi

echo ""
echo -e "${YELLOW}⚠  CRITICAL: Wallet Configuration${NC}"
echo -e "${YELLOW}Please ensure you have:${NC}"
echo -e "${YELLOW}  1. BIP39 mnemonic phrase (12 or 24 words)${NC}"
echo -e "${YELLOW}  2. Treasury wallet private key${NC}"
echo -e "${YELLOW}  3. Escrow wallet private key${NC}"
echo ""
echo -e "${RED}WARNING: These will be stored in plaintext!${NC}"
echo -e "${RED}Consider using a secrets manager in production.${NC}"
echo ""

read -p "Do you want to enter wallet details now? (yes/no): " ENTER_WALLETS
if [[ $ENTER_WALLETS =~ ^[Yy]es$ ]]; then
    read -p "BIP39 Mnemonic (12-24 words): " MNEMONIC
    MNEMONIC=${MNEMONIC:-word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12}

    read -p "Treasury wallet address: " TREASURY_ADDRESS
    TREASURY_ADDRESS=${TREASURY_ADDRESS:-0x...}

    read -sp "Treasury wallet private key: " TREASURY_KEY
    echo ""
    TREASURY_KEY=${TREASURY_KEY:-0x...}

    read -p "Escrow wallet address: " ESCROW_ADDRESS
    ESCROW_ADDRESS=${ESCROW_ADDRESS:-0x...}

    read -sp "Escrow wallet private key: " ESCROW_KEY
    echo ""
    ESCROW_KEY=${ESCROW_KEY:-0x...}
else
    MNEMONIC="word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12"
    TREASURY_ADDRESS="0x..."
    TREASURY_KEY="0x..."
    ESCROW_ADDRESS="0x..."
    ESCROW_KEY="0x..."
    echo -e "${YELLOW}⚠  Skipped wallet configuration. Update .env manually!${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                Email Configuration                      ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

read -p "SMTP Host (default: mail.lunanode.com): " SMTP_HOST
SMTP_HOST=${SMTP_HOST:-mail.lunanode.com}

read -p "SMTP Port (default: 587): " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-587}

read -p "SMTP User: " SMTP_USER
SMTP_USER=${SMTP_USER:-your-smtp-user}

read -sp "SMTP Password: " SMTP_PASSWORD
echo ""
SMTP_PASSWORD=${SMTP_PASSWORD:-your-smtp-password}

read -p "From Email Address: " FROM_EMAIL
FROM_EMAIL=${FROM_EMAIL:-noreply@$DOMAIN}

# Create .env file
echo ""
echo -e "${BLUE}Creating .env file...${NC}"

cat > "$OUTPUT_FILE" <<EOF
# Deep Space - Production Environment Variables
# Generated on: $(date)
# DO NOT COMMIT THIS FILE TO VERSION CONTROL

################################################################################
# Server Configuration
################################################################################
NODE_ENV=production
PORT=3000
FRONTEND_URL=https://$DOMAIN

################################################################################
# Database (PostgreSQL)
################################################################################
DATABASE_URL=postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:5432/$POSTGRES_DB
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB
POSTGRES_PORT=5432

################################################################################
# Redis Cache
################################################################################
REDIS_URL=redis://:$REDIS_PASSWORD@localhost:6379
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_PORT=6379

################################################################################
# JWT Secrets
################################################################################
JWT_ACCESS_SECRET=$JWT_ACCESS_SECRET
JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d

################################################################################
# Blockchain Configuration (Base Network)
################################################################################
BASE_NETWORK=$BASE_NETWORK
BASE_RPC_URL=$BASE_RPC_URL
BASE_CHAIN_ID=$BASE_CHAIN_ID
USDC_ADDRESS=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913

################################################################################
# HD Wallet Configuration
################################################################################
MASTER_SEED_MNEMONIC=$MNEMONIC
DELEGATION_WALLET_INDEX=0

################################################################################
# Treasury & Escrow Wallets
################################################################################
TREASURY_WALLET_ADDRESS=$TREASURY_ADDRESS
TREASURY_WALLET_PRIVATE_KEY=$TREASURY_KEY
ESCROW_WALLET_ADDRESS=$ESCROW_ADDRESS
ESCROW_WALLET_PRIVATE_KEY=$ESCROW_KEY

################################################################################
# Email Configuration
################################################################################
LUNANODE_SMTP_HOST=$SMTP_HOST
LUNANODE_SMTP_PORT=$SMTP_PORT
LUNANODE_SMTP_USER=$SMTP_USER
LUNANODE_SMTP_PASSWORD=$SMTP_PASSWORD
LUNANODE_SMTP_SECURE=false
EMAIL_FROM_ADDRESS=$FROM_EMAIL
EMAIL_FROM_NAME=Deep Space Crypto
ADMIN_EMAIL_ADDRESSES=$ADMIN_EMAIL

################################################################################
# NEAR Intent API
################################################################################
NEAR_INTENT_API_KEY=your-near-intent-api-key
NEAR_INTENT_API_URL=https://api.intents.near.org
NEAR_INTENT_WEBHOOK_URL=https://$DOMAIN/api/webhooks/near-intent

################################################################################
# Avantis Perpetuals Trading
################################################################################
AVANTIS_CONTRACT_ADDRESS=0xf9C384e3C2Ae42a006e70Bb2Ae8F24dB3B8FE3FF
AVANTIS_PAIR_STORAGE_ADDRESS=0xd5a00FEB0bAfDB1F7e4E2d25bAa46CA1f5c11A96
AVANTIS_REFERRAL_STORAGE_ADDRESS=0x90aB96905F09211fe8e0B51d0A01Bb91e6CD9453
AVANTIS_MOCK_MODE=false

################################################################################
# Pyth Oracle
################################################################################
PYTH_ENDPOINT=https://hermes.pyth.network
PYTH_PRICE_SERVICE_ENDPOINT=https://hermes.pyth.network

################################################################################
# Rate Limiting
################################################################################
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

################################################################################
# Logging
################################################################################
LOG_LEVEL=info
LOG_FILE_PATH=/var/log/deepspace/app.log

################################################################################
# Session & Security
################################################################################
SESSION_SECRET=$SESSION_SECRET
COOKIE_SECURE=true
COOKIE_SAME_SITE=strict

################################################################################
# CORS Configuration
################################################################################
CORS_ORIGIN=https://$DOMAIN
CORS_CREDENTIALS=true

################################################################################
# Application Features
################################################################################
ENABLE_SIGNUP=true
ENABLE_WITHDRAWALS=true
ENABLE_P2P=true
ENABLE_INVESTMENT_VAULT=true
ENABLE_REFERRALS=true

INVESTMENT_MONTHLY_YIELD_RATE=10
REFERRAL_BONUS_PERCENTAGE=5

################################################################################
# Development/Testing Flags
################################################################################
AUTO_COMPLETE_DEPOSITS=false
MOCK_TRADING_MODE=false

################################################################################
# Maintenance
################################################################################
MAINTENANCE_MODE=false
MAINTENANCE_MESSAGE=We are currently performing maintenance. Please check back soon.
EOF

echo -e "${GREEN}✓ .env file created at: $OUTPUT_FILE${NC}"
echo ""

# Set permissions
chmod 600 "$OUTPUT_FILE"
echo -e "${GREEN}✓ File permissions set to 600 (owner read/write only)${NC}"
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                   Configuration Summary                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Domain:${NC}              $DOMAIN"
echo -e "${GREEN}Admin Email:${NC}         $ADMIN_EMAIL"
echo -e "${GREEN}Database User:${NC}       $POSTGRES_USER"
echo -e "${GREEN}Database Name:${NC}       $POSTGRES_DB"
echo -e "${GREEN}Blockchain:${NC}          Base $BASE_NETWORK"
echo -e "${GREEN}Email Provider:${NC}      $SMTP_HOST"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Review the .env file: ${GREEN}$OUTPUT_FILE${NC}"
echo -e "  2. Update any placeholder values (NEAR_INTENT_API_KEY, etc.)"
echo -e "  3. Ensure wallet private keys are correct"
echo -e "  4. Test email configuration"
echo -e "  5. Run database migrations: ${GREEN}cd backend && npx prisma migrate deploy${NC}"
echo -e "  6. Start services: ${GREEN}./deploy/start-all.sh${NC}"
echo ""
echo -e "${RED}⚠  SECURITY REMINDER:${NC}"
echo -e "  • Never commit .env file to version control"
echo -e "  • Keep backups in a secure, encrypted location"
echo -e "  • Consider using a secrets manager for production"
echo -e "  • Rotate secrets regularly"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Environment setup completed!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
