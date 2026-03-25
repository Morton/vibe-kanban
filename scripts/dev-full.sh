#!/usr/bin/env bash
# dev-full.sh — Start the full local dev environment (remote stack + desktop client)
#
# Usage:
#   ./scripts/dev-full.sh           # start everything
#   ./scripts/dev-full.sh --build   # rebuild Docker images before starting
#
# Prerequisites: Docker Desktop running, crates/remote/.env.remote exists.
# See CLAUDE.md "Full Local Dev Setup" for one-time setup instructions.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/crates/remote/.env.remote"
COMPOSE_FILE="$REPO_ROOT/crates/remote/docker-compose.yml"
REMOTE_URL="http://localhost:3000"

# -- Colours ------------------------------------------------------------------
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red() { printf '\033[0;31m%s\033[0m\n' "$*"; }

# -- Rustup -------------------------------------------------------------------
# Ensure rustup-managed cargo takes precedence over any system Rust (e.g. Homebrew).
# The rust-toolchain.toml will then select the correct nightly automatically.
if [ -f "$HOME/.cargo/env" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.cargo/env"
fi

# -- Checks -------------------------------------------------------------------
if ! docker info > /dev/null 2>&1; then
  red "Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  red "Missing $ENV_FILE"
  echo "See CLAUDE.md 'Full Local Dev Setup' for instructions on creating it."
  exit 1
fi

# -- Docker remote stack ------------------------------------------------------
BUILD_FLAG=""
if [[ "${1:-}" == "--build" ]]; then
  BUILD_FLAG="--build"
  yellow "Rebuilding Docker images..."
fi

# Check if the remote server is already healthy
if curl -sf "$REMOTE_URL/v1/health" > /dev/null 2>&1; then
  green "Remote stack already running."
else
  yellow "Starting remote stack..."
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d $BUILD_FLAG

  yellow "Waiting for remote server to be healthy..."
  for i in $(seq 1 30); do
    if curl -sf "$REMOTE_URL/v1/health" > /dev/null 2>&1; then
      break
    fi
    if [ "$i" -eq 30 ]; then
      red "Remote server did not become healthy in time."
      echo "Check logs with: docker compose --env-file crates/remote/.env.remote -f crates/remote/docker-compose.yml logs"
      exit 1
    fi
    sleep 2
  done
  green "Remote stack is healthy."
fi

# -- Dev server ---------------------------------------------------------------
green "Starting dev server..."
echo ""
echo "  Frontend : http://localhost:3001"
echo "  Remote   : $REMOTE_URL"
echo ""

cd "$REPO_ROOT"
exec env VK_SHARED_API_BASE="$REMOTE_URL" pnpm run dev
