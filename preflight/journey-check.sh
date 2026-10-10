#!/usr/bin/env bash
#
# journey-check.sh - verifies the journey half of a release's definition of done.
#
# done-check.sh proves the release deploys and runs. This script proves the rest:
# every required journey ran and passed in the test zone, and the test zone has been
# cleaned up. A release locks only when both scripts pass.
#
# It reads the front matter of the release's run report (from
# knowledge/journey/templates/run-report.md), checks every required journey against
# the test runner's own report for the last run (runs/release-<n>/run-<k>.web.json from
# Playwright, run-<k>.mobile.xml from Maestro), and asks Docker whether anything of the
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

if ! command -v python3 >/dev/null 2>&1; then
    printf "${RED}[FAIL]${NC} python3 is required (see preflight/checker.sh)\n"
    exit 1
fi

# 1-3. The run report and the runner reports. Python prints one line per check,
#      "OK <message>" or "FAIL <message>", and a final "PROJECT <name>" line.
# The script is read into a variable first: bash 3.2, the macOS default, cannot parse a
# quoted heredoc inside $(...).
read -r -d '' CHECK_SCRIPT <<'PY'
import json, os, re, sys
import xml.etree.ElementTree as ET

report = sys.argv[1]
out = []
ok = lambda m: out.append("OK " + m)
bad = lambda m: out.append("FAIL " + m)

lines = open(report, encoding="utf-8").read().splitlines()
if not lines or lines[0].strip() != "---":
    print("FAIL no front matter in " + report); print("PROJECT "); sys.exit(0)
front = []
for line in lines[1:]:
    if line.strip() == "---":
        break
    front.append(line)

def strip(v):
    v = re.sub(r"\s+#.*$", "", v).strip()
    return v.strip("\"'")

scalars, journeys, decisions, current = {}, {}, [], None
for line in front:
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    if not line[0].isspace():
        key, _, value = line.partition(":")
        key, value = key.strip(), strip(value)
        current = key
        if key == "human_decisions" and value.startswith("["):
            decisions = [strip(x) for x in value.strip("[]").split(",") if strip(x)]
        else:
            scalars[key] = value
    elif current == "journeys" and ":" in line:
        slug, _, status = line.strip().partition(":")
        journeys[slug.strip()] = strip(status)
    elif current == "human_decisions" and line.strip().startswith("-"):
        decisions.append(strip(line.strip()[1:]))

result = scalars.get("result", "")
accepted = result == "accepted"

# 1. The run's overall result. 'accepted' is valid only when the human's last
#    recorded answer was "lock anyway".
if result == "passed":
    ok("Run result: passed")
elif accepted and decisions and decisions[-1] == "lock-anyway":
    ok("Run result: accepted by the human after the rework rounds ran out")
elif accepted:
    bad("Run result is 'accepted' but the last human decision is not lock-anyway")
elif not result:
    bad("Run report has no result")
else:
    bad("Run result is '%s', not passed" % result)

# 2. Rounds stay within the bound: 3, plus 3 for each recorded "three more rounds".
try:
    rounds = int(scalars.get("rounds", ""))
    max_rounds = int(scalars.get("max_rounds", "3"))
    allowed = 3 * (1 + decisions.count("more-rounds"))
    if max_rounds != allowed:
        bad("max_rounds is %d, but the recorded decisions allow %d" % (max_rounds, allowed))
    elif rounds > max_rounds:
        bad("%d rework rounds used, more than the %d allowed" % (rounds, max_rounds))
    else:
        ok("Rework rounds within bound: %d of %d" % (rounds, max_rounds))
except ValueError:
    bad("Run report has no numeric rounds / max_rounds")

# 3. Every required journey, in the run report and in the runner's own report.
last_run = scalars.get("last_run", "")
base = os.path.join(os.path.dirname(os.path.abspath(report)),
                    os.path.splitext(os.path.basename(report))[0])
runner = {}
web = os.path.join(base, "run-%s.web.json" % last_run)
mobile = os.path.join(base, "run-%s.mobile.xml" % last_run)

def walk(suite, file_name):
    file_name = suite.get("file") or file_name
    for spec in suite.get("specs", []):
        slug = os.path.basename(spec.get("file") or file_name or "")
        slug = re.sub(r"\.spec\.ts$", "", slug)
        statuses = [t.get("status") for t in spec.get("tests", [])]
        good = bool(statuses) and all(s == "expected" for s in statuses)
        runner[slug] = runner.get(slug, True) and good
    for child in suite.get("suites", []):
        walk(child, file_name)

if not last_run:
    bad("Run report has no last_run")
else:
    found = False
    if os.path.isfile(web):
        found = True
        try:
            for suite in json.load(open(web, encoding="utf-8")).get("suites", []):
                walk(suite, None)
        except (ValueError, AttributeError):
            bad("Unreadable Playwright report: " + web)
    if os.path.isfile(mobile):
        found = True
        try:
            for case in ET.parse(mobile).iter("testcase"):
                failed = case.find("failure") is not None or case.find("error") is not None
                runner[case.get("name", "")] = runner.get(case.get("name", ""), True) and not failed
        except ET.ParseError:
            bad("Unreadable Maestro report: " + mobile)
    if not found:
        bad("No runner report for run %s under %s" % (last_run, base))

if not journeys:
    bad("Run report lists no required journeys")
for slug, status in journeys.items():
    in_runner = runner.get(slug)
    if status == "passed" and in_runner:
        ok("Journey passed: %s (runner report agrees)" % slug)
    elif status == "passed" and in_runner is None:
        bad("Journey %s is marked passed but is not in the runner report of run %s" % (slug, last_run))
    elif status == "passed":
        bad("Journey %s is marked passed but the runner report says it failed" % slug)
    elif accepted and decisions and decisions[-1] == "lock-anyway":
        ok("Journey %s, accepted by the human: %s (becomes a type: change release)" % (status, slug))
    else:
        bad("Journey %s: %s" % (status, slug))

# 4a. The report must say the test zone was cleaned up.
if scalars.get("cleaned_up") == "true":
    ok("Run report records cleanup")
else:
    bad("Run report does not record cleanup (cleaned_up: %s)" % (scalars.get("cleaned_up") or "missing"))

print("\n".join(out))
print("PROJECT " + scalars.get("test_project", ""))
PY
CHECKS="$(python3 -c "$CHECK_SCRIPT" "$REPORT")"

PROJECT=""
while IFS= read -r line; do
    case "$line" in
        "OK "*)      pass "${line#OK }" ;;
        "FAIL "*)    fail "${line#FAIL }" ;;
        "PROJECT "*) PROJECT="${line#PROJECT }" ;;
    esac
done <<< "$CHECKS"

# 4b. ...and Docker must agree. Nothing labelled with the test zone's compose project may
#     be left: no container, no volume (the test data), no network. Images are not
#     checked; they belong to the deploy.
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
    if grep -qE '^result:[[:space:]]*accepted' "$REPORT"; then
        printf "${GREEN}DONE${NC} - the human accepted the failing journeys and the test zone is gone.\n"
    else
        printf "${GREEN}DONE${NC} - required journeys passed and the test zone is gone.\n"
    fi
    printf "With done-check.sh also passing, the Release Agent may lock the release.\n"
    exit 0
else
    printf "${RED}NOT DONE${NC} - the release does not lock yet.\n"
    exit 1
fi
