---
release: 1
title: System skeleton
type: feature          # feature | change
supersedes: null       # for type: change, the locked release this replaces
status: draft          # draft | in_progress | locked
deployed_at: null      # ISO date, set when the release is locked
commit: null           # set when the release is locked: the commit that satisfied it
---

# Release 1: System skeleton

## Scope

What this release delivers. One line per item, concrete enough to build from.

- ...
- ...

## Out of scope

What this release deliberately does not deliver, so a later release can pick it up.

- ...

## Repositories touched

| Repository | Type | Why |
|---|---|---|
| ... | backend | ... |
| ... | frontend | ... |

One agent per repository. Repositories in this list are built in parallel.

## Screens

One file per screen under `screens/`. List them here.

| Screen | File | User group |
|---|---|---|
| ... | `screens/<slug>.md` | ... |

Leave this section empty if the release has no user interface.

## Authentication

| User group | Requires login | Login method | Key pair |
|---|---|---|---|
| ... | yes / no | the method the human chose | own RS256 key pair / none |

The login method is whatever the human picked from the options in
`knowledge/auth/AGENTS.md`; it is never assumed. The identity token is **JWE**,
encrypted; data the frontend displays may be **JWS**. Signing is RS256 with a key pair.
Each authentication group gets its own pair and each environment gets its own; a group
that does not authenticate gets none.

## Definition of done

The system deploys and runs on the local Docker host and can be clicked through.
Logic correctness is not checked here. Defects found later become a new release
of `type: change`.
