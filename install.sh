#!/bin/bash
# =============================================================================
# MinIO Server — Remote One-Line Installer
# =============================================================================
#
# Usage (on any fresh Ubuntu/Debian server):
#
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/minio-server/main/install.sh | bash
#
# Or with a custom install directory:
#
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/minio-server/main/install.sh | bash -s -- --dir /opt/minio
#
# What it does:
#   1. Installs git (if missing)
#   2. Installs Docker + Docker Compose plugin (if missing)
#   3. Clones this repository
#   4. Creates .env from .env.example
#   5. Prompts you to set credentials
#   6. Starts MinIO (docker compose up -d)
# =============================================================================

set -e

# ---------------------------------------------------------------------------
# Config — edit these before hosting the script
# ---------------------------------------------------------------------------
REPO_URL="https://github.com/MrAbidAkash/minio-server.git"
DEFAULT_INSTALL_DIR="$HOME/minio-server"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

info()    { echo -e "${GREEN}[✔]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $1"; }
error()   { echo -e "${RED}[✘]${RESET} $1"; exit 1; }
step()    { echo -e "\n${CYAN}${BOLD}──────────────────────────────────${RESET}"; echo -e "${CYAN}${BOLD} $1${RESET}"; echo -e "${CYAN}${BOLD}──────────────────────────────────${RESET}"; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
INSTALL_DIR="$DEFAULT_INSTALL_DIR"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --dir) INSTALL_DIR="$2"; shift ;;
    *) warn "Unknown argument: $1" ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ███╗   ███╗██╗███╗   ██╗██╗ ██████╗ "
echo "  ████╗ ████║██║████╗  ██║██║██╔═══██╗"
echo "  ██╔████╔██║██║██╔██╗ ██║██║██║   ██║"
echo "  ██║╚██╔╝██║██║██║╚██╗██║██║██║   ██║"
echo "  ██║ ╚═╝ ██║██║██║ ╚████║██║╚██████╔╝"
echo "  ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝ ╚═════╝ "
echo -e "${RESET}"
echo -e "  ${BOLD}Self-Hosted S3-Compatible Storage${RESET}"
echo -e "  Install directory: ${YELLOW}$INSTALL_DIR${RESET}"
echo ""

# ---------------------------------------------------------------------------
# Check: not running as root (Docker doesn't need it)
# ---------------------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
  warn "Running as root. This is allowed but not recommended for production."
fi

# ---------------------------------------------------------------------------
# Step 1: Install git
# ---------------------------------------------------------------------------
step "Step 1/5 — Installing dependencies"

if command -v git &>/dev/null; then
  info "git already installed: $(git --version)"
else
  info "Installing git..."
  sudo apt-get update -qq
  sudo apt-get install -y git curl
fi

# ---------------------------------------------------------------------------
# Step 2: Install Docker
# ---------------------------------------------------------------------------
if command -v docker &>/dev/null; then
  info "Docker already installed: $(docker --version)"
else
  info "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  warn "Docker installed. If you get permission errors, run: newgrp docker"
fi

# Ensure Docker Compose plugin is available
if docker compose version &>/dev/null; then
  info "Docker Compose available: $(docker compose version)"
else
  info "Installing Docker Compose plugin..."
  sudo apt-get update -qq
  sudo apt-get install -y docker-compose-plugin
fi

# ---------------------------------------------------------------------------
# Step 3: Clone repository
# ---------------------------------------------------------------------------
step "Step 2/5 — Cloning repository"

if [ -d "$INSTALL_DIR/.git" ]; then
  info "Repository already exists at $INSTALL_DIR — pulling latest..."
  git -C "$INSTALL_DIR" pull
else
  info "Cloning $REPO_URL → $INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# ---------------------------------------------------------------------------
# Step 4: Configure .env
# ---------------------------------------------------------------------------
step "Step 3/5 — Configuring environment"

if [ -f ".env" ]; then
  warn ".env already exists — skipping. Edit it manually if needed:"
  warn "  nano $INSTALL_DIR/.env"
else
  cp .env.example .env
  info "Created .env from .env.example"

  # Prompt for credentials interactively (only if running in a terminal)
  if [ -t 0 ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}Set your MinIO credentials:${RESET}"

    read -rp "  Admin username [minioadmin]: " INPUT_USER
    MINIO_USER="${INPUT_USER:-minioadmin}"

    while true; do
      read -rsp "  Admin password: " INPUT_PASS
      echo ""
      read -rsp "  Confirm password: " INPUT_PASS2
      echo ""
      if [ "$INPUT_PASS" = "$INPUT_PASS2" ] && [ -n "$INPUT_PASS" ]; then
        MINIO_PASS="$INPUT_PASS"
        break
      else
        warn "Passwords don't match or are empty. Try again."
      fi
    done

    # Detect server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    read -rp "  Server IP or domain [$SERVER_IP]: " INPUT_IP
    SERVER_IP="${INPUT_IP:-$SERVER_IP}"

    # Update .env
    sed -i "s|^MINIO_ROOT_USER=.*|MINIO_ROOT_USER=$MINIO_USER|" .env
    sed -i "s|^MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=$MINIO_PASS|" .env
    sed -i "s|MINIO_SERVER_URL=.*|MINIO_SERVER_URL=http://$SERVER_IP:9000|" .env
    sed -i "s|MINIO_BROWSER_REDIRECT_URL=.*|MINIO_BROWSER_REDIRECT_URL=http://$SERVER_IP:9001|" .env

    info "Credentials saved to .env"
  else
    warn "Running non-interactively. Please edit .env before starting:"
    warn "  nano $INSTALL_DIR/.env"
    warn "  Then run: cd $INSTALL_DIR && docker compose up -d"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Step 5: Create directories + start stack
# ---------------------------------------------------------------------------
step "Step 4/5 — Creating directories"
mkdir -p data backups
info "Created ./data and ./backups"

step "Step 5/5 — Starting MinIO"
docker compose pull
docker compose up -d

# ---------------------------------------------------------------------------
# Wait for healthy status
# ---------------------------------------------------------------------------
echo ""
info "Waiting for MinIO to be ready..."
sleep 5

RETRIES=10
until docker compose ps | grep -q "healthy" || [ "$RETRIES" -eq 0 ]; do
  sleep 3
  RETRIES=$((RETRIES - 1))
done

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
SERVER_IP_FINAL=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}============================================${RESET}"
echo -e "${GREEN}${BOLD}  MinIO is running! 🎉${RESET}"
echo -e "${GREEN}${BOLD}============================================${RESET}"
echo ""
echo -e "  ${BOLD}S3 API:${RESET}      http://$SERVER_IP_FINAL:9000"
echo -e "  ${BOLD}Web Console:${RESET} http://$SERVER_IP_FINAL:9001"
echo ""
echo -e "  ${BOLD}Install dir:${RESET} $INSTALL_DIR"
echo -e "  ${BOLD}Data dir:${RESET}    $INSTALL_DIR/data"
echo ""
echo -e "  ${BOLD}Useful commands:${RESET}"
echo -e "    cd $INSTALL_DIR"
echo -e "    docker compose logs -f minio   # Live logs"
echo -e "    docker compose down            # Stop"
echo -e "    docker compose pull && docker compose up -d  # Upgrade"
echo ""
echo -e "  ${YELLOW}${BOLD}⚠  Remember to configure a firewall and set up HTTPS for production!${RESET}"
echo ""
