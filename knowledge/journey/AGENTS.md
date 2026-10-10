# Journey Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/journey/`

and governs the content of the workspace's `journey` repository.

## Purpose

A **journey** is the ordered path a real user walks through the system, including the
steps that have to be inserted to make the next one possible.

It sits a level above a scenario, and it is **not** a unit test.

```text
Journey: add an income record
  1. log in
  2. no account exists yet  ->  create an account        <- inserted because step 3 needs it
  3. open the account page
  4. add the income record
```

Step 2 is what makes this a journey rather than a scenario. The path is what the user
actually has to do, not the one step being exercised.

## Journeys gate the release, and the gate is bounded

A release is not done because its code builds and its containers start. It is done when
a real user's path through it has been **walked and verified**, end to end, through the
real UI, against the full system.

So the required journeys of a release are part of its definition of done:

- The release is **not locked** until every required journey has **passed** in the test
  zone, and the test zone has been **cleaned up**. `preflight/journey-check.sh` verifies
  both.
- A failing required journey sends the release into **rework**: collect the evidence,
  find the root cause, fix the code, configuration or script, rebuild and redeploy, and
  run the journeys again.
- Rework is **bounded at 3 rounds.** The first run is not a round; rounds 1 to 3 each
  follow a failed run. If the journeys still fail after round 3, the loop **stops** and
  the human is asked what happens next (see **When the rounds run out**).

The bound is what keeps this on the right side of the rule in `agents/AGENTS.md`. A
gate that waits for journeys to pass, with no limit, is a loop with no end. A gate with a
fixed number of rounds and a human at the end of it is not.

The gate is **mechanical**. A journey passes or fails on its own assertions, which come
from the journey document, which comes from the specification. No agent judges whether
code is good enough, and the Journey Test Agent is still not a reviewer: it reports what
the journeys did, and the result decides.

### Which journeys are required

The required journeys of release `n` are the ones that walk its scope: every journey the
Journey Test Agent writes or updates for release `n`. The run report lists them by slug
before the first run, and that list does not change between rounds.

A release with no screen a user walks through — an `mcp-server` alone, a batch job, a
listener — has no required journeys. It writes no run report, and `done-check.sh` alone
decides whether it is done.

Journeys from earlier releases that release `n` does not touch may also run. Their
failures are reported and become a `type: change` release; they do not hold release `n`
open.

### A fix never weakens a journey

During rework the easy way to make a journey pass is to make it test less. That is
forbidden.

- A script fix may change **how** a step is performed — a selector, a wait, a label —
  never **whether** it is performed or **what** is asserted at the end.
- The journey document may be corrected only where it disagrees with the release or
  screen specification, and the correction is to match the specification.
- Removing a step, an assertion or a whole required journey, marking one skipped, or
  loosening an expected value so it passes, is never a fix.

## The order inside a release

```text
Coding Agents implement          run natively in the develop zone
      |
      v
build images, deploy             preflight/done-check.sh passes
      |
      v
write or update journeys         documents, then mock data, then scripts
      |
      v
provision the test zone          its own containers, from the images just deployed
      |
      v
wait for readiness               every container healthy, the gateway answering
      |
      v
run the required journeys        desktop mode by default; mock data per journey
      |
      +-- any failed --> evidence --> root cause --> fix --> rebuild/redeploy --> run again
      |                                                      (at most 3 rounds)
      v
all passed --> clean up the test zone --> preflight/journey-check.sh --> lock
```

## The document comes before the script

A journey is written down before it is automated. The order is not optional.

1. **Read.** The release and screen specifications in the `requirement` repository, and
   the source code of the repositories involved.
2. **Write the journey document.** How many journeys the system has, and the ordered
   steps of each — including the inserted ones.
3. **Write the mock data** each journey needs to start from.
4. **Then** write the script: Playwright for web, Maestro for mobile.

An agent that writes a script without a journey document has skipped the step where it
works out what the user actually does.

## Repository layout

One `journey` repository per workspace.

```text
<workspace>-journey/
├── journeys/
│   └── <slug>.md            # one file per journey, from templates/journey.md
├── mock-data/
│   └── <slug>.py            # the data that journey starts from
├── web/
│   ├── playwright.config.ts # from templates/playwright.config.ts
│   └── <slug>.spec.ts       # from templates/journey.spec.ts
├── mobile/
│   └── <slug>.yaml          # from templates/journey.flow.yaml
├── runs/
│   ├── release-<n>.md       # from templates/run-report.md; one per release
│   └── release-<n>/         # the runner reports the gate reads; kept
├── .storage-state/          # git-ignored; see Provider login below
└── README.md
```

| Template | Copy to |
|---|---|
| `templates/journey.md` | `journeys/<slug>.md` |
| `templates/playwright.config.ts` | `web/playwright.config.ts` |
| `templates/journey.spec.ts` | `web/<slug>.spec.ts` |
| `templates/journey.flow.yaml` | `mobile/<slug>.yaml` |
| `templates/run-report.md` | `runs/release-<n>.md` |
| `templates/test-zone.yml` | `${WORKSPACE_PATH}/local-env/test/compose.yml` |

Versions come from the `testing` section of `knowledge/tech-stack.yaml`: Playwright for
web, Maestro for mobile.

## Mock data

Mock data belongs to the journey that needs it.

- It is written **with** the journeys, not after, and it is **injected at the start of
  each journey run** so the run starts from a known state.
- It reaches the datastore through the Python tools in the `tool` repository, like every
  other datastore access. See `knowledge/tools/AGENTS.md`.
- It targets the **test zone's** datastore, never the develop zone's.

Mock data for the **human** to click around in after development is a separate purpose
with the same mechanism: it goes into the develop zone, and it is not tied to a journey.

## Two zones

The develop zone and the test zone are separate, and they do not share resources.

| | Develop zone | Test zone |
|---|---|---|
| Purpose | the human clicks through it for fast feedback; the agent fixes and restarts | journeys run against it |
| Dependencies | containers, per workspace, from `knowledge/local-env/` | **its own** containers, started in addition |
| The application | **started natively** — no container, so fix-and-restart stays fast | run as containers **from the images the release built for its deploy** |
| Compose project | `$WORKSPACE_NAME` | `$WORKSPACE_NAME-test`, with its own network, volumes and host ports |
| Data | mock data for the human to click | mock data injected per journey |
| Lifetime | across releases, until the human destroys it | one release: provisioned after the deploy, removed once the journeys pass |

The test zone exists because a journey needs a known starting state, and the human's
develop zone is full of whatever they have been clicking on. Starting a journey by
wiping their data would be the wrong trade.

Running the application from the deploy's own images is deliberate: what passes the
journeys is exactly what was deployed, not a second build of it. The test zone does not
build images of its own. When something runs natively but fails in the
container, the answer is to investigate and fix it — a runtime difference, a wrong image
version — and redeploy. No one is assigned fault for the difference.

### Provisioning the test zone

1. Copy `templates/test-zone.yml` to `${WORKSPACE_PATH}/local-env/test/compose.yml`.
2. Keep **only** the services the release actually uses. A release with no Kafka gets
   no Kafka container. Dependencies come from the same knowledge templates as the
   develop zone (`knowledge/database/`, `knowledge/redis/`, `knowledge/kafka/`).
3. Point the application services at the image tags the release just deployed.
4. Include Nginx. Journeys reach the backend through the test zone's gateway, like
   every other caller.
5. `docker compose -p "$WORKSPACE_NAME-test" -f compose.yml up -d --wait`
6. **Wait for readiness** before any journey starts: every service healthy, the gateway
   answering. A journey that fails because a container was still starting is not a
   journey failure; it is a provisioning step that was skipped.

### Rework

When a run has a failed required journey:

1. **Collect the evidence** into the run report: which journey, which step, the
   Playwright trace and screenshot (or the Maestro output), and the logs of the
   containers involved.
2. **Analyze the root cause** and record it in the run report, with the repository it
   points to:

   | Root cause | Fixed by |
   |---|---|
   | product code or its configuration | the Coding Agent that owns that repository, given the run report by the Release Agent |
   | the journey script or its mock data | the Journey Test Agent, in the `journey` repository |
   | the test zone itself | the Journey Test Agent, in `local-env/test/` |

3. **Fix**, within the rules in **A fix never weakens a journey**.
4. **Rebuild and redeploy** when product code changed: the owning Coding Agent
   rebuilds, the Release Agent redeploys and passes `preflight/done-check.sh` again, then
   the test zone is pointed at the new image tags.
5. **Run the required journeys again.** All of them, not only the one that failed: a
   fix in one place can break another.

The test zone stays up between rounds. Each journey re-injects its own mock data, so a
round still starts from a known state.

### Clean up

When every required journey has passed, clean up **without asking**:

1. Stop and remove the test zone's containers.
2. Remove its volumes, which is where the test data lives.
3. Remove its networks and any orphan containers.
4. Delete temporary run output: Playwright's `test-results/` and HTML report, Maestro
   output, anything written under `local-env/test/` while running. The runner reports
   under `runs/release-<n>/` are **not** temporary; they stay.

```bash
docker compose -p "$WORKSPACE_NAME-test" -f compose.yml down --volumes --remove-orphans
```

The images are **not** removed: they belong to the deploy. The run report in
`runs/release-<n>.md` is **kept**: it is the record of what passed.

Then run `preflight/journey-check.sh`. The Release Agent locks the release only after
it passes.

### When the rounds run out

If the required journeys still fail after rework round 3, stop. The test zone is **kept
up** so the human can look at it, the release stays `in_progress`, and the agent asks:

```text
Release <n>: <k> required journeys still fail after 3 rework rounds. What now?

  1. Lock anyway       — the release locks; each failing journey becomes a type: change release
  2. Three more rounds — rework continues, bounded at 3 more
  3. Leave it open     — the release stays in_progress and nothing runs until you say so
  4. Something else    — type your answer
```

This question has **no recommended option**, so it is asked even when
`workspace.auto_recommend` is `true`, and it stops the run even when
`release_execution` is `auto`.

Every answer is recorded in the run report, in two places: the answer's key appended to
`human_decisions` in the front matter, and the human's own words, quoted, under
**Human decisions** in the body.

| Answer | Key | Effect |
|---|---|---|
| Lock anyway | `lock-anyway` | the test zone is cleaned up as above; `result: accepted` instead of `passed` |
| Three more rounds | `more-rounds` | `max_rounds` goes up by 3 and rework continues |
| Leave it open | `leave-open` | nothing runs until the human says so |

`journey-check.sh` accepts `result: accepted` only when the last recorded decision is
`lock-anyway`, and allows `rounds` above 3 only as far as the recorded `more-rounds`
answers raise `max_rounds`.

## Runner reports: what the gate reads

The run report's front matter is written by the Journey Test Agent, so on its own it
would be the agent's word. `preflight/journey-check.sh` therefore also reads what the
test runner itself wrote, and the two must agree.

For every run `k` (the first run is `0`), the runner's report is kept beside the run
report:

| Platform | Command shape | Kept at |
|---|---|---|
| web | `JOURNEY_REPORT_FILE=../runs/release-<n>/run-<k>.web.json npx playwright test` | `runs/release-<n>/run-<k>.web.json` |
| mobile | `maestro test --format junit --output runs/release-<n>/run-<k>.mobile.xml mobile/` | `runs/release-<n>/run-<k>.mobile.xml` |

- `last_run` in the front matter names the run the result was taken from.
- In the Playwright report a journey is its `<slug>.spec.ts` file; it passed when every
  test in that file has status `expected`. A `skipped` or `flaky` test is not a pass.
- In the Maestro report a journey is the test case named `<slug>` — the flow's `name`
  field; it passed when it has no `failure` or `error`.
- A required journey that appears in neither report of `last_run` did not run.

These files are committed with the journey repository and never deleted at cleanup.

## Desktop or background mode

**Desktop is the default**: a visible browser, at a desktop viewport, so the human can
watch what the journey does. The agent asks once per release, before the first run, and
every rework round reuses the answer:

```text
Run the journeys in desktop or background mode?

  1. Desktop     — a visible browser or emulator; you watch it happen  [recommended]
  2. Background  — headless; faster, nothing to watch
  3. Something else — type your answer
```

With `workspace.auto_recommend: true` desktop is taken without asking. When the human
does not answer, it is desktop.

**The exception, which overrides the question:** a journey that needs a human to click
something — a provider login screen above all — is **forced to desktop mode**, and the
question is not asked for that run. Background mode cannot wait for a person.

## Provider login

A journey test does not type its way through a provider's login screen.

1. The first run opens it and **the human signs in**.
2. The browser's storage state — cookies and local storage — is saved under
   `.storage-state/`.
3. Later runs load that file and begin already signed in.
4. When it expires, the login screen comes back and the human signs in once more.

`.storage-state/` is git-ignored. It holds a live session: never committed, never copied
between environments. Full rules: `knowledge/auth/AGENTS.md`.

## Must not

- Modify the knowledge files in this directory during normal project generation.
- Lock a release before every required journey has passed, or the human has chosen
  "lock anyway" after the rounds ran out.
- Run more than 3 rework rounds without asking the human.
- Make a journey pass by removing, skipping or loosening a step, an assertion or a
  required journey.
- Count a generated script as a passed journey. A journey passes only by running.
- Record a journey's result anywhere but from its runner report, or delete or edit a
  runner report.
- Write a journey script before the journey document exists.
- Run journeys against the develop zone, or inject journey mock data into it.
- Build application images for the test zone instead of using the deploy's.
- Leave the test zone's containers, volumes or networks behind after the journeys pass.
- Tear down the develop zone's containers.
- Ask the mode question when a human has to click something.
- Commit a storage state file.
- Reach a datastore from a journey by any path but the Python tools.
