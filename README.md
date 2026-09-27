# sticky-rice-fighter

An AI agent framework for building systems in a separate workspace, designed
around fast feedback: one human approval at the start, then agents run without
gates until the release actually runs on a local Docker host.

This repository is the **framework**. It holds knowledge, rules and agent
definitions. No product code is ever written here.

## Layout

```text
.
├── AGENTS.md                  # framework rules: mode, workspace input, language
├── flag.yml                   # human switches: operating mode, release execution
├── .env.example               # WORKSPACE_PATH contract
├── agents/                    # agent definitions
│   ├── AGENTS.md              # flow, gates, concurrency, priority
│   ├── workspace-init-agent.md
│   ├── requirement-analysis-agent.md
│   └── coding-agent.md
├── knowledge/
│   ├── tech-stack.yaml        # fixed languages, frameworks, libraries, versions
│   ├── workspace/             # workspace manifest schema and template
│   ├── requirement/           # release and screen spec templates, locking rules
│   ├── deployment/            # deploy layout and local deploy template
│   ├── config/                # config layout and key-pair rules
│   ├── database/              # PostgreSQL knowledge and compose template
│   ├── redis/                 # Redis knowledge and compose template
│   ├── kafka/                 # Kafka knowledge and compose template
│   └── java-spring-boot/      # backend project structure reference
└── preflight/
    ├── checker.sh             # is this machine ready to develop
    ├── mode-guard.sh          # is the framework writable
    └── done-check.sh          # does a release meet the definition of done
```

## Getting started

```bash
cp .env.example .env
# set WORKSPACE_PATH to the workspace you want to build in
./preflight/checker.sh
```

`checker.sh` must pass before anything else: it verifies Java 25, Node.js 24,
Docker and Python 3.13.

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
raw requirement (any language)
      |
      v
Requirement Analysis Agent  --->  human approves      <- the only gate
      |
      v
Workspace Init Agent        --->  creates repositories
      |
      v
Coding Agent x N            --->  one per repository, in parallel
      |
      v
release runs on local Docker host                     <- the only other check
```

## The two checkpoints

1. The human approves the requirement analysis, once, before any code is written.
2. A release deploys and runs on the local Docker host and can be clicked through,
   verified by `preflight/done-check.sh`.

Nothing else is gated. There is no QA agent and no reviewer agent, and no agent
judges whether its own work is good enough — that is what produces loops that never
end. Logic defects are acceptable: they come back as a new `type: change` release
and re-enter the queue.

Releases run strictly one at a time in ascending order. A release that has been
built and deployed is marked `locked` in the `requirement` repository and can never
be edited again.

## Rules that never bend

- One repository is owned by exactly one agent at a time.
- A newer release overwrites an older one. Nothing is reconciled.
- Versions pinned in `knowledge/tech-stack.yaml` are never changed by an agent, and
  no Docker image uses the `latest` tag.
- Login is username and password. Tokens are JWT signed with RS256 only, with one
  RSA key pair per authentication group.
- All framework content and all generated artifacts are written in English.

Start with `AGENTS.md` for the full rules, then `agents/AGENTS.md` for the flow.
