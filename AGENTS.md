# Framework Rules

## Scope

This file applies to every file in this repository.

This repository is the **framework repo**. It holds the knowledge, context, rules
and agent definitions used to build systems in a separate **workspace**. It is not
the workspace itself, and no product code is ever written here.

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

## Mode guard

Script:

`preflight/mode-guard.sh`

Exits `0` when the framework is writable (`mode: edit`) and `1` when it is locked
(`mode: working`). Use it as the enforcement point from a hook or from an agent's
own pre-write check, so the rule is verified mechanically and not only by
instruction.
