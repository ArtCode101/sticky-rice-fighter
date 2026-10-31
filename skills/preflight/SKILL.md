---
name: preflight
description: Check that this machine is ready to build with the framework — Java 25, Node.js 24 with npm, Docker and Python 3.13, plus the optional mobile tooling. Runs preflight/checker.sh, or checker.bat on Windows, and reports. Use before /srf:init, after installing a tool, or whenever a build fails for a reason that looks like a missing tool.
disable-model-invocation: true
---

# Preflight

## Role

Runs the machine readiness check and reports the result. It is the same check
`/srf:init` runs before it does anything, made available on its own so the human can
run it before initializing a workspace, after installing a missing tool, or on a new
machine, without starting any other work.

This skill changes nothing. It writes no file, asks no question and starts no agent.

## Inputs

| Input | Source |
|---|---|
| The readiness check | `preflight/checker.sh`, or `preflight/checker.bat` on Windows without a Bash tool |

## Where the files are

- **The framework is this plugin**, at `${CLAUDE_PLUGIN_ROOT}`. The `preflight/...`
  paths here are relative to it. The rule is in `knowledge/flow/AGENTS.md` → **Where
  the files are**.
- **The framework is read-only.** This skill has no reason to write anywhere, inside
  the framework or in the workspace.

## Procedure

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/preflight/checker.sh"` with the Bash tool. On
   Windows that is Git Bash, and the script finds the real Python there. Only when no
   Bash tool exists, run `${CLAUDE_PLUGIN_ROOT}/preflight/checker.bat` instead.
2. Show the script's output to the human as it is. Every line is already marked
   `[OK]`, `[FAIL]` or `[WARN]`.
3. State the verdict in one line: ready, or not ready. The script's exit code is the
   verdict — `0` is ready, anything else is not. Do not soften a failure or upgrade a
   warning into one.
4. For every `[FAIL]`, say what is missing and the exact version the framework needs,
   taken from the script's own message. Where it helps, name the usual way to install
   it on this operating system. Do not install anything.
5. A `[WARN]` is mobile tooling: `adb`, `xcrun`, Maestro. Say that it matters only for a
   workspace with a `mobile` repository, and leave it at that.

## Outputs

- The check's output, and a one-line verdict: ready or not ready.

## Must not

- Write any file, in the workspace or in the framework.
- Install, upgrade or change any tool on the machine. Report, and let the human do it.
- Ask the human a question. There is nothing to decide here.
- Run `/srf:init` or anything else afterwards. The human decides what happens next.
- Report "ready" when the script exited non-zero.

## Definition of done

The check has run, its output is in front of the human, and the verdict matches the
script's exit code.
