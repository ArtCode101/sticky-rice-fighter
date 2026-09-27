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
