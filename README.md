# sticky-rice-fighter

An AI agent framework for building systems, designed around fast feedback: one human
approval at the start, then agents run without human gates until the release actually
runs on a local Docker host and a real user's journeys through it have been executed
and passed.

It is packaged as a **Claude Code plugin** named `srf`. You install it once, open
Claude Code in the directory you want to build in, and drive it with three skills.
This repository is the framework: knowledge, rules, skills and subagent definitions.
No product code is ever written here.

This README is an overview for people. Every rule lives in exactly one file, listed in
**Where each rule lives** in `AGENTS.md`; when this page and that file disagree, the
file is right.

## Install

```bash
claude plugin marketplace add ArtCode101/sticky-rice-fighter
```

```bash
claude plugin install srf@sticky-rice-fighter --scope user
```

`--scope user` makes the skills available in every directory you open. Later versions
arrive with `claude plugin update srf@sticky-rice-fighter`. The same two steps, as one
command: `npx sticky-rice-fighter` (and `npx sticky-rice-fighter update` later).

The machine needs Java 25, Node.js 24 with npm, Docker and Python 3.13. Check it any
time with `/srf:preflight` inside Claude Code, or `npx sticky-rice-fighter preflight`
from a terminal; both run `preflight/checker.sh` (`checker.bat` on Windows). `/srf:init`
runs the same check before it does anything else.

## Use

```bash
mkdir my-workspace && cd my-workspace
```

```bash
claude
```

Then, inside Claude Code:

| Skill | When | What it does |
|---|---|---|
| `/srf:preflight` | any time | checks that this machine is ready to build, and changes nothing |
| `/srf:init [requirement file]` | once, at the start | reads the requirement file if given, asks only the questions it does not answer, writes `workspace.yaml` and `CLAUDE.md`, creates the phase 1 repositories |
| `/srf:analyze <requirement>` | for every new requirement | turns it into releases and screen specifications, then waits for your approval |
| `/srf:release` | after an approval | runs the next `draft` release until it is deployed, its journeys pass, and it locks |

The directory you opened Claude Code in **is** the workspace. Everything the framework
writes lands inside it; nothing is written into the plugin. `CLAUDE.md`, placed by
`/srf:init`, carries the framework's rules into every later session in that directory.

If the requirement is already written down, give its path to both skills:
`/srf:init requirement.md`, then `/srf:analyze requirement.md`. Anything the file
states — "one repository", "needs an MCP server", "users sign in with Google" — is
taken as your answer and not asked again; anything it only hints at is still asked.

## Layout

```text
.
├── AGENTS.md                  # framework rules, and where every other rule lives
├── NOTES.md                   # recorded ideas that are deliberately NOT built
├── RELEASE_NOTES.md           # what each framework version contains
├── .claude-plugin/
│   ├── plugin.json            # the srf plugin: name and version
│   └── marketplace.json       # the marketplace that serves it
├── bin/cli.js                 # npx sticky-rice-fighter: install, update, preflight
├── skills/                    # what the human runs, in their own session
│   ├── preflight/SKILL.md     # is this machine ready, on its own
│   ├── init/SKILL.md          # Workspace Init Agent
│   ├── analyze/SKILL.md       # Requirement Analysis Agent
│   └── release/SKILL.md       # Release Agent
├── agents/                    # subagents the Release Agent spawns
│   ├── coding-agent.md
│   └── journey-test-agent.md
├── hooks/
│   ├── hooks.json             # PreToolUse: the framework is read-only
│   └── guard-framework.js
├── knowledge/
│   ├── flow/                  # flow, gates, concurrency, file ownership, where the files are
│   ├── tech-stack.yaml        # fixed languages, frameworks, libraries, exact versions
│   ├── workspace/             # workspace manifest schema, manifest and CLAUDE.md templates
│   ├── requirement/           # release and screen spec templates, locking rules
│   ├── questions/             # the one shape every question to the human takes
│   ├── auth/                  # login patterns, provider setup, token and key rules
│   ├── mobile/                # React Native and Expo applications
│   ├── journey/               # user journeys, mock data and journey tests
│   ├── versioning/            # git tags and image tags, by repository layout
│   ├── local-env/             # dependency containers for the develop phase
│   ├── local-run/             # running backend, frontend and Nginx on the host
│   ├── nginx/                 # the mandatory gateway in front of every backend
│   ├── mcp/                   # the MCP server generated over the backend API
│   ├── tools/                 # the only sanctioned datastore access path
│   ├── deployment/            # deploy layout and local deploy template
│   ├── config/                # config layout and key layout
│   ├── database/              # PostgreSQL knowledge and compose template
│   ├── redis/                 # Redis knowledge and compose template
│   ├── kafka/                 # Kafka knowledge and compose template
│   └── java-spring-boot/      # backend project structure reference
└── preflight/
    ├── checker.sh             # is this machine ready to develop
    ├── checker.bat            # the same check, for Windows
    ├── done-check.sh          # does a release deploy and run
    └── journey-check.sh       # did its required journeys pass, and is the test zone gone
```

## The one switch

`release_execution` lives in the workspace's `workspace.yaml` and only you change it.

| Value | Meaning |
|---|---|
| `manual` | Stop after each release locks. You click through the running system and run `/srf:release` again. |
| `auto` | Continue to the next `draft` release until none is left. |

`/srf:init` writes `manual`. The framework itself has no switch any more: it is
read-only wherever it is installed, enforced by the plugin's own hook, and it is edited
only in this repository.

## How a build runs

```text
/srf:init                   --->  phase 1 repositories, three questions
      |
raw requirement (any language)
      |
      v
/srf:analyze                --->  human approves      <- the only gate
      |
      v
/srf:release                --->  creates phase 2 repositories, starts the release
      |
      v
coding-agent x N            --->  one per repository, in parallel
      |
      v
/srf:release                --->  deploys, done-check.sh
      |
      v
journey-test-agent          --->  journeys executed in a test zone
      |                           failed -> rework, at most 3 rounds, then you decide
      v
all required journeys pass  --->  journey-check.sh
      |
      v
/srf:release                --->  release locked     <- the only other check
```

The full flow, the two checkpoints and why there is no QA or reviewer agent are in
`knowledge/flow/AGENTS.md`.

## What you will be asked

Agents ask one question at a time, as numbered options with a free-text slot last
(`knowledge/questions/AGENTS.md`). At initialization there are three: monorepo or
multi-repo, whether you want an MCP server, and whether agents may take the option they
recommend without asking. After that, questions come only when a decision is genuinely
yours — a login method, a provider setup, what to do when journey rework runs out.

Agents read what you gave them before asking. A question your requirement file already
answers outright is not asked; the answer is recorded as yours, and the report says
where it came from. A hint is not an answer, so that question is still asked.

`NOTES.md` holds ideas that were recorded and deliberately not built; no agent works
from it.

## Developing the framework

Open Claude Code in this repository to change the framework; the guard hook recognizes
that case. Validate with `claude plugin validate .`, and try a change from an empty
scratch directory with `claude --plugin-dir <path to this repository>` before bumping
the version in `.claude-plugin/` and tagging. `AGENTS.md` has the rest.
