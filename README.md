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
├── NOTES.md                   # recorded ideas that are deliberately NOT built
├── flag.yml                   # human switches: operating mode, release execution
├── .env.example               # WORKSPACE_PATH contract
├── agents/                    # agent definitions
│   ├── AGENTS.md              # flow, gates, concurrency, priority
│   ├── workspace-init-agent.md
│   ├── requirement-analysis-agent.md
│   ├── coding-agent.md
│   └── journey-test-agent.md
├── knowledge/
│   ├── tech-stack.yaml        # fixed languages, frameworks, libraries, versions
│   ├── workspace/             # workspace manifest schema and template
│   ├── requirement/           # release and screen spec templates, locking rules
│   ├── questions/             # the one shape every question to the human takes
│   ├── auth/                  # login patterns, provider setup, token rules
│   ├── mobile/                # React Native and Expo applications
│   ├── journey/               # user journeys, mock data and journey tests
│   ├── versioning/            # git tags and image tags, by repository layout
│   ├── local-env/             # dependency containers for the develop phase
│   ├── local-run/             # running backend, frontend and Nginx on the host
│   ├── nginx/                 # the mandatory gateway in front of every backend
│   ├── mcp/                   # the MCP server generated over the backend API
│   ├── tools/                 # the only sanctioned datastore access path
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

## How agents ask

Every question any agent asks takes one shape: numbered options, one line each saying
what it means, a free-text slot last, and **one question at a time**.

```text
Which login method should this system use?

  1. Google / Gmail        — OAuth; needs a Google Cloud project  [recommended]
  2. LINE                  — OAuth; set up by hand in LINE Developers Console
  3. Username and password — no provider to set up; weakest of the three
  4. Something else        — type your answer
```

A wall of ten or twenty questions is the failure this replaces. Full rules:
`knowledge/questions/AGENTS.md`.

## Three questions at initialization

The Workspace Init Agent asks the human three things, every time, one at a time, and
writes all three answers into `workspace.yaml` so nothing asks again.

| Question | When the human does not answer |
|---|---|
| Monorepo or multi-repo? | **`mono`** — one git repository at the workspace root. Work is not blocked on a decision. |
| Do you want an MCP server? | **`false`** — nothing is built. Nothing is generated that was not asked for. |
| May agents take the recommended option without asking? | **`false`** — every question is asked. |

The first two defaults point in opposite directions on purpose. An agent never answers
the layout question on the human's behalf while they still have the chance to, and a
`false` on the MCP question is not permanent: a direct request later still gets built.

`auto_recommend: true` does not silence every question. A decision where no option is
clearly best is still brought to the human, because there is no recommendation to apply.

These are inputs, not gates. The framework still has exactly two checkpoints.

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
      |
      v
Journey Test Agent          --->  journeys, mock data, tests; reports, never gates
```

## Developing versus finishing

These two look similar and are not the same thing.

| | Develop phase | Definition of done |
|---|---|---|
| Dependencies | containers, per workspace, started by any agent that needs them | containers, from the deployment repository |
| Backend, frontend, batch, listeners | host processes | Docker containers |
| Nginx | host process | Docker container |
| MCP server | host process, stdio | Docker container, Streamable HTTP |
| Mobile app | emulator or simulator, driven with `adb` / `simctl` | signed build through Expo EAS |
| Datastore access | Python tools, full privileges, local only | — |
| Purpose | see the code work while writing it | finish the release |
| Verified by | the agent looking at it | `preflight/done-check.sh` |

An agent may start, stop and poke at the develop phase as much as it likes. None of
it finishes a release. Only a Docker deploy that `done-check.sh` passes does.

**Journeys run somewhere else again.** The develop zone is what the human clicks
through; a journey runs in a **test zone** with its own containers, where the
application is built as a Docker image. A journey needs a known starting state, and the
develop zone is full of whatever the human has been clicking on.

Dependency containers belong to one workspace, are namespaced by `WORKSPACE_NAME`,
and stay up across releases. Data survives `local-env.sh down`; only
`local-env.sh destroy --yes`, which the human asks for, deletes it.

## The two checkpoints

1. The human approves the requirement analysis, once, before any code is written.
2. A release deploys and runs on the local Docker host and can be clicked through,
   verified by `preflight/done-check.sh`. An `mcp-server` has no screen, so
   `done-check.sh --mcp` checks instead that the service is deployed, `tools/list`
   responds, and one real tool call reaches the backend.

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
  no **consumed** image uses the `latest` tag. An image the framework **builds** is
  tagged `latest` in monorepo layout and with its repository's git tag in multi-repo
  layout.
- No secret is ever embedded in a mobile build.
- The login method is **asked**, never assumed. Username and password is on the list
  but is never the recommended option.
- The identity token is **JWE**, encrypted. Data the frontend displays may be JWS.
  Signing is RS256 with a key pair — one per authentication group, **and** one per
  environment.
- **Every** caller reaches the backend through **Nginx only**, while developing and
  when deployed: the frontend, the MCP server, and anything added later.
- A generated **MCP server** wraps the backend API and never touches a datastore, and
  it is built only when the human asked for one.
- Agents reach PostgreSQL, Kafka and Redis through the **Python tools** in the
  workspace's `tool` repository and nothing else, against a **local** host only.
- Every batch job and every listener gets its own repository, with its
  responsibility written down.
- Ownership may be a directory or a single file, but no two agents ever write the same
  file.
- Questions are asked one at a time, as numbered options with a free-text slot.
- Journey tests report. They never gate a release.
- All framework content and all generated artifacts are written in English.

Start with `AGENTS.md` for the full rules, then `agents/AGENTS.md` for the flow.
`NOTES.md` holds ideas that were recorded and deliberately not built; no agent works
from it.
