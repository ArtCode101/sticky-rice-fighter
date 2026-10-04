#!/usr/bin/env bash
#
# journey-check.sh - verifies the journey half of a release's definition of done.
#
# done-check.sh proves the release deploys and runs. This script proves the rest:
# every required journey ran and passed in the test zone, and the test zone has been
# cleaned up. A release locks only when both scripts pass.
#
# It reads the front matter of the release's run report (from
# knowledge/journey/templates/run-report.md) and asks Docker whether anything of the
# test zone's compose project is left behind.
#
# Usage:
#   preflight/journey-check.sh <run-report>
#
# Example:
#   preflight/journey-check.sh \
#       ../my-workspace/my-workspace-journey/runs/release-3.md
#
# Exit codes:
#   0 - done: required journeys passed (or were accepted by the human) and the
#       test zone is gone
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

if [ "$#" -ne 1 ]; then
    printf "usage: %s <run-report>\n" "$0"
    exit 2
fi

REPORT="$1"

if [ ! -f "$REPORT" ]; then
    printf "${RED}[FAIL]${NC} run report not found: %s\n" "$REPORT"
    exit 1
fi

# The front matter is everything between the first two '---' lines.
FRONT="$(awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside {print}' "$REPORT")"
if [ -z "$FRONT" ]; then
    printf "${RED}[FAIL]${NC} no front matter in %s\n" "$REPORT"
    exit 1
fi

# Top-level scalar from the front matter, without its trailing comment.
field() {
    printf '%s\n' "$FRONT" \
        | grep -E "^$1:" \
        | head -n 1 \
        | sed -E "s/^$1:[[:space:]]*//; s/[[:space:]]*#.*$//; s/^[\"']//; s/[\"']$//"
}

RESULT="$(field result)"
CLEANED="$(field cleaned_up)"
PROJECT="$(field test_project)"

# 1. The run's overall result. 'accepted' means the human chose "lock anyway" after
#    the rework rounds ran out; it is the only way a failing journey reaches a lock.
case "$RESULT" in
    passed)   pass "Run result: passed" ;;
    accepted) pass "Run result: accepted by the human after the rework rounds ran out" ;;
    "")       fail "Run report has no result" ;;
    *)        fail "Run result is '$RESULT', not passed" ;;
esac

# 2. Every required journey. Entries are the indented 'slug: status' lines under
#    'journeys:'. A required journey that never ran is as unfinished as one that failed.
JOURNEYS="$(printf '%s\n' "$FRONT" \
    | awk '/^journeys:/ {inside=1; next} inside && /^[^[:space:]]/ {exit} inside {print}' \
    | sed -E 's/[[:space:]]*#.*$//' \
    | grep -E '^[[:space:]]+[^[:space:]]+:' || true)"

if [ -z "$JOURNEYS" ]; then
    fail "Run report lists no required journeys"
else
    while IFS= read -r line; do
        slug="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+([^:]+):.*/\1/')"
        status="$(printf '%s' "$line" | sed -E 's/^[^:]+:[[:space:]]*//')"
        if [ "$status" = "passed" ]; then
            pass "Journey passed: $slug"
        elif [ "$RESULT" = "accepted" ]; then
            pass "Journey $status, accepted by the human: $slug (becomes a type: change release)"
        else
            fail "Journey $status: $slug"
        fi
    done <<< "$JOURNEYS"
fi

# 3. The report must say the test zone was cleaned up...
if [ "$CLEANED" = "true" ]; then
    pass "Run report records cleanup"
else
    fail "Run report does not record cleanup (cleaned_up: ${CLEANED:-missing})"
fi

# 4. ...and Docker must agree. Nothing labelled with the test zone's compose project may
#    be left: no container, no volume (the test data), no network. Images are not
#    checked; they belong to the deploy.
if [ -z "$PROJECT" ]; then
    fail "Run report has no test_project"
elif ! docker info >/dev/null 2>&1; then
    fail "Docker daemon is not running; cannot confirm the test zone is gone"
else
    LABEL="label=com.docker.compose.project=$PROJECT"

    CONTAINERS="$(docker ps -a -q --filter "$LABEL" 2>/dev/null)"
    VOLUMES="$(docker volume ls -q --filter "$LABEL" 2>/dev/null)"
    NETWORKS="$(docker network ls -q --filter "$LABEL" 2>/dev/null)"

    if [ -z "$CONTAINERS" ]; then
        pass "No test zone containers left ($PROJECT)"
    else
        fail "Test zone containers still exist for $PROJECT"
    fi

    if [ -z "$VOLUMES" ]; then
        pass "No test zone volumes left ($PROJECT)"
    else
        fail "Test zone volumes (test data) still exist for $PROJECT"
    fi

    if [ -z "$NETWORKS" ]; then
        pass "No test zone networks left ($PROJECT)"
    else
        fail "Test zone networks still exist for $PROJECT"
    fi
fi

printf -- "-----------------------------------\n"
if [ "$FAILED" -eq 0 ]; then
    if [ "$RESULT" = "accepted" ]; then
        printf "${GREEN}DONE${NC} - the human accepted the failing journeys and the test zone is gone.\n"
    else
        printf "${GREEN}DONE${NC} - required journeys passed and the test zone is gone.\n"
    fi
    printf "With done-check.sh also passing, the release may be locked.\n"
    exit 0
else
    printf "${RED}NOT DONE${NC} - the release does not lock yet.\n"
    exit 1
fi
