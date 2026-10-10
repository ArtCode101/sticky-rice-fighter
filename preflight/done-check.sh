#!/usr/bin/env bash
#
# done-check.sh - verifies the definition of done for a release.
#
# This is the deploy half of the definition of done: the release deploys and runs on
# the local Docker host and its entry points respond. Nothing about logic correctness
# is checked here. The other half - required journeys passed in the test zone, and the
# test zone cleaned up - is preflight/journey-check.sh. A release locks only when both
# pass.
#
# Usage:
#   preflight/done-check.sh [--gateway <url>]
#                           [--mcp <url> --mcp-tool <name> [--mcp-args <json>] [--mcp-token <token>]]
#                           <compose-file> <url> [url...]
#
# --gateway asserts that Nginx is deployed and answering. Every release of a workspace
# that has a backend must pass it, because every caller reaches the backend through
# Nginx only.
#
# --mcp asserts that the MCP server is deployed, that an MCP session initializes, that
# it lists its tools, and that the tool named by --mcp-tool, called with --mcp-args
# (default {}), reaches the backend. --mcp-token is the bearer token the deployed
# server's OAuth 2.1 layer expects, when it expects one. An MCP release has no screen to
# click through, so this takes the place of that check. The tool to call is the one the
# mcp-server repository's README names for this check.
#
# Example:
#   preflight/done-check.sh --gateway http://localhost:8000 \
#       ../my-workspace/my-workspace-deployment/local/compose.yml \
#       http://localhost:8000
#
#   preflight/done-check.sh --gateway http://localhost:8000 \
#       --mcp http://localhost:8100/mcp --mcp-tool listAccounts \
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
    printf "usage: %s [--gateway <url>] [--mcp <url> --mcp-tool <name> [--mcp-args <json>] [--mcp-token <token>]] <compose-file> <url> [url...]\n" "$0"
}

# --gateway asserts that Nginx is deployed as a service and answers on that url.
# Every release of a workspace that has a backend must pass it.
#
# --mcp asserts the definition of done for a release that ships an MCP server: the
# service is deployed, it lists its tools, and one real tool call reaches the backend.
GATEWAY_URL=""
MCP_URL=""
MCP_TOOL=""
MCP_ARGS="{}"
MCP_TOKEN=""
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
        --mcp|--mcp-tool|--mcp-args|--mcp-token)
            if [ -z "${2:-}" ]; then
                usage
                exit 2
            fi
            case "$1" in
                --mcp)       MCP_URL="$2" ;;
                --mcp-tool)  MCP_TOOL="$2" ;;
                --mcp-args)  MCP_ARGS="$2" ;;
                --mcp-token) MCP_TOKEN="$2" ;;
            esac
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

if [ -n "$MCP_URL" ] && [ -z "$MCP_TOOL" ]; then
    printf '%s\n' "--mcp needs --mcp-tool: the tool the mcp-server README names for this check"
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
#    must answer. Every caller reaches the backend through Nginx only, so a release of
#    a workspace with a backend is not done without it.
if [ -n "$GATEWAY_URL" ]; then
    if printf '%s\n' "$SERVICES" | grep -qi 'nginx'; then
        pass "Nginx is a deployed service"
    else
        fail "No Nginx service in $COMPOSE_FILE: every caller must reach the backend through Nginx"
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

# 4. When an MCP server is required, it must be deployed, an MCP session must
#    initialize over Streamable HTTP, it must list its tools, and the named tool must
#    actually reach the backend. An MCP release has no screen to click through, so
#    these checks are its definition of done.
if [ -n "$MCP_URL" ]; then
    if printf '%s\n' "$SERVICES" | grep -qi 'mcp-server'; then
        pass "MCP server is a deployed service"
    else
        fail "No mcp-server service in $COMPOSE_FILE"
    fi

    MCP_HEADERS="$(mktemp)"
    trap 'rm -f "$MCP_HEADERS"' EXIT
    MCP_SESSION=""
    MCP_VERSION=""

    # One JSON-RPC message to the server. Adds the session, protocol version and bearer
    # token once they are known. The response may be plain JSON or an SSE stream.
    mcp_post() {
        set -- -s --max-time 20 -D "$MCP_HEADERS" \
            -H 'content-type: application/json' \
            -H 'accept: application/json, text/event-stream' \
            -d "$1"
        [ -n "$MCP_SESSION" ] && set -- "$@" -H "mcp-session-id: $MCP_SESSION"
        [ -n "$MCP_VERSION" ] && set -- "$@" -H "mcp-protocol-version: $MCP_VERSION"
        [ -n "$MCP_TOKEN" ] && set -- "$@" -H "authorization: Bearer $MCP_TOKEN"
        curl "$@" "$MCP_URL" 2>/dev/null
    }

    # 4a. initialize, then notifications/initialized.
    INIT_RESPONSE="$(mcp_post '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"done-check","version":"1.0.0"}}}')"
    MCP_SESSION="$(grep -i '^mcp-session-id:' "$MCP_HEADERS" | head -n 1 | sed -E 's/^[^:]+:[[:space:]]*//' | tr -d '\r')"
    MCP_VERSION="$(printf '%s' "$INIT_RESPONSE" | grep -o '"protocolVersion"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed -E 's/.*"([^"]*)"$/\1/')"
    MCP_STATUS="$(head -n 1 "$MCP_HEADERS" | awk '{print $2}')"

    if [ "$MCP_STATUS" = "401" ] || [ "$MCP_STATUS" = "403" ]; then
        fail "MCP server answered HTTP $MCP_STATUS to initialize: pass --mcp-token"
    elif [ -z "$MCP_VERSION" ]; then
        fail "MCP server at $MCP_URL did not complete initialize"
    else
        pass "MCP session initialized (protocol $MCP_VERSION${MCP_SESSION:+, session $MCP_SESSION})"
        mcp_post '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null

        # 4b. tools/list must include the named tool.
        TOOLS_RESPONSE="$(mcp_post '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')"
        if printf '%s' "$TOOLS_RESPONSE" | grep -q "\"name\"[[:space:]]*:[[:space:]]*\"$MCP_TOOL\""; then
            pass "tools/list responded and includes $MCP_TOOL"

            # 4c. Call it for real. A JSON-RPC error, or a result flagged isError, means
            #     the call did not get through the server, the gateway and the backend.
            CALL_RESPONSE="$(mcp_post "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"$MCP_TOOL\",\"arguments\":$MCP_ARGS}}")"
            if [ -z "$CALL_RESPONSE" ]; then
                fail "No response calling tool $MCP_TOOL"
            elif printf '%s' "$CALL_RESPONSE" | grep -q '"error"[[:space:]]*:'; then
                fail "Tool $MCP_TOOL returned a JSON-RPC error"
            elif printf '%s' "$CALL_RESPONSE" | grep -q '"isError"[[:space:]]*:[[:space:]]*true'; then
                fail "Tool $MCP_TOOL ran but returned isError: the backend call failed"
            elif printf '%s' "$CALL_RESPONSE" | grep -q '"result"'; then
                pass "Tool $MCP_TOOL reached the backend"
            else
                fail "Tool $MCP_TOOL returned no result"
            fi
        else
            fail "tools/list from $MCP_URL does not include $MCP_TOOL"
        fi
    fi
fi

# 5. Every entry point must respond. Any HTTP status below 500 counts as
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
    printf "Next: the required journeys run in the test zone, and\n"
    printf "preflight/journey-check.sh must pass before the release locks.\n"
    exit 0
else
    printf "${RED}NOT DONE${NC} - the release does not run yet.\n"
    exit 1
fi
