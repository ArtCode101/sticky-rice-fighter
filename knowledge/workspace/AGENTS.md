# Workspace Manifest Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/workspace/`

## Purpose

The files in this directory define the workspace manifest: the single file that
declares every repository in a workspace, its type, and when it is created.

## Template usage

File:

`knowledge/workspace/templates/workspace.yaml`

Use this file as the standard workspace manifest reference.

AI agents should:

- Read this file when a workspace is initialized.
- Copy it to `${WORKSPACE_PATH}/workspace.yaml` and replace the placeholder
  workspace and repository names with real ones.
- Keep the schema, field names and phase semantics unchanged.
- Append phase 2 entries to the workspace copy as new repositories are identified.

AI agents must not:

- Modify this knowledge file during normal project generation.
- Store a local host path for any repository.
- Add repository types that are not in the list below.
- Create more than one `registry` or more than one `requirement` repository.

## Schema

| Field | Required | Meaning |
|---|---|---|
| `workspace.name` | yes | Name of the workspace. |
| `workspace.repo_layout` | yes | `mono` or `multi`. Asked of the human at initialization and never changed afterwards. See **Repository layout mode**. |
| `workspace.mcp_server` | yes | `true` or `false`. Whether the human asked for an MCP server. See **The MCP server is opt-in**. |
| `workspace.auto_recommend` | yes | `true` or `false`. Whether agents may take the recommended option without asking. See `knowledge/questions/AGENTS.md`. |
| `repos[].name` | yes | Repository name. Names only — never a local host path. |
| `repos[].type` | yes | One of `registry`, `requirement`, `deployment`, `config`, `tool`, `backend`, `frontend`, `mobile`, `batch`, `listener`, `mcp-server`, `journey`. |
| `repos[].phase` | yes | Creation phase. `1` = create immediately, `2` = create once the requirement analysis says it is needed. |
| `repos[].remote` | no | Git remote link. May be `null` and filled in later. In `mono` layout there is one remote for the whole workspace, so this field stays `null` on every entry. |

## Repository types

| Type | Cardinality | Purpose |
|---|---|---|
| `registry` | exactly 1 | Lists every repository in the workspace with its type. The workspace's own index. |
| `requirement` | exactly 1 | Holds the release and screen specifications produced by the Requirement Analysis Agent. Git-versioned as an audit trail. |
| `deployment` | 1 or more | Deploy scripts for the local Docker host and for real environments. Created empty in phase 1. |
| `config` | 1 or more | Configuration for every part of the system. Read by the deployment repository at deploy time. Created empty in phase 1. |
| `tool` | 0 or 1 | The Python tools that are the only sanctioned way for an agent to reach PostgreSQL, Kafka or Redis. See `knowledge/tools/AGENTS.md`. |
| `backend` | 0 or more | Backend services, split by domain. Created in phase 2. |
| `frontend` | 0 or more | Frontend applications, split by user group. Created in phase 2. |
| `batch` | 0 or more | Batch jobs. **One repository per batch job.** Created in phase 2. |
| `listener` | 0 or more | Queue and stream listeners. **One repository per listener.** Created in phase 2. |
| `mcp-server` | 0 or 1 | The MCP adapter over the backend API, so an outside AI agent can drive the system. Created in phase 2, and **only when the human asked for one**. See `knowledge/mcp/AGENTS.md`. |
| `mobile` | 0 or more | React Native applications, split by user group the same way frontends are. Created in phase 2. See `knowledge/mobile/AGENTS.md`. |
| `journey` | 0 or 1 | The journey documents, mock data and journey test scripts for the whole workspace. Created in phase 2. See `knowledge/journey/AGENTS.md`. |

### Batch and listener repositories

A batch job and a listener each get their **own** repository. They are never
collected into one shared repository.

Every batch and listener repository must state its single responsibility in writing,
in its `README.md`: what this specific job or listener does, what it consumes and
what it produces. A repository whose responsibility cannot be written in a sentence
has been scoped wrongly.

Their configuration may be edited to connect to the real source, the same way a
backend's may.

### The MCP server is opt-in

There is no `mcp-server` entry unless the human asked for one. `workspace.mcp_server`
records the answer, given once at initialization.

- `false`, or absent, means the repository is never created and nothing MCP-related
  is generated.
- `false` is not a permanent refusal. If the human later asks for an MCP server
  directly, append the entry and set the field to `true`. The field exists to stop
  agents from asking again, not to override an instruction.
- At most one, whatever the number of backend domains. One server covers them all.

Full rules: `knowledge/mcp/AGENTS.md`.

### Registry repository layout

The `registry` repository is the workspace's index, and it is also where each backend
publishes the OpenAPI document that the MCP server is generated from.

```text
<workspace>-registry/
├── repos.yaml              # the repository index: every repository and its type
├── openapi/
│   ├── <backend-1>.json    # written by the agent that owns <backend-1>, only
│   └── <backend-2>.json    # written by the agent that owns <backend-2>, only
└── README.md
```

**Ownership inside this repository is the file, not the repository.** This is a
deliberate exception to "one repository, one agent", and it is the only one:

- The agent that owns backend X writes `openapi/<X>.json` and nothing else.
- It must not touch another backend's document, `repos.yaml`, or anything else here.
- Two agents therefore work in this repository at the same time, each in its own
  file. That is allowed precisely because their write sets cannot overlap.

The document is regenerated as part of the backend's own release work, so it moves
with the code rather than drifting behind it.

## Repository layout mode

`workspace.repo_layout` decides how git is laid out across the workspace. The human
chooses it at initialization; no agent chooses it and no agent changes it afterwards.

| Mode | Git layout |
|---|---|
| `multi` | One git repository per manifest entry. `git init` runs once per repository. |
| `mono` | **One** git repository at the workspace root. `git init` runs once, and every repository in the manifest — `registry`, `requirement`, `deployment`, `config`, `tool`, every `backend`, `frontend`, `batch`, `listener` and the `mcp-server` — is a directory inside it. |

In both modes the manifest is the same list of repositories with the same names and
types. Only the git boundary moves.

In `mono` mode:

- Coding agents write files and **do not commit**. One commit is made per release,
  after `preflight/done-check.sh` and `preflight/journey-check.sh` pass — so journey
  rework lands in the same commit — and parallel agents never contend for the git
  index and no merge step is introduced.
- There is deliberately no intermediate checkpoint inside a release.
- `repos[].remote` stays `null`; the single remote belongs to the workspace.

In `multi` mode each repository commits as it always has.

## Phases

Phase 1 repositories have no dependencies on any requirement analysis, so they
are all created together at workspace initialization: `registry`, `requirement`,
an empty `deployment` and an empty `config`.

Phase 2 repositories depend on the requirement analysis, which decides how many
backend repositories are needed (one per domain), how many frontend repositories are
needed (one per user group, for example a separate admin portal and general-user
site), and whether the release needs any `batch` or `listener` repositories. They
are appended to the workspace manifest and created only once that analysis is
approved.

The `tool` repository is created the first time an agent needs to reach a datastore,
which in practice is during the first release. It carries `phase: 2`.

The `mcp-server` repository carries `phase: 2` as well, and is appended only when
`workspace.mcp_server` is `true`.

The `mobile` repositories carry `phase: 2`, one per user group, appended when the
requirement implies a mobile application.

The `journey` repository carries `phase: 2` and is created the first time journeys are
written for the workspace, which in practice is the first release that produces a
clickable system.
