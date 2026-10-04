# Framework Rules

## Scope

This file applies to every file in this repository.

This repository is the **framework repo**. It holds the knowledge, context, rules
and agent definitions used to build systems in a separate **workspace**. It is not
the workspace itself, and no product code is ever written here.

## Workspace input

File:

`.env` (created by the human from `.env.example`; git-ignored, never committed)

| Key | Required | Meaning |
|---|---|---|
| `WORKSPACE_PATH` | yes | Absolute path to the workspace the framework operates on. Every repository the framework creates or edits lives under this path. |

The human drives everything from this repository: clone it, copy `.env.example`
to `.env`, set `WORKSPACE_PATH`, and run the framework from here.

`WORKSPACE_PATH` is the only writable location. Agents must treat any write
outside `WORKSPACE_PATH` as out of bounds, and writes inside this repository are
governed by the operating mode below.

The operating mode is deliberately **not** part of `.env`. `flag.yml` is the
single source of truth for it, so the switch cannot be changed by editing an
untracked file.

## Operating mode

File:

`flag.yml`

```yaml
mode: working   # or: edit
```

This flag is the framework's safety switch. Every agent must read it before any
write operation whose target is inside this repository.

### `mode: working`

AI agents must not:

- Create, modify, rename, move or delete **any** file in this repository.
- Modify their own context, prompts, rules, knowledge or definition of done.
- Modify `flag.yml` itself, including switching the mode to `edit`.

AI agents may:

- Read any file in this repository.
- Write to the external workspace given by `WORKSPACE_PATH` (see `.env`).

If a task appears to require editing this repository while `mode: working`, the
agent must stop and report it to the human instead of proceeding.

### `mode: edit`

The human framework author is editing the framework. Writes inside this
repository are allowed. Agents must still not switch the mode on their own.

## Language

All framework content must be written in **English**. This covers every file in
this repository — knowledge base, agent context and prompts, manifests, `.env`
keys, scripts, code comments, commit messages and `README.md`.

It also covers every artifact an agent generates in the workspace: release files,
screen specifications, registry entries, deployment scripts and configuration, so
that all agents read and write one consistent language.

Raw requirement input from the human may arrive in any language. The Requirement
Analysis Agent must produce its output in English regardless of the input
language.

## Datastore access

Agents reach PostgreSQL, Kafka and Redis through the Python tools in the workspace's
`tool` repository, and through nothing else. No `psql`, no `redis-cli`, no
`docker exec` into a datastore container, no ad-hoc connection code in a service
repository.

On the **local** workspace datastores the grant is total: insert, update, delete,
DDL and mock data generation for testing are all allowed, with no approval step. The
scope is **local level only** — never a dev, sys, staging or production datastore —
and each tool enforces that itself by refusing a non-local host.

The human has been told what this permits, including that a mistaken script can
destroy local data, and accepts that risk. Do not add guardrails, backups or
confirmation prompts in front of a local write: that would reintroduce a gate.

Full rules: `knowledge/tools/AGENTS.md`.

## Backend traffic

**Every** caller reaches the backend through **Nginx only**, in development and when
deployed. That covers the frontend, the MCP server and anything added later. Nothing
calls a backend port directly, and Nginx is never bypassed "just for local
development".

Full rules: `knowledge/nginx/AGENTS.md`.

## MCP servers

The framework can generate an **MCP server** over the system it built, so an outside
AI agent can drive that system:

```text
AI Agent  ->  MCP Client  ->  MCP Server  ->  Nginx  ->  Backend API  ->  Database
```

- It is built **only when the human asked for one**. `workspace.mcp_server` in the
  workspace manifest records the answer, given once at initialization. Silence means
  no.
- It wraps the backend API and **never** touches PostgreSQL, Kafka or Redis.
- Its tools are generated mechanically from the OpenAPI documents each backend
  publishes to `registry/openapi/`. No agent chooses which endpoints to expose.
- The framework generates the server only. The client is the outside agent; its stack
  is pinned for reference.

Full rules: `knowledge/mcp/AGENTS.md`.

## Asking the human

Every question any agent asks takes one shape: **numbered options**, one line each
saying what the option means, a **free-text slot** last, and **one question at a time**.
A wall of ten or twenty questions is the failure this replaces.

`workspace.auto_recommend` decides whether an agent may take the option it recommends
without asking. Even when it is `true`, a question with **no** recommended option is
still asked: auto mode has nothing to apply there, and an agent must not invent a
recommendation in order to avoid asking.

Questions are inputs, not gates. The framework still has exactly the two checkpoints in
`agents/AGENTS.md`.

Full rules: `knowledge/questions/AGENTS.md`.

## Authentication

The login method is **asked**, never assumed — a requirement that says "the system has
login" has not said how. Username and password is on the list of options but is never
the recommended one.

A method that needs provider setup is offered two ways: the agent does it through the
provider's CLI, or the human does it in the portal with a numbered list of what to click.
The second is the default.

Tokens: the **identity token is JWE**, encrypted and unreadable. Data the frontend has
to display may be **JWS**. Signing is RS256 with a key pair — private key signs, public
key verifies — and **every environment has its own pair**, as does every authentication
group. No key ever reaches a browser or a mobile build.

Full rules: `knowledge/auth/AGENTS.md`.

## Applications the framework builds

Backend, frontend, **mobile** (React Native on Expo), batch jobs, listeners, and
optionally an MCP server. A mobile app is split by user group the same way a frontend
is, reaches the backend through Nginx like everything else, and **never carries a secret
in its build** — a user can unpack the installed file.

Full rules: `knowledge/mobile/AGENTS.md`.

## Journeys and journey tests

A **journey** is the ordered path a real user walks, including the steps inserted to make
a later one possible. The journey **document** is written first, from the code and the
specifications; the Playwright or Maestro script comes after it.

Journeys run in a **test zone** with its own containers — a separate compose project,
running the images the release deployed — apart from the develop zone the human clicks
through, with mock data injected per journey.

**A release locks only when its required journeys pass.** After the deploy, the Journey
Test Agent writes or updates the journeys for the release's scope, provisions the test
zone, and **executes** them through the real UI — desktop browser mode by default. A
generated script that has not run proves nothing.

- A failing required journey sends the release into **rework**: evidence, root cause,
  fix, rebuild and redeploy, run again. Rework is **bounded at 3 rounds**; then the
  loop stops and the human decides.
- A fix never weakens a journey: no step, assertion or required journey is removed,
  skipped or loosened to make it pass.
- Once every required journey passes, the test zone's containers, volumes and networks
  are removed. `preflight/journey-check.sh` verifies the pass and the cleanup.

The gate is the journeys' executed assertions, not an agent's judgment. The Journey Test
Agent is still not a QA agent or a reviewer.

Full rules: `knowledge/journey/AGENTS.md`.

## Versioning and image tags

The rule that no image uses the `latest` tag applies to images the framework
**consumes** — base and dependency images stay pinned exactly. An image the framework
**produces** from workspace code is tagged `latest` in `mono` layout, and with its
repository's git tag in `multi` layout, where the repository is tagged with a semantic
version before it is built.

Full rules: `knowledge/versioning/AGENTS.md`.

## Repository layout

Each workspace is either **mono** (one git repository at the workspace root, every
repository a directory inside it) or **multi** (one git repository per repository).

`workspace.repo_layout` in the workspace manifest records the answer, asked of the
human at initialization. Agents read it and must never write it. When the human does
not choose, the answer is `mono`.

Full rules: `knowledge/workspace/AGENTS.md`.

## Ideas that are not built

`NOTES.md` records ideas the human deliberately decided not to build yet. No agent
creates, edits or works from that file. A note there is not a requirement.

## Release execution mode

Also in `flag.yml`:

```yaml
release_execution: manual   # or: auto
```

| Value | Behavior after a release is locked |
|---|---|
| `manual` | Stop. The human clicks through the running system and explicitly continues to the next release. |
| `auto` | Continue to the next `draft` release immediately, until none is left. |

Releases always run one at a time in ascending release number, in both modes. The
mode only decides whether the human is asked before the next one starts.

Only the human sets this value. Agents read it and must never write it, in either
operating mode.

## Mode guard

Script:

`preflight/mode-guard.sh`

Exits `0` when the framework is writable (`mode: edit`) and `1` when it is locked
(`mode: working`). Use it as the enforcement point from a hook or from an agent's
own pre-write check, so the rule is verified mechanically and not only by
instruction.
