# Framework Rules

## Scope

This file applies to every file in this repository.

This repository is the **framework**, packaged as a Claude Code plugin named `srf` and
published through the marketplace manifest in `.claude-plugin/marketplace.json`. It
holds the knowledge, rules, skills and subagent definitions used to build systems in a
separate **workspace**. It is not a workspace, and no product code is ever written here.

Whoever opens Claude Code in this repository is the framework author. Everyone else
meets the framework as an installed plugin, from inside a workspace.

## Two places

| | Where | How agents refer to it |
|---|---|---|
| The framework | This repository, or its installed copy under `~/.claude/plugins/cache/` | `${CLAUDE_PLUGIN_ROOT}` |
| The workspace | The directory the human opened Claude Code in | `${CLAUDE_PROJECT_DIR}`, which **is** `WORKSPACE_PATH` |

There is no `.env` and no flag file. The workspace is wherever Claude Code was started,
and every `knowledge/...`, `preflight/...`, `skills/...` and `agents/...` path in the
framework is relative to `${CLAUDE_PLUGIN_ROOT}`. The rule, and the words every skill
repeats, live in `knowledge/flow/AGENTS.md` → **Where the files are**.

## The framework is read-only in use

Agents building a workspace never create, modify, rename, move or delete a file in the
framework, and never modify their own context, prompts, rules or definition of done.
Two things enforce it:

- `hooks/guard-framework.js`, a `PreToolUse` hook the plugin ships, blocks `Edit`,
  `Write` and `NotebookEdit` under `${CLAUDE_PLUGIN_ROOT}`. It lets the write through
  only when the plugin root is also the project Claude Code was opened in, which is
  the author editing this repository.
- Claude Code asks before any write outside the directory it was opened in.

If a task inside a workspace appears to require editing the framework, the agent stops
and reports it to the human instead of proceeding. The framework changes here, by the
author, and reaches workspaces through a new plugin version.

## Working on the framework

- Validate the plugin after any structural change: `claude plugin validate .`
- Try it before publishing: from an empty scratch directory, run
  `claude --plugin-dir <path to this repository>` and drive `/srf:init`.
- A release of the framework bumps `version` in `.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json` together, records it in `RELEASE_NOTES.md`, and
  tags the commit. Installed copies move with `claude plugin update srf@sticky-rice-fighter`.
- Values the human sets per workspace, such as `release_execution`, live in that
  workspace's `workspace.yaml`, never here.

## Language

All framework content must be written in **English**. This covers every file in this
repository — knowledge base, skill and subagent definitions, manifests, hooks, scripts,
code comments, commit messages and `README.md`.

It also covers every artifact an agent generates in the workspace: release files,
screen specifications, registry entries, deployment scripts and configuration, so that
all agents read and write one consistent language.

Raw requirement input from the human may arrive in any language. The Requirement
Analysis Agent must produce its output in English regardless of the input language.

## Where each rule lives

Every rule has **one** home. This table gives each a line so an agent knows it exists;
the file on the right is the rule, and it wins over any summary, including this one.
When a rule changes, it changes there.

| Topic | In one line | The rule |
|---|---|---|
| Agents, flow, gates, places | Two checkpoints: the human approves the analysis; a release is done when `done-check.sh` and `journey-check.sh` pass. No QA or reviewer agent. The framework is `${CLAUDE_PLUGIN_ROOT}`, the workspace is `${CLAUDE_PROJECT_DIR}`. | `knowledge/flow/AGENTS.md` |
| File ownership | No two agents write the same file at the same time; shared workspace files are written under a lock. | `knowledge/flow/AGENTS.md` |
| Machine readiness | `/srf:preflight`, or `npx sticky-rice-fighter preflight`, runs `preflight/checker.sh` (`checker.bat` on Windows) and changes nothing. | `skills/preflight/SKILL.md` |
| Initializing a workspace | `/srf:init [requirement file]` reads the file first, asks the three questions it does not answer, writes `workspace.yaml` and `CLAUDE.md`, creates the phase 1 repositories. | `skills/init/SKILL.md` |
| Analyzing a requirement | `/srf:analyze` writes releases and screens, and stops for the human's approval. | `skills/analyze/SKILL.md` |
| Running releases | `/srf:release` creates phase 2 repositories, starts, deploys and locks each release. | `skills/release/SKILL.md` |
| Release execution | `workspace.release_execution`: `manual` stops after each lock, `auto` continues. Only the human changes it. | `knowledge/workspace/AGENTS.md` |
| Journey mode | `workspace.journey_mode`: `desktop`, `background` or `ask`. `/srf:release` settles it before any release starts; the human sets it with `/srf:journey-mode`. | `knowledge/workspace/AGENTS.md`, `skills/journey-mode/SKILL.md` |
| Asking the human | Read what the human gave before asking: a stated answer is not asked again, a hint is. One question at a time, numbered options, a free-text slot last; `auto_recommend` never skips a question with no recommendation. | `knowledge/questions/AGENTS.md` |
| Datastore access | PostgreSQL, Kafka and Redis only through the Python tools in the `tool` repository, local hosts only, full privileges there. | `knowledge/tools/AGENTS.md` |
| Backend traffic | Every caller reaches the backend through Nginx only, in development and deployed; every workspace with a backend has Nginx. | `knowledge/nginx/AGENTS.md` |
| MCP servers | Built only when the human asked; generated mechanically from the backends' OpenAPI documents, in its own release; never touches a datastore. | `knowledge/mcp/AGENTS.md` |
| Authentication | The login method is asked, never assumed; the identity token is a nested JWT, signed then encrypted; keys per group and per environment. | `knowledge/auth/AGENTS.md` |
| Mobile apps | React Native on Expo, split by user group, no secret in a build. | `knowledge/mobile/AGENTS.md` |
| Journeys | A release locks only when its required journeys have run and passed in the test zone; rework is bounded at 3 rounds. | `knowledge/journey/AGENTS.md` |
| Versions and image tags | Every version in `knowledge/tech-stack.yaml` is exact; consumed images are never `latest`; produced images are tagged by layout. | `knowledge/versioning/AGENTS.md` |
| Repository layout | `mono` or `multi`, asked once at initialization, default `mono`. | `knowledge/workspace/AGENTS.md` |

The knowledge files are not loaded on their own: the workspace lives outside the
framework. Each skill and subagent reads the files its definition's **Inputs** table
lists, from `${CLAUDE_PLUGIN_ROOT}`.

## Ideas that are not built

`NOTES.md` records ideas the human deliberately decided not to build yet. No agent
creates, edits or works from that file. A note there is not a requirement.
