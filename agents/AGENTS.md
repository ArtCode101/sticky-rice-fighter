# Agent Rules

## Scope

This file applies to all files under:

`agents/`

## Agents

| Agent | Definition | Human gate |
|---|---|---|
| Workspace Init Agent | `agents/workspace-init-agent.md` | no |
| Requirement Analysis Agent | `agents/requirement-analysis-agent.md` | **yes** |
| Coding Agent | `agents/coding-agent.md` | no |
| Journey Test Agent | `agents/journey-test-agent.md` | no |

There is deliberately no QA agent and no reviewer agent. Adding one reintroduces
the loop this framework exists to avoid.

The Journey Test Agent is **not** one of those. It writes journeys, mock data and test
scripts, runs them for real and cleans up. The **journeys** gate the release — a
release locks only when its required journeys pass — but that gate is mechanical and
bounded:

- A journey passes or fails on its own assertions, taken from the specification. No
  agent judges whether code is good enough.
- A failure sends the release into rework, at most **3 rounds**. Then the loop stops
  and the human decides. An unbounded "run until green" is exactly the loop this rule
  forbids, and must not be added.

## Flow

```text
raw requirement
      |
      v
Requirement Analysis Agent  --->  human approves  (the only gate)
      |
      v
Workspace Init Agent        --->  creates phase 2 repositories
      |
      v
Coding Agent x N            --->  one per repository, in parallel
      |
      v
release runs on local Docker host  --->  preflight/done-check.sh
      |
      v
Journey Test Agent          --->  journeys, mock data, scripts; test zone; run them
      |
      +-- a required journey failed --> evidence --> root cause
      |        --> owning Coding Agent fixes, redeploys --> run again
      |        (at most 3 rounds, then the human decides)
      v
all required journeys pass  --->  test zone removed  --->  preflight/journey-check.sh
      |
      v
release is locked
      |
      v
flag.yml release_execution:  manual -> wait for human
                             auto   -> next release
```

## Gates

The framework has exactly two checkpoints:

1. The human approves the Requirement Analysis Agent's output, once, before any
   code is written.
2. A release is done: it deploys and runs on the local Docker host
   (`preflight/done-check.sh`), its required journeys have been walked through the real
   UI and passed in the test zone, and the test zone has been removed
   (`preflight/journey-check.sh`). For an `mcp-server`, which has no screen,
   `done-check.sh --mcp` takes the place of clicking through. A release with no
   screen at all has no required journeys, and `done-check.sh` alone decides it.

Checkpoint 2 is mechanical: two scripts pass or they do not. The one time it reaches the
human is when the journey rework rounds run out, and then the human decides what happens
to that release. That question is bounded by construction; it is not a review step.

The two questions the Workspace Init Agent asks the human — monorepo or multi-repo,
and whether they want an MCP server — are **inputs, not gates**. They collect a
parameter before any work starts. Nothing is being approved, no agent judges anything,
and no work is held back pending a verdict. Do not turn them into a checkpoint, and do
not add more questions in their shape.

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
- The number of coding agents for a release equals the number of repositories that
  release touches, as decided by the Requirement Analysis Agent.
- A Coding Agent may spawn helper agents, for example to start and watch a local
  process. A helper inherits its parent's boundaries and does not become a second
  writer for the parent's repository.

### Ownership is a write set, not a directory name

Two situations break the one-repository-one-agent shape while keeping the rule it
protects: **no two agents ever write the same file.**

| Situation | How ownership works |
|---|---|
| `workspace.repo_layout: mono` | Every repository is a directory in one git repository. An agent owns its directory. It writes files and **does not commit**; one commit is made for the whole release after `preflight/done-check.sh` and `preflight/journey-check.sh` pass, so parallel agents never contend for the git index and no merge step is introduced. |
| `registry/openapi/` | Every backend publishes its OpenAPI document here. An agent owns exactly `openapi/<its own backend>.json` — not another backend's document, not `repos.yaml`, nothing else in that repository. |

These are the only two exceptions, and both are exceptions to the *boundary*, never to
the rule. An agent that cannot name the exact files it owns is not allowed to write.

In `multi` layout each repository commits as it always has.

## Priority

A newer release always wins over an earlier one. Overlapping or contradicting code
is overwritten, not reconciled. A defect a required journey exposes is fixed in that
release's rework. Every other defect — one the human finds by clicking, or one in an
earlier release's journey — comes back as a `type: change` release.

## Asking the human

Every question any agent asks follows one shape, defined in
`knowledge/questions/AGENTS.md`: numbered options, a one-line consequence each, a
free-text slot last, and **one question at a time**. A wall of ten questions is the
failure that protocol exists to fix.

`workspace.auto_recommend` decides whether an agent may take the option it recommends
without asking. Even when it is `true`, a question with **no** recommended option is
still asked — auto mode has nothing to apply, and guessing is not a substitute.

Questions are inputs, not gates. They collect a parameter before work starts. No agent
may use one to hold work for review or to ask whether its own output is good enough.

## Shared rules

Every agent must:

- Read `flag.yml` before writing, and never write inside the framework repository
  while `mode: working`.
- Never write `flag.yml`, in either mode.
- Write only inside `WORKSPACE_PATH`, and within it only where its own definition
  says it may. Product code goes in the one repository it was assigned; the
  supporting paths each agent may also touch are listed in its definition.
- Reach PostgreSQL, Kafka and Redis only through the Python tools in the `tool`
  repository, against a local host.
- Route every call to a backend through Nginx only, whether it comes from a frontend,
  from the MCP server, or from anything added later.
- Read `workspace.repo_layout`, `workspace.mcp_server` and `workspace.auto_recommend`
  from `${WORKSPACE_PATH}/workspace.yaml` rather than asking the human again, and never
  write any of them.
- Ask questions only in the shape `knowledge/questions/AGENTS.md` defines, one at a time.
- Produce all output in English.
- Stop and report to the human rather than working around a rule in this file.
