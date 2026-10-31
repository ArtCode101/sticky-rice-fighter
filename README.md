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

### Requirements

| Needed | Why |
|---|---|
| [Claude Code](https://claude.com/claude-code) | the framework runs as a Claude Code plugin |
| Node.js 18 or newer with npm | only for the `npx` install; the manual install does not need it |
| Java 25, Node.js 24 with npm, Docker, Python 3.13 | what the systems the framework builds need; `/srf:init` checks them with `preflight/checker.sh` (`checker.bat` on Windows) before it does anything else |

### Option 1: one command with npx (recommended)

```bash
npx sticky-rice-fighter
```

This adds the marketplace and installs the `srf` plugin at user scope, so the skills are
available in every directory you open. It needs nothing cloned and nothing configured.

### Option 2: manual install

The same two steps, run by hand. Use this if you cannot run `npx` or want to see each
step.

```bash
claude plugin marketplace add ArtCode101/sticky-rice-fighter
```

```bash
claude plugin install srf@sticky-rice-fighter --scope user
```

`--scope user` makes the skills available in every directory you open. Use
`--scope project` to install it for one project only.

### Check the install

```bash
claude plugin list
```

`srf@sticky-rice-fighter` should be listed as enabled. Inside Claude Code, typing `/srf:`
should offer `init`, `analyze` and `release`.

### Update

```bash
npx sticky-rice-fighter update
```

or, by hand:

```bash
claude plugin update srf@sticky-rice-fighter
```

Restart Claude Code afterwards so the new version loads.

### Uninstall

```bash
claude plugin uninstall srf@sticky-rice-fighter
```

```bash
claude plugin marketplace remove sticky-rice-fighter
```

### Troubleshooting

| Symptom | Fix |
|---|---|
| `Claude Code was not found on PATH` | install Claude Code, then open a new terminal and run the command again |
| `/srf:` offers nothing | run `claude plugin list`; if `srf` is missing or disabled, install or enable it, then restart Claude Code |
| An old version keeps loading | run the update command above and restart Claude Code |

## Use

### Step by step

1. Make an empty directory for the system you want to build. This directory **is** the
   workspace; everything the framework writes lands inside it.

   ```bash
   mkdir my-workspace && cd my-workspace
   ```

2. Open Claude Code in it.

   ```bash
   claude
   ```

3. Run `/srf:init` once. It checks the machine, asks the three questions, writes
   `workspace.yaml` and `CLAUDE.md`, and creates the phase 1 repositories.
4. Describe what you want built, in any language, and run `/srf:analyze`. Read the
   releases and screen specifications it produces, then approve them. This is the only
   gate.
5. Run `/srf:release`. It builds, deploys and tests the next `draft` release, then locks
   it. With `release_execution: manual` (the default), run `/srf:release` again for each
   following release; with `auto` it continues on its own.
6. For a new requirement later, open Claude Code in the same directory and start again
   from step 4.

### The three skills

Inside Claude Code:

| Skill | When | What it does |
|---|---|---|
| `/srf:init` | once, at the start | asks the three questions, writes `workspace.yaml` and `CLAUDE.md`, creates the phase 1 repositories |
| `/srf:analyze` | for every new requirement | turns it into releases and screen specifications, then waits for your approval |
| `/srf:release` | after an approval | runs the next `draft` release until it is deployed, its journeys pass, and it locks |

The directory you opened Claude Code in **is** the workspace. Everything the framework
writes lands inside it; nothing is written into the plugin. `CLAUDE.md`, placed by
`/srf:init`, carries the framework's rules into every later session in that directory.

## Layout

```text
.
├── AGENTS.md                  # framework rules, and where every other rule lives
├── NOTES.md                   # recorded ideas that are deliberately NOT built
├── RELEASE_NOTES.md           # what each framework version contains
├── .claude-plugin/
│   ├── plugin.json            # the srf plugin: name and version
│   └── marketplace.json       # the marketplace that serves it
├── skills/                    # what the human runs, in their own session
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

`NOTES.md` holds ideas that were recorded and deliberately not built; no agent works
from it.

## Developing the framework

Open Claude Code in this repository to change the framework; the guard hook recognizes
that case. Validate with `claude plugin validate .`, and try a change from an empty
scratch directory with `claude --plugin-dir <path to this repository>` before bumping
the version in `.claude-plugin/` and tagging. `AGENTS.md` has the rest.
