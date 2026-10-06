# sticky-rice-fighter

An AI agent framework for building systems in a separate workspace, designed
around fast feedback: one human approval at the start, then agents run without
human gates until the release actually runs on a local Docker host and a real user's
journeys through it have been executed and passed.

This repository is the **framework**. It holds knowledge, rules and agent
definitions. No product code is ever written here.

This README is an overview for people. Every rule lives in exactly one file, listed in
**Where each rule lives** in `AGENTS.md`; when this page and that file disagree, the
file is right.

## Layout

```text
.
├── AGENTS.md                  # framework rules, and where every other rule lives
├── NOTES.md                   # recorded ideas that are deliberately NOT built
├── RELEASE_NOTES.md           # what each framework version contains
├── flag.yml                   # human switches: operating mode, release execution
├── .env.example               # WORKSPACE_PATH contract
├── agents/                    # agent definitions
│   ├── AGENTS.md              # flow, gates, concurrency, file ownership
│   ├── workspace-init-agent.md
│   ├── requirement-analysis-agent.md
│   ├── release-agent.md
│   ├── coding-agent.md
│   └── journey-test-agent.md
├── knowledge/
│   ├── tech-stack.yaml        # fixed languages, frameworks, libraries, exact versions
│   ├── workspace/             # workspace manifest schema and template
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
    ├── mode-guard.sh          # is the framework writable
    ├── done-check.sh          # does a release deploy and run
    └── journey-check.sh       # did its required journeys pass, and is the test zone gone
```

## Getting started

```bash
cp .env.example .env
# set WORKSPACE_PATH to the workspace you want to build in
./preflight/checker.sh
```

`checker.sh` must pass before anything else: it verifies Java 25, Node.js 24 with
npm, Docker and Python 3.13.

## The two switches

Both live in `flag.yml` and only the human changes them.

| Switch | Values | Meaning |
|---|---|---|
| `mode` | `working` / `edit` | `working` locks this repository against all agent writes. `edit` opens it for the framework author. |
| `release_execution` | `manual` / `auto` | `manual` stops after each release for the human to click through. `auto` continues to the next release. |

Keep `mode: working` whenever agents are building a system. Switch to `edit` only
to change the framework itself.

## How a build runs

```text
Workspace Init Agent        --->  phase 1 repositories, three questions
      |
raw requirement (any language)
      |
      v
Requirement Analysis Agent  --->  human approves      <- the only gate
      |
      v
Release Agent               --->  creates phase 2 repositories, starts the release
      |
      v
Coding Agent x N            --->  one per repository, in parallel
      |
      v
Release Agent               --->  deploys, done-check.sh
      |
      v
Journey Test Agent          --->  journeys executed in a test zone
      |                           failed -> rework, at most 3 rounds, then you decide
      v
all required journeys pass  --->  journey-check.sh
      |
      v
Release Agent               --->  release locked     <- the only other check
```

The full flow, the two checkpoints and why there is no QA or reviewer agent are in
`agents/AGENTS.md`.

## What you will be asked

Agents ask one question at a time, as numbered options with a free-text slot last
(`knowledge/questions/AGENTS.md`). At initialization there are three: monorepo or
multi-repo, whether you want an MCP server, and whether agents may take the option they
recommend without asking. After that, questions come only when a decision is genuinely
yours — a login method, a provider setup, what to do when journey rework runs out.

`NOTES.md` holds ideas that were recorded and deliberately not built; no agent works
from it.
