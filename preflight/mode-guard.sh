#!/usr/bin/env bash
#
# mode-guard.sh - enforcement point for the framework operating mode.
#
# Reads `mode` from flag.yml at the repository root and reports whether writes
# inside this framework repository are allowed.
#
# Exit codes:
#   0 - mode is "edit": the framework is open for editing
#   1 - mode is "working": the framework is locked, no agent may write to it
#   2 - the mode could not be determined (missing file or unknown value)
#
set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG_FILE="$SCRIPT_DIR/../flag.yml"

if [ ! -f "$FLAG_FILE" ]; then
    printf "${RED}[ERROR]${NC} flag.yml not found at %s\n" "$FLAG_FILE"
    exit 2
fi

# Read the first uncommented `mode:` entry.
MODE="$(sed -E -n 's/^[[:space:]]*mode:[[:space:]]*([A-Za-z]+).*/\1/p' "$FLAG_FILE" | head -n 1)"

case "$MODE" in
    edit)
        printf "${GREEN}[EDIT]${NC}    Framework is open for editing. Writes allowed.\n"
        exit 0
        ;;
    working)
        printf "${RED}[WORKING]${NC} Framework is locked. No agent may write to this repository.\n"
        exit 1
        ;;
    "")
        printf "${RED}[ERROR]${NC} No 'mode' key found in %s\n" "$FLAG_FILE"
        exit 2
        ;;
    *)
        printf "${RED}[ERROR]${NC} Unknown mode '%s' in %s (expected 'edit' or 'working')\n" "$MODE" "$FLAG_FILE"
        exit 2
        ;;
esac
