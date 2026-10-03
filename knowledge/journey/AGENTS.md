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

## Journey tests are not a gate

**This is the rule that keeps the framework's shape.**

A journey test is an **artifact**, like code or a specification. It is not a
checkpoint, and nothing waits on it.

- A failing journey **does not block a release.** The definition of done is unchanged:
  the release deploys to the local Docker host, can be clicked through, and
  `preflight/done-check.sh` passes.
- A journey that fails produces a `type: change` release, exactly like a defect the
  human finds by clicking through the system themselves.
- No agent reviews another agent's work through a journey, and no agent asks whether
  its own output is good enough because a journey failed.

`agents/AGENTS.md` forbids a QA agent and a reviewer agent because they reintroduce a
loop with no end. Journey tests stay on the right side of that line only as long as they
have no veto. A rule of the form "every journey must pass before the release locks" is
exactly the thing that must not be added.

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
├── .storage-state/          # git-ignored; see Provider login below
└── README.md
```

| Template | Copy to |
|---|---|
| `templates/journey.md` | `journeys/<slug>.md` |
| `templates/playwright.config.ts` | `web/playwright.config.ts` |
| `templates/journey.spec.ts` | `web/<slug>.spec.ts` |
| `templates/journey.flow.yaml` | `mobile/<slug>.yaml` |

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
| The application | **started natively** — no container, so fix-and-restart stays fast | **built as a Docker image** and run as a container |
| Data | mock data for the human to click | mock data injected per journey |

The test zone exists because a journey needs a known starting state, and the human's
develop zone is full of whatever they have been clicking on. Starting a journey by
wiping their data would be the wrong trade.

Building the application as a container for the test zone is deliberate: it is closer to
what the definition of done deploys. When something runs natively but fails in the
container, the answer is to investigate and fix it — a runtime difference, a wrong image
version — and redeploy. No one is assigned fault for the difference.

### After a run

The agent **asks** whether to keep the test resources, through
`knowledge/questions/AGENTS.md`:

```text
Keep the test resources from this journey run?

  1. Keep them          — the containers and data stay up so you can look through them
  2. Tear them down     — containers and data for the test zone are removed  [recommended]
  3. Something else     — type your answer
```

On "tear them down" the agent may remove the **test zone's** containers and data. It
never touches the develop zone's, whose lifecycle is in
`knowledge/local-env/AGENTS.md` and whose `destroy` only the human asks for.

## Desktop or background mode

The agent asks which mode to run in:

```text
Run the journeys in desktop or background mode?

  1. Desktop     — a visible browser or emulator; you watch it happen
  2. Background  — headless; faster, nothing to watch
  3. Something else — type your answer
```

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
- Let a journey result block, gate or delay a release.
- Write a journey script before the journey document exists.
- Run journeys against the develop zone, or inject journey mock data into it.
- Tear down the develop zone's containers.
- Ask the mode question when a human has to click something.
- Commit a storage state file.
- Reach a datastore from a journey by any path but the Python tools.
