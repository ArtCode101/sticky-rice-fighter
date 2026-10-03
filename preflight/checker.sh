#!/usr/bin/env bash
#
# checker.sh - checks machine readiness for the sticky-rice-fighter stack:
#   1. Java 25
#   2. Node.js 24, and the npm that ships with it
#   3. Docker
#   4. Python 3
#
# Mobile tooling is checked too, but only WARNS when missing: a workspace without a
# mobile repository does not need it, so a missing emulator is not a reason to block.
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

# 2b. npm, which builds the frontend and the MCP server. It ships with Node.js, so a
#     missing npm means a broken Node installation rather than a separate install.
if command -v npm >/dev/null 2>&1; then
    pass "npm detected ($(npm -v))"
else
    fail "npm not found in PATH: the frontend and MCP server are built with npm and tsc"
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

# 4. Python 3.13 (fixed version, used for Playwright and tooling)
REQUIRED_PYTHON="3.13"
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION_RAW="$(python3 --version 2>&1)"
    PYTHON_MINOR_VERSION="$(echo "$PYTHON_VERSION_RAW" | sed -E 's/^Python ([0-9]+\.[0-9]+).*/\1/')"
    if [ "$PYTHON_MINOR_VERSION" = "$REQUIRED_PYTHON" ]; then
        pass "Python $REQUIRED_PYTHON detected ($PYTHON_VERSION_RAW)"
    else
        fail "Python $REQUIRED_PYTHON required, found: $PYTHON_VERSION_RAW"
    fi
else
    fail "Python 3 not found in PATH"
fi

# 5. Mobile tooling. Needed only when the workspace has a mobile repository, so these
#    warn rather than fail. React Native and Expo themselves install per project.
if command -v adb >/dev/null 2>&1; then
    pass "adb detected - the agent can drive the Android Emulator"
else
    warn "adb not found: needed to drive the Android Emulator for a mobile repository"
fi

# Presence only. Do not invoke these tools to read a version: xcrun can block for a
# long time when the Xcode tooling is not fully installed, and this script must stay
# fast enough to run before every piece of work.
if [ "$(uname -s)" = "Darwin" ]; then
    if command -v xcrun >/dev/null 2>&1; then
        pass "xcrun detected - simctl can drive the iOS Simulator"
    else
        warn "xcrun not found: needed to drive the iOS Simulator (install Xcode)"
    fi
else
    warn "iOS Simulator runs on macOS only: this machine can build and test Android only"
fi

if command -v maestro >/dev/null 2>&1; then
    pass "Maestro detected"
else
    warn "Maestro not found: needed to run mobile journeys"
fi

echo "-----------------------------------"
if [ "$FAILED" -eq 0 ]; then
    printf "${GREEN}All checks passed. Machine is ready.${NC}\n"
    exit 0
else
    printf "${RED}Some checks failed. Machine is NOT ready.${NC}\n"
    exit 1
fi
