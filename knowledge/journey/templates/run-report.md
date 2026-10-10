---
release: release-<n>
mode: desktop                    # desktop | background
rounds: 0                        # rework rounds used so far
max_rounds: 3                    # 3, plus 3 for each recorded more-rounds decision
last_run: 0                      # the run whose runner reports the result is taken from
human_decisions: []              # lock-anyway | more-rounds | leave-open, in the order given
result: running                  # running | passed | failed | exhausted | accepted
test_project: <workspace>-test   # the test zone's compose project
cleaned_up: false                # true once the test zone has been removed
journeys:                        # the required journeys, fixed before the first run
  add-income-record: pending     # pending | passed | failed
---

# Journey run: release <n>

`preflight/journey-check.sh` reads the front matter above **and** the runner reports in
`runs/release-<n>/run-<last_run>.*`. The release locks only when `result` is `passed`
(or `accepted`, after the human chose "lock anyway"), every required journey is `passed`
in both this file and the runner's report (unless accepted), `rounds` is within
`max_rounds`, `cleaned_up` is `true`, and nothing of `test_project` is left on the
Docker host.

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

- Runner report: `runs/release-<n>/run-0.web.json` (kept)
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

## Human decisions

Only when the rework rounds ran out. One entry per answer, in order, with the human's own
words quoted.

- after round 3: `more-rounds` — "<what the human typed>"

## Cleanup

- [ ] containers stopped and removed
- [ ] volumes removed (test data)
- [ ] networks and orphans removed
- [ ] temporary run output deleted (runner reports under `runs/` kept)
