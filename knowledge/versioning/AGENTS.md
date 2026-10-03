# Versioning and Tagging Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/versioning/`

and governs how built artifacts are versioned and tagged in the workspace.

## Purpose

When something is wrong in a running system, the first question is *which code is
this*. These rules exist so that question has an answer.

What the answer looks like depends on `workspace.repo_layout`, because a monorepo and a
multi-repo workspace have different things to point at.

## Two `latest` rules that are not the same rule

The framework has always said no image uses the `latest` tag. That rule is about images
the framework **consumes**. It does not govern images the framework **produces**.

| Image | Tag |
|---|---|
| Consumed: `postgres`, `redis`, `kafka`, `nginx`, `node` and any other base or dependency image | **Pinned exactly** in `knowledge/tech-stack.yaml`. Never `latest`, never a floating tag. |
| Produced: an image built from this workspace's own code | Per the layout below. In monorepo layout that is `latest`. |

The reason the two differ: a dependency on `latest` changes underneath the system
without anyone choosing it, which is the failure the original rule prevents. An image
just built from code just written has no such exposure — the code is right there.

AI agents must not relax the first rule, and must not apply the first rule's wording to
the second case in order to refuse a `latest` tag on a produced image.

## Monorepo layout

`workspace.repo_layout: mono`.

- Built images are tagged **`latest`**, always.
- **No git tagging.** One repository holds everything, so a per-repository version
  number has nothing to mean.
- The link from a running system back to its code is the release's `commit` field in
  `release.md`, which already records the one commit that satisfied that release.

## Multi-repo layout

`workspace.repo_layout: multi`.

- **Tag the repository before building it.** The tag is a semantic version, and it is
  created first so that the build has a known version to carry.
- **A built image is tagged with the same number as the repository's git tag.** An
  image version therefore names exactly the code it came from.

### Choosing the number

| Bump | When | Who decides |
|---|---|---|
| **patch** | A small fix. | The agent, on its own. |
| **minor** | A new feature. | The agent, on its own. |
| **major** | A breaking change. | The agent when it is clear-cut; otherwise it **asks**. |

A **breaking change** means:

- An existing feature is removed and replaced with a different one, so what worked
  before does not work now.
- The user interface is replaced across every screen of the application.

When an agent is unsure whether a change is major, it asks, through
`knowledge/questions/AGENTS.md` like any other question. It does not quietly pick minor
to avoid the conversation, and it does not quietly pick major to be safe.

## Mobile builds and store versions

A store submission is not a Docker tag and is not covered by the `latest` rule.

iOS and Android both require a real version that increases on every submission, and
reject a number that has already been submitted. A mobile build headed for a store
therefore always carries such a number, in **both** layouts. In monorepo layout it is
not derived from a git tag, since there is none; it is tracked for the mobile
repository and incremented on each submission.

An internal build that never reaches a store is not bound by this.

## Must not

- Pin a consumed image to `latest` or any floating tag.
- Refuse to tag a produced image `latest` in monorepo layout.
- Build a multi-repo repository before it has been tagged.
- Give a multi-repo image a tag that differs from its repository's git tag.
- Decide a major bump on the human's behalf when the case is not clear-cut.
- Reuse a mobile store version number.
- Modify the knowledge files in this directory during normal project generation.
