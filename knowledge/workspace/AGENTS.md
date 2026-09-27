# Workspace Manifest Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/workspace/`

## Purpose

The files in this directory define the workspace manifest: the single file that
declares every repository in a workspace, its type, and when it is created.

## Template usage

File:

`knowledge/workspace/templates/workspace.yaml`

Use this file as the standard workspace manifest reference.

AI agents should:

- Read this file when a workspace is initialized.
- Copy it to `${WORKSPACE_PATH}/workspace.yaml` and replace the placeholder
  workspace and repository names with real ones.
- Keep the schema, field names and phase semantics unchanged.
- Append phase 2 entries to the workspace copy as new repositories are identified.

AI agents must not:

- Modify this knowledge file during normal project generation.
- Store a local host path for any repository.
- Add repository types that are not in the list below.
- Create more than one `registry` or more than one `requirement` repository.

## Schema

| Field | Required | Meaning |
|---|---|---|
| `workspace.name` | yes | Name of the workspace. |
| `repos[].name` | yes | Repository name. Names only — never a local host path. |
| `repos[].type` | yes | One of `registry`, `requirement`, `deployment`, `config`, `backend`, `frontend`. |
| `repos[].phase` | yes | Creation phase. `1` = create immediately, `2` = create once the requirement analysis says it is needed. |
| `repos[].remote` | no | Git remote link. May be `null` and filled in later. |

## Repository types

| Type | Cardinality | Purpose |
|---|---|---|
| `registry` | exactly 1 | Lists every repository in the workspace with its type. The workspace's own index. |
| `requirement` | exactly 1 | Holds the release and screen specifications produced by the Requirement Analysis Agent. Git-versioned as an audit trail. |
| `deployment` | 1 or more | Deploy scripts for the local Docker host and for real environments. Created empty in phase 1. |
| `config` | 1 or more | Configuration for every part of the system. Read by the deployment repository at deploy time. Created empty in phase 1. |
| `backend` | 0 or more | Backend services, split by domain. Created in phase 2. |
| `frontend` | 0 or more | Frontend applications, split by user group. Created in phase 2. |

## Phases

Phase 1 repositories have no dependencies on any requirement analysis, so they
are all created together at workspace initialization: `registry`, `requirement`,
an empty `deployment` and an empty `config`.

Phase 2 repositories depend on the requirement analysis, which decides how many
backend repositories are needed (one per domain) and how many frontend
repositories are needed (one per user group, for example a separate admin portal
and general-user site). They are appended to the workspace manifest and created
only once that analysis is approved.
