---
name: init
description: Initialize a greenfield workspace in the directory Claude Code was opened in. Asks the three questions, writes workspace.yaml and CLAUDE.md, creates the phase 1 repositories. Runs once per workspace.
disable-model-invocation: true
---

# Workspace Init Agent

## Role

Initializes a greenfield workspace: creates the phase 1 repositories declared in
the workspace manifest and nothing else.

This agent does not analyze requirements and does not write product code.

## Inputs

| Input | Source |
|---|---|
| `WORKSPACE_PATH` | the directory Claude Code was opened in, `${CLAUDE_PROJECT_DIR}` |
| Manifest template | `knowledge/workspace/templates/workspace.yaml` |
| Workspace instructions template | `knowledge/workspace/templates/CLAUDE.md` |
| Manifest schema and rules | `knowledge/workspace/AGENTS.md` |
| Three answers from the human | Asked at initialization. See **Three questions for the human**. |
| Question protocol | `knowledge/questions/AGENTS.md` |

## Where the files are

- **The framework is this plugin**, at `${CLAUDE_PLUGIN_ROOT}`. Every `knowledge/...`,
  `preflight/...` and `agents/...` path here and in the knowledge files is relative to
  it. Read `knowledge/flow/AGENTS.md` first; the rule behind this section is there.
- **The workspace is the directory Claude Code was opened in**, `${CLAUDE_PROJECT_DIR}`.
  That is `WORKSPACE_PATH`, and every `${WORKSPACE_PATH}` path means this directory.
  There is no `.env`.
- **The framework is read-only.** A hook blocks every write under
  `${CLAUDE_PLUGIN_ROOT}`. A blocked write is reported to the human, never worked around.

## Procedure

1. `WORKSPACE_PATH` is `${CLAUDE_PROJECT_DIR}`. Stop and report if it already holds a
   `workspace.yaml`: that workspace is initialized, and this skill runs once.
2. Run `bash "${CLAUDE_PLUGIN_ROOT}/preflight/checker.sh"` with the Bash tool. On
   Windows that is Git Bash, and the script finds the real Python there. Only when no
   Bash tool exists, run `${CLAUDE_PLUGIN_ROOT}/preflight/checker.bat` instead. Stop
   and report if the machine is not ready.
3. Take the workspace name from the directory's name, unless the human gives another.
4. **Ask the human the three questions below**, one at a time, and record the answers.
   Ask them before writing the manifest, because all three answers go into it.
5. If `${WORKSPACE_PATH}/workspace.yaml` does not exist, copy the template there
   and replace the placeholder workspace and repository names with real ones
   derived from the workspace name. Write `repo_layout`, `mcp_server` and
   `auto_recommend` from the answers to step 4; `release_execution` stays at the
   template's `manual`, for the human to flip later.
   Then copy `knowledge/workspace/templates/CLAUDE.md` to `${WORKSPACE_PATH}/CLAUDE.md`,
   with the workspace name filled in, unless one exists. It is what makes the
   framework's rules apply from the first message of every later session here.
6. Read `${WORKSPACE_PATH}/workspace.yaml`.
7. Initialize git according to `workspace.repo_layout`:
   - `multi`: for every entry with `phase: 1`, create `${WORKSPACE_PATH}/<name>/`,
     run `git init` in it, and make an initial commit. Phase 1 repositories are
     independent, so they may be created in any order or in parallel.
   - `mono`: run `git init` **once** at `${WORKSPACE_PATH}`, create
     `${WORKSPACE_PATH}/<name>/` for every entry with `phase: 1` as a directory
     inside it, add `.locks/` to the workspace root's `.gitignore` (see the shared-file
     lock in `knowledge/flow/AGENTS.md`), and make one initial commit covering all of them.
8. Give each created repository a `README.md` naming the repository and its type.
   The `deployment` and `config` repositories stay otherwise empty: their scripts
   and configuration are added later, not here.
9. Write the repository index into the `registry` repository: every repository
   name from the manifest with its type. Names only, never a local host path.
   Leave `remote` empty when the manifest has none.
10. Report what was created, including which layout was chosen and whether an MCP
    server was asked for.

## Three questions for the human

All three are asked **every time** a workspace is initialized, and all three answers are
written into the manifest so no agent ever asks again.

They are asked **one at a time**, in the numbered-option shape
`knowledge/questions/AGENTS.md` defines — including question 3, which is the one that
decides whether later questions get asked at all. Question 3 is never auto-answered by
the mode it is establishing.

### 1. Monorepo or multi-repo?

```text
Should this workspace be one git repository (monorepo) or one git repository
per repository (multi-repo)?
```

- Offer the choice first. **Never decide on the human's behalf** while they still
  have a chance to answer.
- Explain it in one line if they do not know the terms: monorepo means everything
  lives in one git repository; multi-repo means each backend, frontend and supporting
  repository gets its own.
- **Default `mono`** when the answer is absent, or non-committal — "you decide",
  "whatever you think", or no reply at all. Monorepo is easier to start and keeps the
  decision count down.
- Write the answer to `workspace.repo_layout`.

### 2. Do you want an MCP server?

```text
Do you want an MCP server for this system, so an outside AI agent can drive it?
```

- **Default `false`** when the answer is absent, non-committal or "no". Unlike the
  layout question, silence here means *do not build it*: nothing is generated that
  was not asked for.
- Write the answer to `workspace.mcp_server`.
- A `false` here is not a permanent refusal. If the human later asks for an MCP server
  directly, the Release Agent sets the field to `true`; see
  `skills/release/SKILL.md`. The field stops agents from asking again; it does not
  override an instruction.

### 3. May agents take the option they recommend, without asking?

```text
When a decision comes up and one option is clearly best, may agents take it
without stopping to ask you?

  1. No, ask me every time       — you answer every decision yourself
  2. Yes, take the recommended one — agents continue without interrupting you, and
                                     say in their report what they chose and why
  3. Something else              — type your answer
```

- **Default `false`** when the answer is absent or non-committal. Asking is the safe
  direction.
- Write the answer to `workspace.auto_recommend`.
- Say plainly, when asking, that `true` does **not** silence every question: a decision
  where no option is clearly best is still brought to them, because auto mode has
  nothing to apply there.

These three questions are **inputs, not gates**. They collect a parameter before work
starts. They are not a checkpoint, nothing is being approved, and no agent judges
anything. The framework still has exactly the two checkpoints in `knowledge/flow/AGENTS.md`.

## Outputs

- `${WORKSPACE_PATH}/workspace.yaml`, with `repo_layout`, `mcp_server` and
  `auto_recommend` filled in, and `release_execution: manual`
- `${WORKSPACE_PATH}/CLAUDE.md`, from the template
- Git initialized according to `repo_layout`: one repository per phase 1 manifest
  entry in `multi`, or a single repository at the workspace root in `mono`, with an
  initial commit either way
- A populated repository index inside the `registry` repository

## Must not

- Create any `phase: 2` repository. The Release Agent creates them once the requirement
  analysis is approved.
- Skip any of the three questions, or answer one on the human's behalf before they have
  had the chance to.
- Ask the three questions in one message. One at a time.
- Apply `auto_recommend` to question 3 itself.
- Change `repo_layout`, `mcp_server` or `auto_recommend` once they are written. Only the
  human revisits those; the single exception is in `skills/release/SKILL.md`.
- Write any file inside the framework, `${CLAUDE_PLUGIN_ROOT}`.
- Store a local host path in the manifest or the registry.
- Write product code, deploy scripts or configuration content.
- Create more than one `registry` or more than one `requirement` repository.

## Definition of done

Every phase 1 repository exists under `WORKSPACE_PATH` with an initial commit — as
its own git repository in `multi` layout, or as a directory in the workspace's single
git repository in `mono` layout — the registry lists all of them with their types, and
the manifest records all three answers from the human.
