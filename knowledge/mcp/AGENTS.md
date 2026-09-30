# MCP Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/mcp/`

and governs the content of the workspace's `mcp-server` repository.

## Purpose

An MCP server exposes the system this framework built so an **outside** AI agent can
drive it. It is a thin adapter over the backend API and nothing more.

The framework generates the **server**. It never generates a client: the client is
the outside agent. The client stack is pinned in `knowledge/tech-stack.yaml` for
reference only.

## The rule that never bends

**The MCP server reaches the system through the backend API only.**

```text
AI Agent  ->  MCP Client  ->  MCP Server  ->  Nginx  ->  Backend API  ->  Database
```

AI agents must not:

- Connect the MCP server to PostgreSQL, Kafka or Redis. Not through a driver, not
  through the Python tools in the `tool` repository, not at all.
- Point the MCP server at a backend port. It goes through Nginx like every other
  caller.
- Put business logic in the MCP server. If a rule is missing, it belongs in the
  backend.

This is a different rule from the one in `knowledge/tools/AGENTS.md`. That one
governs how an **agent** reaches a datastore while it works. This one governs the
**product code the framework generates**. Neither implies the other, and both hold.

## Opt-in

The MCP server is built only when the human asked for one.

- `workspace.mcp_server` in `${WORKSPACE_PATH}/workspace.yaml` holds the answer,
  recorded once by the Workspace Init Agent.
- `false`, or absent, means **do not build it**. No agent creates an `mcp-server`
  repository on its own initiative.
- `false` is not a permanent refusal. If the human later asks for an MCP server
  directly, build it and set the field to `true`. The field stops agents from asking
  again; it does not override a direct instruction.

## Where it lives

One `mcp-server` repository per workspace, at most, declared in the manifest with
`type: mcp-server`. One server covers every backend domain, so the calling agent
needs one connection to reach the whole system.

```text
<workspace>-mcp-server/
├── src/
│   ├── server.ts            # from templates/server.ts
│   ├── token-exchange.ts    # from templates/token-exchange.ts
│   └── tools/
│       ├── <operationId>.ts # one file per OpenAPI operation, generated
│       └── index.ts         # registers every tool above
├── test/
├── package.json             # from templates/package.json
├── tsconfig.json            # from templates/tsconfig.json
├── vitest.config.ts         # from templates/vitest.config.ts
├── Dockerfile               # from templates/Dockerfile
└── README.md
```

| Template | Copy to |
|---|---|
| `templates/package.json` | `package.json` |
| `templates/tsconfig.json` | `tsconfig.json` |
| `templates/vitest.config.ts` | `vitest.config.ts` |
| `templates/server.ts` | `src/server.ts` |
| `templates/token-exchange.ts` | `src/token-exchange.ts` |
| `templates/tool.ts` | `src/tools/<operationId>.ts`, once per operation |
| `templates/Dockerfile` | `Dockerfile` |
| `templates/docker-compose.yml` | the `deployment` repository's `local/compose.yml` |

Every version comes from the `mcp` section of `knowledge/tech-stack.yaml`, unchanged.

## The only input: the OpenAPI documents in the registry

The MCP server is generated from the OpenAPI documents every backend commits to the
`registry` repository:

```text
<workspace>-registry/openapi/<backend>.json
```

The generating agent reads every file in that directory, in manifest order. It does
not read backend controllers, and it does not infer an endpoint that is not in a
document. If a document is missing, the agent stops and reports rather than guessing.

## Tool mapping is mechanical

**One OpenAPI operation becomes one tool.** Every operation in every document, with
no exceptions and no selection.

| From the OpenAPI operation | Becomes |
|---|---|
| `operationId` | the tool name and the file name under `src/tools/` |
| `summary`, `description` | the tool description the calling agent reads |
| path, query and body parameters | the tool's Zod input schema |
| the success response schema | the tool's Zod output schema |
| method and path | the request the tool makes through Nginx |

AI agents must not:

- Choose which operations deserve a tool, or leave one out because it looks
  uninteresting or dangerous. The backend already enforces authorization per
  endpoint; the MCP server does not second-guess it.
- Rename, merge or split operations, or invent a tool with no operation behind it.
- Add a parameter the operation does not have, or drop one it does.

A large system produces a large tool list. That is the accepted cost of removing an
agent judgement call.

## Authentication

Two layers, two standards. They do not mix.

| Hop | Mechanism |
|---|---|
| AI Agent → MCP Server, remote | OAuth 2.1, as the MCP specification requires |
| AI Agent → MCP Server, local | stdio. No OAuth: there is no HTTP layer to carry the flow |
| MCP Server → Backend API | JWT RS256, exactly like every other caller |

The MCP server **holds no signing key**. It calls the backend's token exchange
endpoint, which owns the authentication group's key pair, and receives a JWT RS256
for the end user:

```text
remote:  AI Agent --OAuth 2.1 token--> MCP Server --exchange--> backend auth
                                                                   |
                                              JWT RS256 for that same user
                                                                   v
                                                      Nginx --> Backend API

local:   AI Agent --stdio, no OAuth--> MCP Server --exchange--> backend auth
                                       credential from config's local/
```

The backend sees the real user, not a service account, so its own authorization
rules apply unchanged.

AI agents must not:

- Give the MCP server a private key or an RSA key pair of its own.
- Introduce a new authentication group for the MCP server.
- Let the MCP server mint, forge or extend a token.
- Skip the exchange and forward an OAuth token to the backend. The backend accepts
  JWT RS256 only.

The local credential the MCP server uses for the exchange lives in the `config`
repository under `local/`. It is never hard-coded and never committed as a real
value.

## Definition of done

An MCP release is done when `preflight/done-check.sh --mcp <url>` passes:

1. `mcp-server` is one of the deployed compose services
2. `tools/list` responds
3. one real tool call reaches the backend

There is no screen to click through, so these three take the place of that check.
Running the server on the host during development does not finish the release, for
the same reason a host-run backend does not.

## Must not

- Modify the knowledge files in this directory during normal project generation.
- Change a version pinned in `knowledge/tech-stack.yaml`.
- Use the `latest` Docker tag.
- Add Express, NestJS or any other HTTP framework. The SDK carries its own transport.
- Add a database driver or an ORM.
- Build an MCP server that the human did not ask for.
