#!/usr/bin/env bash
#
# deploy.sh - deploys this release to the local Docker host.
#
# Configuration is read from the workspace's config repository. Nothing is
# hard-coded here.
#
# Usage:
#   local/deploy.sh
#
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_ROOT="$SCRIPT_DIR/.."
WORKSPACE_ROOT="$DEPLOYMENT_ROOT/.."

# Replace with the real config repository name from the workspace manifest.
CONFIG_REPO="$WORKSPACE_ROOT/my-workspace-config"
CONFIG_ENV="$CONFIG_REPO/local/.env"

COMPOSE_FILE="$SCRIPT_DIR/compose.yml"

if [ ! -f "$CONFIG_ENV" ]; then
    printf "config not found: %s\n" "$CONFIG_ENV"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    printf "compose file not found: %s\n" "$COMPOSE_FILE"
    exit 1
fi

printf "Using config: %s\n" "$CONFIG_ENV"

docker compose --env-file "$CONFIG_ENV" -f "$COMPOSE_FILE" up -d --build

printf "\nDeployed. Verify with:\n"
printf "  <framework>/preflight/done-check.sh %s <url> [url...]\n" "$COMPOSE_FILE"
