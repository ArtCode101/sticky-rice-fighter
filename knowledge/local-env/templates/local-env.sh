#!/usr/bin/env bash
#
# local-env.sh - manages this workspace's local development dependencies.
#
# The containers this script starts are the workspace's own local environment.
# They are never shared with another workspace: every command runs under the
# compose project name "$WORKSPACE_NAME".
#
# Usage:
#   local-env.sh up       [service...]   start services (default: all present)
#   local-env.sh down     [service...]   stop services, keep data
#   local-env.sh destroy  --yes          stop services and delete all volumes
#   local-env.sh status                  show what is running
#
# Services are the compose files sitting next to this script, for example
# postgres.yml, redis.yml and kafka.yml, copied from the framework's knowledge
# templates.
#
# Configuration, including WORKSPACE_NAME and every port, comes from the .env
# next to this script.
#
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    printf "config not found: %s\n" "$ENV_FILE"
    exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

if [ -z "${WORKSPACE_NAME:-}" ]; then
    printf "WORKSPACE_NAME is not set in %s\n" "$ENV_FILE"
    exit 1
fi

COMMAND="${1:-}"
[ "$#" -gt 0 ] && shift

# Pull the confirmation flag out before the remaining arguments are read as
# service names.
CONFIRM=""
if [ "${1:-}" = "--yes" ]; then
    CONFIRM="--yes"
    shift
fi

# Build the -f list: the named services, or every compose file present.
COMPOSE_ARGS=()
if [ "$#" -gt 0 ]; then
    for service in "$@"; do
        file="$SCRIPT_DIR/$service.yml"
        if [ ! -f "$file" ]; then
            printf "unknown service '%s' (no %s)\n" "$service" "$file"
            exit 1
        fi
        COMPOSE_ARGS+=(-f "$file")
    done
else
    for file in "$SCRIPT_DIR"/*.yml; do
        [ -e "$file" ] || continue
        COMPOSE_ARGS+=(-f "$file")
    done
fi

if [ "${#COMPOSE_ARGS[@]}" -eq 0 ]; then
    printf "no compose files found in %s\n" "$SCRIPT_DIR"
    exit 1
fi

compose() {
    docker compose -p "$WORKSPACE_NAME" --env-file "$ENV_FILE" "${COMPOSE_ARGS[@]}" "$@"
}

case "$COMMAND" in
    up)
        compose up -d
        printf "\nLocal environment up for workspace '%s'.\n" "$WORKSPACE_NAME"
        compose ps
        ;;
    down)
        # Containers stop, named volumes stay. Data survives across releases.
        compose down
        printf "\nStopped. Data volumes kept.\n"
        ;;
    destroy)
        if [ "$CONFIRM" != "--yes" ]; then
            printf "destroy deletes every volume in workspace '%s'.\n" "$WORKSPACE_NAME"
            printf "Re-run with: local-env.sh destroy --yes\n"
            exit 1
        fi
        compose down -v
        printf "\nDestroyed. Volumes deleted.\n"
        ;;
    status)
        compose ps
        ;;
    *)
        printf "usage: %s <up|down|destroy|status> [service...]\n" "$0"
        exit 2
        ;;
esac
