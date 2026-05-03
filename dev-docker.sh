#!/usr/bin/env bash
# dev-docker.sh — thin wrapper around podman/docker compose for local NEOS development.
#
# NOTE (Windows users): Run this script inside Git Bash, WSL, or any Unix-compatible
# shell. It will NOT work in plain cmd.exe or PowerShell without a bash interpreter.
#
# Usage:
#   ./dev-docker.sh          # build images and start all services (attached)
#   ./dev-docker.sh -d       # start in detached (background) mode
#   ./dev-docker.sh --down   # stop and remove containers
#   ./dev-docker.sh --logs   # tail logs from all running containers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Use podman if available, fall back to docker
if command -v podman &>/dev/null; then
  COMPOSE="podman compose"
else
  COMPOSE="docker compose"
fi

case "${1:-}" in
  --down)
    echo "Stopping and removing NEOS containers..."
    $COMPOSE down
    ;;
  --logs)
    $COMPOSE logs -f
    ;;
  -d|--detach)
    echo "Building images and starting NEOS services in the background..."
    $COMPOSE up --build -d
    echo ""
    echo "Services running:"
    echo "  Backend:  http://localhost:8000"
    echo "  Frontend: http://localhost:3000"
    echo ""
    echo "Tail logs with:  ./dev-docker.sh --logs"
    echo "Stop with:       ./dev-docker.sh --down"
    ;;
  *)
    echo "Building images and starting NEOS services (Ctrl+C to stop)..."
    $COMPOSE up --build
    ;;
esac
