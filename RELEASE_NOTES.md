# Release Notes

## Unreleased

### Journeys gate the release, with a bound

A release used to be done when it deployed and its containers started. It is now done
only when a real user's journeys through it have been **executed** and have **passed**.
This reverses the v1.0.0 rule that journey tests report and never gate.

- **Order inside a release.** Implement and run natively, build images, deploy and pass
  `done-check.sh`, then write or update the journeys for the release's scope, provision
  the test zone, run the journeys, clean up, and lock.
- **Executed, not generated.** A Playwright or Maestro script that has not run proves
  nothing. Desktop browser mode is now the default and the recommended answer.
- **Rework loop.** A failing required journey produces evidence and a root cause in the
  run report. The Coding Agent that owns the repository fixes, rebuilds and redeploys,
  or the Journey Test Agent fixes its own script, and then every required journey runs
  again.
- **Bounded at 3 rounds.** After round 3 the loop stops, the test zone stays up, and the
  human is asked: lock anyway, three more rounds, or leave the release open. That
  question has no recommended option and is always asked, even in auto mode.
- **No weakening.** A fix may change how a step is performed, never whether it is
  performed or what is asserted. The required journeys are fixed before the first run.
- **Test zone.** Its own compose project, `$WORKSPACE_NAME-test`, with only the
  dependencies the release uses, running the images the release deployed. It no longer
  builds images of its own. Once the journeys pass it is removed without asking:
  containers, volumes, networks and run output. The "keep the test resources?" question
  is gone.
- **New:** `preflight/journey-check.sh`, which reads the release's run report and
  confirms with Docker that nothing of the test zone is left.
  `knowledge/journey/templates/run-report.md` and `templates/test-zone.yml`.
- **Mono layout** makes its single release commit after both `done-check.sh` and
  `journey-check.sh` pass, so journey rework lands in the same commit.
- Releases with no screen (an `mcp-server` alone, batch jobs, listeners) have no
  required journeys, and `done-check.sh` alone decides them.

### Every step has an owner, and every rule has one home

An audit of the framework's context found steps no agent owned, files that contradicted
each other, and rules repeated in up to six places, which is where agents drift. This
release closes them.

- **New: the Release Agent** (`agents/release-agent.md`). It creates the phase 2
  repositories, starts each release (`in_progress`), spawns the Coding Agents, deploys,
  relays journey rework, makes the single `mono` commit, locks the release and reads
  `release_execution`. Before this, no agent was allowed to do most of these. It is not
  a reviewer: its decisions come from files, script exit codes and the human's answers.
- **Only the Release Agent deploys.** Coding Agents build their image and add their
  service to the deployment's `local/`; parallel agents no longer deploy over each
  other.
- **Shared files are written one agent at a time.** `local-env/`, the deployment's
  `local/`, the config's `local/` and the `tool` repository are written under an atomic
  `mkdir` lock in `${WORKSPACE_PATH}/.locks/`. This is the third listed exception to
  "one repository, one agent", next to `mono` and `registry/openapi/`.
- **Three init questions, everywhere.** `agents/AGENTS.md` said two and forbade more.
- **Identity token is a nested JWT.** Signed with RS256, then encrypted as a JWE
  (`RSA-OAEP-256`, `A256GCM`). Each authentication group has a signing pair and an
  encryption pair, per environment. The old wording, "JWE signed with RS256", mixed the
  two layers up. Key layout: `keys/<group>/<environment>/` in the `config` repository.
- **Nginx is in every workspace that has a backend.** It used to require a frontend
  too, which left a mobile-only or MCP-only system without its mandatory gateway.
- **The MCP server is always its own release**, after the backends it wraps, and is
  regenerated in the release after any change to a backend's API. Its compose template
  now takes its tag by layout instead of a hard-coded `0.1.0`.
- **`journey-check.sh` reads the runner's own report.** Playwright's JSON and Maestro's
  JUnit output for the last run are kept under `runs/release-<n>/`, and every journey
  marked `passed` must pass there too. It also checks `rounds` against `max_rounds`, and
  accepts `result: accepted` only after a recorded `lock-anyway` answer.
- **`done-check.sh --mcp` speaks the protocol.** It initializes a session, lists tools,
  and calls the tool named by `--mcp-tool` with `--mcp-args`, with an optional
  `--mcp-token`. It used to call the first tool with no arguments and no session.
- **Inputs tables completed.** The Coding Agent now reads the deployment, config and
  requirement rules; the Journey Test Agent reads the gateway, versioning and deployment
  rules. Knowledge files are not loaded automatically, so a missing row meant an unread
  rule.
- **One home per rule.** Root `AGENTS.md` and `README.md` now summarize each topic in a
  line and link to its single source, instead of restating it.
- **Exact versions.** Node.js 24.21.0, Next.js 16.3.8, Java 25.0.4, Spring Boot 4.1.1,
  Python 3.13.16, PostgreSQL 16.15, Kafka 4.0.0 and Redis 8.2.10 (`redis:8.2.10`).
- Smaller fixes: the `mono` directory list names every type, `NOTES.md` quotes are in
  English, and compiled `__pycache__` files are no longer committed.

## v1.0.0 — 2026-10-05

The first tagged release of the framework. It is an AI agent framework that builds
complete systems in a separate workspace. It is built for fast feedback: the human
approves once at the start, and then agents run with no gates until the release runs
on a local Docker host.

This repository holds knowledge, rules and agent definitions only. No product code is
ever written here.

---

### Framework control

- **Workspace input.** `.env` takes one key, `WORKSPACE_PATH`. It is the only place
  agents may write.
- **Operating mode** (`flag.yml` → `mode`). `working` locks this repository against
  every agent write, including changes to the flag itself. `edit` opens it to the
  framework author. `preflight/mode-guard.sh` enforces the mode mechanically.
- **Release execution** (`flag.yml` → `release_execution`). With `manual`, agents stop
  after each locked release so the human can click through it. With `auto`, agents
  continue to the next draft release. Only the human sets this value.
- **Language rule.** All framework content and every generated artifact is in English.
  Raw requirements may arrive in any language.
- **NOTES.md** records ideas the human decided not to build yet. No agent works from it.

### Agents

| Agent | What it does | Human gate |
|---|---|---|
| Requirement Analysis Agent | Turns a raw requirement into English release and screen specifications | **yes**, the only one |
| Workspace Init Agent | Asks the three init questions, writes `workspace.yaml`, creates repositories and initializes git by layout | no |
| Coding Agent ×N | One per repository, run in parallel. Builds, runs locally and deploys | no |
| Journey Test Agent | Writes journeys, mock data and test scripts, then runs them and reports | no, and it has **no veto** |

- There are exactly **two checkpoints**: the human approves the requirement analysis,
  and the release must deploy and run on the local Docker host, verified by
  `preflight/done-check.sh`.
- There is deliberately **no QA or reviewer agent**. A logic defect, or a failing
  journey, comes back as a new `type: change` release.
- **Concurrency.** Exactly one agent owns a repository at any time. Ownership is a write
  set: a directory or a single file. No two agents ever write the same file.
- **Releases** run one at a time in ascending order. A release that has been built and
  deployed is `locked` and can never be edited again. A newer release overwrites an
  older one; nothing is reconciled.

### Asking the human

- Every question takes one shape: numbered options with one line each, a free-text
  slot last, and **one question at a time**.
- `workspace.auto_recommend` lets agents take the recommended option without asking.
  A question with no recommended option is still asked.
- Questions are inputs, not gates.

### Workspace initialization

Three questions, asked every time, are recorded in `workspace.yaml`:

| Question | Default when unanswered |
|---|---|
| Monorepo or multi-repo (`repo_layout`)? | `mono` |
| Build an MCP server (`mcp_server`)? | `false` |
| Take the recommended option without asking (`auto_recommend`)? | `false` |

### Repository types

`registry`, `requirement`, `deployment`, `config`, `tool`, `backend` (split by
domain), `frontend` (split by user group), `batch` (one per job), `listener` (one per
listener), `mobile` (split by user group), `mcp-server` (opt-in) and `journey`.

### Applications the framework builds

- **Backend:** Java 25 and Spring Boot 4.1. Each backend publishes its OpenAPI
  document to `registry/openapi/`.
- **Frontend:** Node.js 24, Next.js 16, MUI, Tailwind, TanStack Query and Zustand.
- **Mobile:** React Native 0.86 on Expo SDK 57, signed with Expo EAS Build. No secret
  is ever embedded in a build. Push notifications are added only when a project asks
  for them.
- **Batch jobs and listeners:** one repository each, with its responsibility written
  down.
- **MCP server** (opt-in): TypeScript 7 and MCP SDK v2. Its tools are generated
  mechanically from the registry's OpenAPI documents. It uses stdio locally and
  Streamable HTTP when deployed, and it exchanges the caller's token for an RS256 JWT
  at the backend. It never touches a datastore.
- Every version is pinned in `knowledge/tech-stack.yaml`, and no agent may change one.

### Infrastructure and runtime

- **Nginx gateway.** Every caller reaches the backend through Nginx only: frontend,
  mobile, the MCP server and anything added later. This holds in development and when
  deployed.
- **Datastores:** PostgreSQL 16, Kafka 4 and Redis. Each runs in workspace-scoped
  containers namespaced by `WORKSPACE_NAME`, and its data survives between releases.
- **Datastore access** goes only through the Python tools in the workspace's `tool`
  repository: `db_tool.py`, `kafka_tool.py` and `redis_tool.py`. They have full
  privileges on a **local** host and refuse any non-local host.
- **Three zones:**
  - **Develop zone:** host processes and dependency containers, for seeing the code
    work while writing it.
  - **Definition of done:** everything runs in Docker from the deployment repository.
  - **Test zone:** separate containers where journeys run against known mock data.
- **Deployment and config repositories**, with a local deploy template and the key-pair
  layout.

### Authentication

- The login method is **asked, never assumed**. The options are Google, Azure AD, LINE,
  Facebook, and username and password. Username and password is offered but never
  recommended. 2FA is added on top of another method, never on its own.
- Provider setup can be done two ways: the agent uses the provider's CLI, or the human
  follows a numbered portal checklist. The checklist is the default.
- **Tokens:** the identity token is JWE (encrypted). Data the frontend displays may be
  JWS. Signing is RS256, with one key pair per environment and per authentication
  group. No key ever reaches a browser or a mobile build.

### Journeys and journey tests

- The journey document is written first, from the code and the specifications. The
  script comes after it.
- Web journeys use Playwright 1.63. Mobile journeys use Maestro 2.11.
- Each journey gets its own mock data and runs in the test zone.
- Journey tests **report and never gate** a release.

### Versioning

- **Consumed** images (base images and dependencies) are pinned exactly and never use
  `latest`.
- **Produced** images are tagged `latest` in `mono` layout. In `multi` layout they take
  the repository's semantic git tag.

### Preflight scripts

| Script | Purpose |
|---|---|
| `preflight/checker.sh` | Checks that the machine is ready: Java 25, Node.js 24 with npm, Docker and Python 3.13 |
| `preflight/mode-guard.sh` | Exits `0` when the framework is writable (`edit`) and `1` when it is locked (`working`) |
| `preflight/done-check.sh` | Checks the definition of done: services are up and URLs respond. `--gateway` asserts Nginx, and `--mcp` asserts `tools/list` plus one real tool call |

---

### Known gaps and deferred items

These are recorded in `NOTES.md` and are **not** part of v1.0.0:

- Quality and change control: traceability, an impact analyzer, a verification gate,
  a full contract registry, rollback, and generators for environments, observability,
  security and documentation.
- Authentication: where key material lives, token lifetime and refresh, and key
  rotation.
- Journeys: formal preconditions tied to a named mock-data set, paths other than the
  happy path, and who decides what happens to a journey when the system changes.
- Mobile: internationalization and error tracking.
- A code index and code graph (SCIP).
