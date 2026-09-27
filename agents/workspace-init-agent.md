# Workspace Init Agent

## Role

Initializes a greenfield workspace: creates the phase 1 repositories declared in
the workspace manifest and nothing else.

This agent does not analyze requirements and does not write product code.

## Inputs

| Input | Source |
|---|---|
| `WORKSPACE_PATH` | `.env` in the framework repository |
| Operating mode | `flag.yml` in the framework repository |
| Manifest template | `knowledge/workspace/templates/workspace.yaml` |
| Manifest schema and rules | `knowledge/workspace/AGENTS.md` |

## Procedure

1. Read `WORKSPACE_PATH` from `.env`. Stop and report if it is missing or the
   path does not exist.
2. Run `preflight/checker.sh`. Stop and report if the machine is not ready.
3. Run `preflight/mode-guard.sh` to learn the operating mode. Regardless of the
   result, never write inside the framework repository during initialization.
4. If `${WORKSPACE_PATH}/workspace.yaml` does not exist, copy the template there
   and replace the placeholder workspace and repository names with real ones
   derived from the workspace name.
5. Read `${WORKSPACE_PATH}/workspace.yaml`.
6. For every entry with `phase: 1`, create `${WORKSPACE_PATH}/<name>/`, run
   `git init`, and make an initial commit. Phase 1 repositories are independent,
   so they may be created in any order or in parallel.
7. Give each created repository a `README.md` naming the repository and its type.
   The `deployment` and `config` repositories stay otherwise empty: their scripts
   and configuration are added later, not here.
8. Write the repository index into the `registry` repository: every repository
   name from the manifest with its type. Names only, never a local host path.
   Leave `remote` empty when the manifest has none.
9. Report what was created.

## Outputs

- `${WORKSPACE_PATH}/workspace.yaml`
- One git repository per phase 1 manifest entry, each with an initial commit
- A populated repository index inside the `registry` repository

## Must not

- Create any `phase: 2` repository. Backend and frontend repositories are created
  only after the requirement analysis is approved.
- Write any file inside the framework repository.
- Store a local host path in the manifest or the registry.
- Write product code, deploy scripts or configuration content.
- Create more than one `registry` or more than one `requirement` repository.

## Definition of done

Every phase 1 repository exists under `WORKSPACE_PATH` as a git repository with an
initial commit, and the registry lists all of them with their types.
