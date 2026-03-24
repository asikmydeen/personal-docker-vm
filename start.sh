#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Pre-flight checks -------------------------------------------------------
command -v podman >/dev/null 2>&1 || error "podman is not installed"

# --- Create .env if missing ---------------------------------------------------
if [ ! -f .env ]; then
  warn ".env file not found. Creating from env.example..."
  cp env.example .env

  # Auto-populate SSH key if available
  for key in ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub; do
    if [ -f "$key" ]; then
      SSH_KEY=$(cat "$key")
      # Use a delimiter that won't appear in SSH keys
      sed -i.bak "s|SSH_PUBLIC_KEY=ssh-ed25519 AAAA... your-key-here|SSH_PUBLIC_KEY=${SSH_KEY}|" .env
      rm -f .env.bak
      info "Auto-detected SSH public key: $key"
      break
    fi
  done

  warn "Please edit .env with your AWS Bedrock credentials before starting."
  warn "  vim .env  (or your editor of choice)"
  echo ""
  read -p "Press Enter to continue (or Ctrl+C to edit .env first)... "
fi

# --- Validate SSH key is set --------------------------------------------------
if grep -q "your-key-here" .env 2>/dev/null; then
  error "SSH_PUBLIC_KEY is not set in .env. Edit .env first."
fi

# --- Build and start ----------------------------------------------------------
info "Building Claude Dev VM..."
podman compose build

info "Starting Claude Dev VM..."
podman compose up -d

# --- Wait for SSH to be ready -------------------------------------------------
info "Waiting for SSH to become available..."
for i in $(seq 1 30); do
  if ssh -o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=no -p 2222 developer@localhost echo "ok" 2>/dev/null; then
    break
  fi
  sleep 1
done

echo ""
info "============================================="
info " Claude Code Dev VM is running!"
info "============================================="
info " Connect:  ssh -p 2222 developer@localhost"
info " Stop:     podman compose down"
info " Logs:     podman compose logs -f"
info " Rebuild:  podman compose up -d --build"
info "============================================="
