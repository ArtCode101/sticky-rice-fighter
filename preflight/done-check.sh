#!/usr/bin/env bash
#
# done-check.sh - verifies the definition of done for a release.
#
# A release is done when it deploys and runs on the local Docker host and its
# entry points respond. Nothing about logic correctness is checked here.
#
# Usage:
#   preflight/done-check.sh [--gateway <url>] <compose-file> <url> [url...]
#
# --gateway asserts that Nginx is deployed and answering. Any release whose frontend
# calls a backend must pass it, because the frontend reaches the backend through
# Nginx only.
#
# Example:
#   preflight/done-check.sh --gateway http://localhost:8000 \
#       ../my-workspace/my-workspace-deployment/local/compose.yml \
#       http://localhost:8000
#
# Exit codes:
#   0 - done: every service is up and every url responded
#   1 - not done: at least one check failed
#   2 - usage error
#
set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0

pass() { printf "${GREEN}[OK]${NC}   %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; FAILED=1; }

usage() {
    printf "usage: %s [--gateway <url>] <compose-file> <url> [url...]\n" "$0"
}

# --gateway asserts that Nginx is deployed as a service and answers on that url.
# Any release whose frontend calls a backend must pass it: the frontend reaches the
# backend through Nginx only.
GATEWAY_URL=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --gateway)
            GATEWAY_URL="${2:-}"
            if [ -z "$GATEWAY_URL" ]; then
                usage
                exit 2
            fi
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -lt 2 ]; then
    usage
    exit 2
fi

COMPOSE_FILE="$1"
shift

if [ ! -f "$COMPOSE_FILE" ]; then
    printf "${RED}[FAIL]${NC} compose file not found: %s\n" "$COMPOSE_FILE"
    exit 1
fi

# 1. The Docker daemon must be running.
if ! docker info >/dev/null 2>&1; then
    fail "Docker daemon is not running"
    printf -- "-----------------------------------\n"
    printf "${RED}NOT DONE${NC}\n"
    exit 1
fi
pass "Docker daemon is running"

# 2. Every service declared in the compose file must have a running container.
SERVICES="$(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null)"
if [ -z "$SERVICES" ]; then
    fail "No services found in $COMPOSE_FILE"
else
    RUNNING="$(docker compose -f "$COMPOSE_FILE" ps --services --filter status=running 2>/dev/null)"
    while IFS= read -r service; do
        [ -z "$service" ] && continue
        if printf '%s\n' "$RUNNING" | grep -qx "$service"; then
            pass "Service running: $service"
        else
            fail "Service not running: $service"
        fi
    done <<< "$SERVICES"
fi

# 3. When a gateway is required, Nginx must be one of the deployed services and it
#    must answer. The frontend reaches the backend through Nginx only, so a release
#    with a frontend is not done without it.
if [ -n "$GATEWAY_URL" ]; then
    if printf '%s\n' "$SERVICES" | grep -qi 'nginx'; then
        pass "Nginx is a deployed service"
    else
        fail "No Nginx service in $COMPOSE_FILE: the frontend must reach the backend through Nginx"
    fi

    GATEWAY_STATUS="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$GATEWAY_URL" 2>/dev/null)"
    if [ -z "$GATEWAY_STATUS" ] || [ "$GATEWAY_STATUS" = "000" ]; then
        fail "No response from the gateway at $GATEWAY_URL"
    elif [ "$GATEWAY_STATUS" -ge 500 ]; then
        fail "Gateway at $GATEWAY_URL returned HTTP $GATEWAY_STATUS"
    else
        pass "Gateway at $GATEWAY_URL returned HTTP $GATEWAY_STATUS"
    fi
fi

# 4. Every entry point must respond. Any HTTP status below 500 counts as
#    responding: the point is that the system is reachable and clickable, not
#    that the response is correct.
for url in "$@"; do
    STATUS="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null)"
    if [ -z "$STATUS" ] || [ "$STATUS" = "000" ]; then
        fail "No response from $url"
    elif [ "$STATUS" -ge 500 ]; then
        fail "$url returned HTTP $STATUS"
    else
        pass "$url returned HTTP $STATUS"
    fi
done

printf -- "-----------------------------------\n"
if [ "$FAILED" -eq 0 ]; then
    printf "${GREEN}DONE${NC} - release runs on the local Docker host.\n"
    printf "In manual release_execution mode, the human now clicks through it\n"
    printf "before the next release starts.\n"
    exit 0
else
    printf "${RED}NOT DONE${NC} - the release does not run yet.\n"
    exit 1
fi
