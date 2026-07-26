#!/bin/bash
# =============================================================================
# MinIO One-Command Installation Script
# =============================================================================
# Usage:
#   bash scripts/install.sh
#
# What it does:
#   1. Installs Docker and Docker Compose (if not already installed)
#   2. Copies .env.example → .env (if .env doesn't exist)
#   3. Pulls latest images
#   4. Starts MinIO stack
# =============================================================================

set -e

COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[0;31m"
COLOR_RESET="\033[0m"

info()    { echo -e "${COLOR_GREEN}[INFO]${COLOR_RESET} $1"; }
warning() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1"; }
error()   { echo -e "${COLOR_RED}[ERR ]${COLOR_RESET} $1"; exit 1; }

# ---------------------------------------------------------------------------
# Go to project root (one level up from scripts/)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"
info "Working directory: $PROJECT_DIR"

# ---------------------------------------------------------------------------
# Step 1: Install Docker
# ---------------------------------------------------------------------------
if command -v docker &> /dev/null; then
  info "Docker already installed: $(docker --version)"
else
  info "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  warning "Docker installed. You may need to log out and back in for group changes."
  warning "Or run: newgrp docker"
fi

# ---------------------------------------------------------------------------
# Step 2: Install Docker Compose plugin (if missing)
# ---------------------------------------------------------------------------
if docker compose version &> /dev/null; then
  info "Docker Compose already available: $(docker compose version)"
else
  info "Installing Docker Compose plugin..."
  sudo apt-get update -qq
  sudo apt-get install -y docker-compose-plugin
fi

# ---------------------------------------------------------------------------
# Step 3: Create .env if it doesn't exist
# ---------------------------------------------------------------------------
if [ -f ".env" ]; then
  warning ".env already exists — skipping copy. Review it before proceeding."
else
  cp .env.example .env
  info "Created .env from .env.example"
  warning "⚠  IMPORTANT: Edit .env and set strong credentials before production!"
  warning "   nano .env"
fi

# ---------------------------------------------------------------------------
# Step 4: Create required directories
# ---------------------------------------------------------------------------
mkdir -p data backups
info "Created ./data and ./backups directories"

# ---------------------------------------------------------------------------
# Step 5: Pull latest images
# ---------------------------------------------------------------------------
info "Pulling latest MinIO images..."
docker compose pull

# ---------------------------------------------------------------------------
# Step 6: Start the stack
# ---------------------------------------------------------------------------
info "Starting MinIO stack..."
docker compose up -d

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${COLOR_GREEN}============================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}  MinIO is running!${COLOR_RESET}"
echo -e "${COLOR_GREEN}============================================${COLOR_RESET}"
echo ""
echo "  API Endpoint : http://$(hostname -I | awk '{print $1}'):9000"
echo "  Web Console  : http://$(hostname -I | awk '{print $1}'):9001"
echo ""
echo "  Credentials are in: .env"
echo ""
echo "  View logs:    docker compose logs -f minio"
echo "  Stop:         docker compose down"
echo ""
