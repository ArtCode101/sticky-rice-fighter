#!/usr/bin/env bash
#
# checker.sh - checks machine readiness for the sticky-rice-fighter stack:
#   1. Java 25
#   2. Node.js 24
#   3. Docker
#
set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

FAILED=0

pass() { printf "${GREEN}[OK]${NC}   %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC} %s\n" "$1"; FAILED=1; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }

# 1. Java 25
if command -v java >/dev/null 2>&1; then
    JAVA_VERSION_RAW="$(java -version 2>&1 | head -n 1)"
    JAVA_MAJOR="$(java -version 2>&1 | head -n 1 | sed -E 's/.*"([0-9]+)[^"]*".*/\1/')"
    if [ "$JAVA_MAJOR" = "25" ]; then
        pass "Java version 25 detected ($JAVA_VERSION_RAW)"
    else
        fail "Java 25 required, found: $JAVA_VERSION_RAW"
    fi
else
    fail "Java not found in PATH"
fi

# 2. Node.js 24
if command -v node >/dev/null 2>&1; then
    NODE_VERSION_RAW="$(node -v)"
    NODE_MAJOR="$(echo "$NODE_VERSION_RAW" | sed -E 's/^v([0-9]+).*/\1/')"
    if [ "$NODE_MAJOR" = "24" ]; then
        pass "Node.js version 24 detected ($NODE_VERSION_RAW)"
    else
        fail "Node.js 24 required, found: $NODE_VERSION_RAW"
    fi
else
    fail "Node.js not found in PATH"
fi

# 3. Docker
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION="$(docker --version 2>&1)"
    if docker info >/dev/null 2>&1; then
        pass "Docker detected and running ($DOCKER_VERSION)"
    else
        warn "Docker detected but daemon is not running ($DOCKER_VERSION)"
        FAILED=1
    fi
else
    fail "Docker not found in PATH"
fi

echo "-----------------------------------"
if [ "$FAILED" -eq 0 ]; then
    printf "${GREEN}All checks passed. Machine is ready.${NC}\n"
    exit 0
else
    printf "${RED}Some checks failed. Machine is NOT ready.${NC}\n"
    exit 1
fi
