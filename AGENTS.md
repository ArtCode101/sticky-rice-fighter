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

## Where each rule lives

Every rule has **one** home. This table gives each a line so an agent knows it exists;
the file on the right is the rule, and it wins over any summary, including this one.
When a rule changes, it changes there.

| Topic | In one line | The rule |
|---|---|---|
| Agents, flow, gates | Two checkpoints: the human approves the analysis; a release is done when `done-check.sh` and `journey-check.sh` pass. No QA or reviewer agent. | `agents/AGENTS.md` |
| File ownership | No two agents write the same file at the same time; shared workspace files are written under a lock. | `agents/AGENTS.md` |
| Running releases | The Release Agent creates phase 2 repositories, starts, deploys and locks each release. | `agents/release-agent.md` |
| Asking the human | One question at a time, numbered options, a free-text slot last; `auto_recommend` never skips a question with no recommendation. | `knowledge/questions/AGENTS.md` |
| Datastore access | PostgreSQL, Kafka and Redis only through the Python tools in the `tool` repository, local hosts only, full privileges there. | `knowledge/tools/AGENTS.md` |
| Backend traffic | Every caller reaches the backend through Nginx only, in development and deployed; every workspace with a backend has Nginx. | `knowledge/nginx/AGENTS.md` |
| MCP servers | Built only when the human asked; generated mechanically from the backends' OpenAPI documents, in its own release; never touches a datastore. | `knowledge/mcp/AGENTS.md` |
| Authentication | The login method is asked, never assumed; the identity token is a nested JWT, signed then encrypted; keys per group and per environment. | `knowledge/auth/AGENTS.md` |
| Mobile apps | React Native on Expo, split by user group, no secret in a build. | `knowledge/mobile/AGENTS.md` |
| Journeys | A release locks only when its required journeys have run and passed in the test zone; rework is bounded at 3 rounds. | `knowledge/journey/AGENTS.md` |
| Versions and image tags | Every version in `knowledge/tech-stack.yaml` is exact; consumed images are never `latest`; produced images are tagged by layout. | `knowledge/versioning/AGENTS.md` |
| Repository layout | `mono` or `multi`, asked once at initialization, default `mono`. | `knowledge/workspace/AGENTS.md` |

The knowledge files are not loaded on their own: the workspace lives outside this
repository. Each agent reads the files its definition's **Inputs** table lists.

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
