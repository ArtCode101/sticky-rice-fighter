# Agent Rules

## Scope

This file applies to all files under:

`agents/`

It is the single source for the flow, the gates, concurrency and file ownership. Other
files summarize these rules in a line and link here.

## Agents

| Agent | Definition | Human gate |
|---|---|---|
| Workspace Init Agent | `agents/workspace-init-agent.md` | no |
| Requirement Analysis Agent | `agents/requirement-analysis-agent.md` | **yes** |
| Release Agent | `agents/release-agent.md` | no |
| Coding Agent | `agents/coding-agent.md` | no |
| Journey Test Agent | `agents/journey-test-agent.md` | no |

There is deliberately no QA agent and no reviewer agent. Adding one reintroduces
the loop this framework exists to avoid.

The **Release Agent** is not one of those either. It runs the sequence — creates the
phase 2 repositories, starts a release, spawns the agents, deploys, locks — and every
decision it takes comes from a file, a script's exit code or the human's answer.

The **Journey Test Agent** is not one of those either. It writes journeys, mock data and
test scripts, runs them for real and cleans up. The **journeys** gate the release — a
release locks only when its required journeys pass — but that gate is mechanical and
bounded:

- A journey passes or fails on its own assertions, taken from the specification. No
  agent judges whether code is good enough.
- A failure sends the release into rework, at most **3 rounds**. Then the loop stops
  and the human decides. An unbounded "run until green" is exactly the loop this rule
  forbids, and must not be added.

## Flow

```text
Workspace Init Agent        --->  phase 1 repositories, three questions
      |
      v
raw requirement
      |
      v
Requirement Analysis Agent  --->  human approves  (the only gate)
      |
      v
Release Agent               --->  creates phase 2 repositories
      |                           picks the next draft release, sets in_progress
      v
Coding Agent x N            --->  one per repository, in parallel; build images
      |
      v
Release Agent               --->  deploys, preflight/done-check.sh
      |
      v
Journey Test Agent          --->  journeys, mock data, scripts; test zone; run them
      |
      +-- a required journey failed --> evidence --> root cause
      |        --> Release Agent hands it to the owning Coding Agent
      |        --> rebuild, redeploy, done-check.sh --> run again
      |        (at most 3 rounds, then the human decides)
      v
all required journeys pass  --->  test zone removed  --->  preflight/journey-check.sh
      |
      v
Release Agent               --->  locks the release
      |
      v
flag.yml release_execution:  manual -> wait for human
                             auto   -> next release
```

## Gates

The framework has exactly two checkpoints:

1. The human approves the Requirement Analysis Agent's output, once per analysis,
   before any code from it is written.
2. A release is done: it deploys and runs on the local Docker host
   (`preflight/done-check.sh`), its required journeys have been walked through the real
   UI and passed in the test zone, and the test zone has been removed
   (`preflight/journey-check.sh`). For an `mcp-server`, which has no screen,
   `done-check.sh --mcp` takes the place of clicking through. A release with no
   screen at all has no required journeys, and `done-check.sh` alone decides it.

Checkpoint 2 is mechanical: two scripts pass or they do not. The one time it reaches the
human is when the journey rework rounds run out, and then the human decides what happens
to that release. That question is bounded by construction; it is not a review step.

`release_execution: manual` stopping after a lock is not a third checkpoint: nothing is
being approved, the human simply chooses when the next release starts.

The three questions the Workspace Init Agent asks the human — monorepo or multi-repo,
whether they want an MCP server, and whether agents may take the recommended option —
are **inputs, not gates**, like every other question in
`knowledge/questions/AGENTS.md`. Nothing is being approved and no work is held back
pending a verdict. Do not turn any question into a checkpoint.

No agent has its own completion gate. No agent judges whether its own work is good
enough. Any rule of the form "prove this is complete before continuing" is what
produces the loop this framework is built to avoid, and must not be added. The journey
gate is the single, deliberate exception, and it holds only because its verdict comes
from executed assertions and its loop has a fixed number of rounds. Do not add a second
gate in its shape, and do not remove its bound.

## Concurrency

- One repository is owned by exactly one agent at a time. Two agents must never
  write product code to the same repository.
- Agents working on different repositories run in parallel.
- The number of Coding Agents for a release equals the number of repositories that
  release touches, as decided by the Requirement Analysis Agent. The Release Agent
  spawns them.
- Only the Release Agent deploys, so parallel agents never deploy over each other.
- A Coding Agent may spawn helper agents, for example to start and watch a local
  process. A helper inherits its parent's boundaries and does not become a second
  writer for the parent's repository.

### Ownership is a write set, not a directory name

The rule is: **no two agents ever write the same file at the same time.** Three
situations break the one-repository-one-agent shape while keeping that rule:

| Situation | How ownership works |
|---|---|
| `workspace.repo_layout: mono` | Every repository is a directory in one git repository. An agent owns its directory. It writes files and **does not commit**; the Release Agent makes one commit for the whole release after `preflight/done-check.sh` and `preflight/journey-check.sh` pass, so parallel agents never contend for the git index and no merge step is introduced. |
| `registry/openapi/` | Every backend publishes its OpenAPI document here. An agent owns exactly `openapi/<its own backend>.json` — not another backend's document, not `repos.yaml`, nothing else in that repository. |
| Shared workspace files | Files every Coding Agent needs to touch. They are written **one agent at a time**, under the lock below. |

These are the only three exceptions, and all three are exceptions to the *boundary*,
never to the rule. An agent that cannot name the exact files it owns, or the lock it
holds, is not allowed to write.

In `multi` layout each repository commits as it always has.

### Shared files are written one agent at a time

| Lock name | Covers |
|---|---|
| `local-env` | everything under `${WORKSPACE_PATH}/local-env/` except `test/`, including the develop Nginx configuration |
| `deployment-local` | the `deployment` repository's `local/` directory: `compose.yml`, `deploy.sh`, the Nginx configuration it mounts |
| `config-local` | the `config` repository's `local/` directory |
| `tool` | the `tool` repository |

To write any of these:

1. Take the lock: `mkdir "${WORKSPACE_PATH}/.locks/<lock name>"`. `mkdir` is atomic, so
   it either succeeds and the lock is yours, or fails because another agent holds it.
2. If it failed, wait and try again. Do not write around it.
3. Make the edit, and only the edit. Never hold a lock while running a long process,
   building or deploying.
4. Release it: `rmdir "${WORKSPACE_PATH}/.locks/<lock name>"`.

Only the Release Agent removes a lock it does not hold, and only when no agent of the
current release is running. In `mono` layout `.locks/` is git-ignored at the workspace
root.

## Priority

A newer release always wins over an earlier one. Overlapping or contradicting code
is overwritten, not reconciled. A defect a required journey exposes is fixed in that
release's rework. Every other defect — one the human finds by clicking, or one in an
earlier release's journey — comes back as a `type: change` release.

## Shared rules

Every agent must:

- Read `flag.yml` before writing, and never write inside the framework repository
  while `mode: working`.
- Never write `flag.yml`, in either mode.
- Write only inside `WORKSPACE_PATH`, and within it only where its own definition
  says it may. Product code goes in the one repository it was assigned; the
  supporting paths each agent may also touch are listed in its definition.
- Take the lock above before writing a shared file.
- Read every knowledge file its definition's **Inputs** table lists. Those files are not
  loaded automatically: the workspace lives outside this repository.
- Reach PostgreSQL, Kafka and Redis only through the Python tools in the `tool`
  repository, against a local host (`knowledge/tools/AGENTS.md`).
- Route every call to a backend through Nginx only (`knowledge/nginx/AGENTS.md`).
- Read `workspace.repo_layout`, `workspace.mcp_server` and `workspace.auto_recommend`
  from `${WORKSPACE_PATH}/workspace.yaml` rather than asking the human again. Only the
  Workspace Init Agent writes them, once; the single later change is the Release Agent
  setting `mcp_server` to `true` on the human's direct request.
- Ask questions only in the shape `knowledge/questions/AGENTS.md` defines, one at a time.
- Produce all output in English.
- Stop and report to the human rather than working around a rule in this file.
