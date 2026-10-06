# Requirement Repository Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/requirement/`

and governs the content of the workspace's `requirement` repository.

## Purpose

The `requirement` repository holds the output of the Requirement Analysis Agent:
one file per release and one file per screen. It is the only specification the
coding agents read, and its git history is the audit trail for what was approved
and when.

## Layout

```text
<workspace>-requirement/
└── releases/
    ├── release-1/
    │   ├── release.md
    │   └── screens/
    │       ├── login.md
    │       └── dashboard.md
    └── release-2/
        ├── release.md
        └── screens/
            └── ...
```

- One directory per release, named `release-<n>`.
- Scope of the release goes in `release.md`.
- One file per screen under `screens/`, named after the screen slug.
- Never put two screens in one file.
- Releases are numbered from 1 and executed in ascending order.

## Templates

| Template | Copy to |
|---|---|
| `knowledge/requirement/templates/release.md` | `releases/release-<n>/release.md` |
| `knowledge/requirement/templates/screen.md` | `releases/release-<n>/screens/<slug>.md` |

AI agents must not modify the templates in this knowledge directory during normal
project generation.

## Status and locking

Every `release.md` carries a `status` in its front matter. The Requirement Analysis
Agent writes `draft`; the **Release Agent** is the only agent that changes it, and the
only one that fills in `deployed_at` and `commit` (`agents/release-agent.md`).

| Status | Meaning | Editable |
|---|---|---|
| `draft` | Analyzed, not started. Waiting in the queue. | yes |
| `in_progress` | Currently being built. | yes |
| `locked` | Built, deployed to the local Docker host, its required journeys passed. | **no, ever** |

Rules:

- When a release starts, the Release Agent sets `status: in_progress`.
- When a release meets the definition of done, the Release Agent sets
  `status: locked`, `deployed_at` to the date, and `commit` to the commit that
  satisfied the release, then commits. That commit is the lock.
- `commit` is what ties an approved specification to the code that delivered it. In
  `mono` layout it is the one commit made for that release. In `multi` layout it is
  one hash per repository the release touched, listed as a map:

  ```yaml
  commit:
    my-workspace-backend-account: a1b2c3d
    my-workspace-frontend-user: e4f5a6b
  ```

- `commit` is as immutable as the rest of a locked file. It is filled in once, at the
  moment of locking, and never corrected afterwards.
- A `locked` release file and its screen files must never be edited again, by any
  agent or by the human, for any reason.
- To change something in a locked release, create a **new** release directory with
  `type: change` and `supersedes: release-<n>`. It enters the same queue as any
  other release.
- A release that is still `draft` may be edited freely in place.
- The repository is git-versioned so an attempt to edit a locked release is
  visible in the history. Any agent that finds itself about to modify a `locked`
  file must stop and report instead.

## Queue

- Releases run strictly one at a time, in ascending release number.
- Release `n+1` is not started until release `n` is `locked`.
- A release is locked when it deploys and runs **and its required journeys pass**
  (`preflight/done-check.sh` and `preflight/journey-check.sh`), not when it is
  correct in every respect. A failing required journey keeps the release
  `in_progress` through at most 3 rework rounds; then the human decides. Any other
  defect is not a reason to keep a release open; it becomes a `type: change` release.

## Language

All release and screen files must be written in English, whatever language the
raw requirement arrived in.
