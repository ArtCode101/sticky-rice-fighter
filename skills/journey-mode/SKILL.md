---
name: journey-mode
description: Set how the journey tests of this workspace run — desktop (a visible browser or emulator), background (headless), or ask at the start of every /srf:release run. Writes workspace.journey_mode and nothing else.
argument-hint: "[desktop | background | ask]"
disable-model-invocation: true
---

# Journey Mode

## Role

Records the human's choice of how journeys run, in `workspace.journey_mode`. The
Release Agent reads that field at the start of every `/srf:release` run and hands the
mode to the Journey Test Agent. The rule for the modes themselves is
`knowledge/journey/AGENTS.md` → **Desktop or background mode**.

This skill is not an agent. It writes one field, starts nothing and runs no journey.

## Inputs

| Input | Source |
|---|---|
| `WORKSPACE_PATH` | the directory Claude Code was opened in, `${CLAUDE_PROJECT_DIR}` |
| The mode | `desktop`, `background` or `ask` in `$ARGUMENTS`; otherwise asked |
| Workspace manifest | `${WORKSPACE_PATH}/workspace.yaml` |
| The field and its values | `knowledge/workspace/AGENTS.md` → **Journey mode** |
| What each mode does | `knowledge/journey/AGENTS.md` → **Desktop or background mode** |
| Question protocol | `knowledge/questions/AGENTS.md` |

## Where the files are

- **The framework is this plugin**, at `${CLAUDE_PLUGIN_ROOT}`. The `knowledge/...`
  paths here are relative to it. The rule is in `knowledge/flow/AGENTS.md` → **Where
  the files are**.
- **The workspace is the directory Claude Code was opened in**, `${CLAUDE_PROJECT_DIR}`.
  That is `WORKSPACE_PATH`.
- **The framework is read-only.** A hook blocks every write under
  `${CLAUDE_PLUGIN_ROOT}`. A blocked write is reported to the human, never worked around.

## Procedure

1. Stop and report if `${WORKSPACE_PATH}/workspace.yaml` does not exist: the workspace
   is not initialized, and `/srf:init` comes first.
2. Read `workspace.journey_mode`. An absent field means `ask`.
3. If `$ARGUMENTS` is `desktop`, `background` or `ask`, in any letter case, that is the
   human's answer; go to step 5.
4. Otherwise, say the current value in one line and ask:

   ```text
   How should the journey tests run?

     1. Desktop        — a visible browser or emulator; you watch every journey happen
     2. Background     — headless; faster, nothing to watch
     3. Ask each time  — /srf:release asks before it starts, and the answer lasts for that run
     4. Something else — type your answer

   Pick a number, or type your own answer.
   ```

   This is a preference, so no option is recommended, and it is asked even when
   `workspace.auto_recommend` is `true`. An answer that maps to none of the three
   values is asked again; nothing is written until it does.
5. Write the answer to `workspace.journey_mode`, changing nothing else in the file.
   When the field is absent, add it after `release_execution` with the comment the
   manifest template gives it, `knowledge/workspace/templates/workspace.yaml`.
6. Report the old and the new value, and when it takes effect: from the next
   `/srf:release` run. A journey that needs a human to click still runs in desktop
   mode, whatever the value.

## Write scope

| May write | Why |
|---|---|
| `workspace.journey_mode` in `${WORKSPACE_PATH}/workspace.yaml` | the human's choice |

Everything else is out of bounds.

## Must not

- Write any other field of `workspace.yaml`, or any other file.
- Write a value other than `desktop`, `background` or `ask`.
- Choose the mode on the human's behalf, or take an option because
  `auto_recommend` is `true`.
- Start a release, provision a test zone or run a journey.
- Write any file inside the framework, `${CLAUDE_PLUGIN_ROOT}`.

## Definition of done

`workspace.journey_mode` holds the value the human gave, nothing else in the workspace
changed, and the human has been told the old value, the new one and when it applies.
