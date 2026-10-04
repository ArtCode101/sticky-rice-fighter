---
release: release-<n>
mode: desktop                    # desktop | background
rounds: 0                        # rework rounds used so far, at most 3 before asking the human
result: running                  # running | passed | failed | exhausted | accepted
test_project: <workspace>-test   # the test zone's compose project
cleaned_up: false                # true once the test zone has been removed
journeys:                        # the required journeys, fixed before the first run
  add-income-record: pending     # pending | passed | failed
---

# Journey run: release <n>

`preflight/journey-check.sh` reads the front matter above. The release locks only when
`result` is `passed` (or `accepted`, after the human chose "lock anyway"), every required
journey is `passed` (unless accepted), `cleaned_up` is `true`, and nothing of
`test_project` is left on the Docker host.

## Required journeys

The journeys that walk this release's scope. This list is written before the first run
and does not change between rounds.

| Journey | Platform | Document |
|---|---|---|
| `add-income-record` | web | `journeys/add-income-record.md` |

## Runs

One section per run. The first run is run 0; each later run follows one rework round.

### Run 0

| Journey | Result | Failed at step |
|---|---|---|
| `add-income-record` | failed | 4 — the record does not appear in the list |

#### Evidence

- Trace: `web/test-results/<...>/trace.zip` (deleted at cleanup; summarize what it showed here)
- Screenshot: what was on screen at the failing step
- Container logs: the lines that matter, from the services involved

#### Root cause

What actually went wrong, and which repository it points to.

| Root cause in | Repository | Fixed by |
|---|---|---|
| product code | `<workspace>-backend-account` | Coding Agent |

#### Fix

What changed, and the new image tags deployed. A fix changes how a step is performed,
never whether it is performed or what is asserted.

### Run 1

| Journey | Result | Failed at step |
|---|---|---|
| `add-income-record` | passed | |

## Cleanup

- [ ] containers stopped and removed
- [ ] volumes removed (test data)
- [ ] networks and orphans removed
- [ ] temporary run output deleted
