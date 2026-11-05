# Local Run Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/local-run/`

## Purpose

While writing code, an agent may run the system's own processes **directly on the
host**, outside Docker, so it can see the code work immediately.

This is the develop phase. It is deliberately not containerized.

| Runs on the host | Runs in Docker |
|---|---|
| Backend services | PostgreSQL |
| Frontend (Next.js) | Redis |
| Nginx gateway | Kafka |
| Batch jobs | — |
| Listeners | — |
| MCP server, on stdio | — |

The host processes connect to the containerized dependencies from
`knowledge/local-env/`.

## Who does this

The Coding Agent starts and stops these processes itself. It may also spawn helper
agents to do it. No separate agent type owns this, and no approval is needed.

## Configuration

Agents may freely edit the local and test configuration inside each repository to
wire things together:

- the address the frontend calls (always the Nginx address, never a backend port)
- the Nginx upstreams and routes
- the backend's PostgreSQL, Redis and Kafka connection settings, pointing at the
  local environment containers
- the batch and listener connection settings
- the MCP server's gateway address, its token exchange path and the local credential
  it exchanges

The authoritative copies of these values live in the workspace's `config`
repository under `local/`. Keep the two in step: edit freely while developing, then
reflect the settled values back into `config`.

## Ports

Defaults for a single workspace. Every one of them is configurable from the
`config` repository; nothing is hard-coded in application code.

| Process | Port |
|---|---|
| Nginx gateway (**the only address the frontend uses**) | 8000 |
| Frontend dev server | 3000 |
| Backend services | 8080, 8081, 8082, ... in manifest order |
| Batch jobs and listeners, if they expose a port | 8090, 8091, ... |
| MCP server, only when run on Streamable HTTP instead of stdio | 8100 |
| PostgreSQL container | 5432 |
| Redis container | 6379 |
| Kafka container | 9094 |

When a second workspace has to run at the same time, add 100 to every port in that
workspace's `config` and `local-env/.env`. Set the values explicitly: nothing
computes an offset automatically. Any port can still be taken, so check it first, as
the next section says.

## Ports and what is not yours

The machine is shared with whatever else the human runs. This rule applies to every agent
that starts anything on it: a host process, the local environment, the local deploy and
the test zone.

### What is yours

| Kind | It is yours when |
|---|---|
| Host process | It is one of this workspace's processes in the table at the top of this file, and its working directory or command line is inside `${WORKSPACE_PATH}` |
| Container | Its compose project is `$WORKSPACE_NAME`, `$WORKSPACE_NAME-deploy` or `$WORKSPACE_NAME-test` |

Everything else is **not yours**, including anything whose owner cannot be established.
A familiar name, a usual port or the same kind of application does not make it yours.

### Check before starting

Before starting anything that listens on a host port, find out what holds that port. Ask
Docker first, because on macOS `lsof` shows only Docker's own proxy for a container's port.

```bash
docker ps --filter publish=<port> --format '{{.Names}} {{.Label "com.docker.compose.project"}}'
lsof -nP -iTCP:<port> -sTCP:LISTEN -t      # the process id
lsof -a -p <pid> -d cwd -Fn                # its working directory
ps -o command= -p <pid>                    # its command line
```

On Windows, use `netstat -ano | findstr :<port>`, then
`Get-CimInstance Win32_Process -Filter "ProcessId=<pid>"` for its command line.

| The port is | Do this |
|---|---|
| Free | Start. |
| Held by something of yours | Stop it or restart it, without asking. Start again afterwards anything you stopped only to free a port. |
| Held by something not yours | Leave it alone and move your own to a free port. |

Deleting data stays the human's decision whichever way this goes: stopping is allowed,
`local-env.sh destroy` is not.

### Moving to another port

Take the next free port above the default, and change the value where it is defined, so
every caller moves with it:

- the workspace's `config` repository under `local/`, and `local-env/.env`
- the gateway's upstream, when the process sits behind Nginx, under its lock
- the `config` repository's `local-deploy/.env`, for the local deploy
- the `TEST_*_PORT` values, for the test zone

Only the host side of a container's port mapping moves; the port inside the container
stays the same. Tell the human which port changed, because they use these addresses too.

AI agents must not:

- Stop, restart, remove or reconfigure a process or container that is not theirs, to free
  a port or for any other reason.
- Use a command that can reach beyond their own: `killall`, `pkill`,
  `kill $(lsof -t -i :<port>)` before checking the owner, `docker stop $(docker ps -q)`,
  or any `docker ... prune`.
- Prune Docker's networks, images or volumes because Docker ran out of something. That
  covers other people's resources too, so report it to the human.

## Procedures

Frontend, from the frontend repository:

```bash
npm install
npm run dev          # serves on 3000
```

Backend, from a backend repository:

```bash
./mvnw spring-boot:run          # serves on its assigned port
```

MCP server, from the `mcp-server` repository:

```bash
npm install
npm run dev          # speaks stdio; the calling agent launches this command
```

On stdio there is no HTTP layer, so there is no OAuth flow. The server exchanges
`LOCAL_EXCHANGE_CREDENTIAL` from the `config` repository's `local/` for the identity
token at the backend instead. The backend's code path is the same one a deployed caller
takes.

Nginx, from the workspace:

```bash
nginx -p ${WORKSPACE_PATH}/local-env/nginx -c nginx.conf
nginx -p ${WORKSPACE_PATH}/local-env/nginx -c nginx.conf -s reload   # after editing
nginx -p ${WORKSPACE_PATH}/local-env/nginx -c nginx.conf -s stop
```

Start order: local environment containers, then backends, then Nginx, then the
frontend, then the MCP server. Nginx fails to proxy until its upstreams are
listening, and the MCP server fails its token exchange until Nginx is up.

## This is not the definition of done

A release is **not** done because it runs this way.

| | Local run (this file) | Definition of done |
|---|---|---|
| Backend | host process | Docker container |
| Frontend | host process, `next dev` on Node.js | Docker container, a static export with no Node.js (`knowledge/frontend/AGENTS.md`) |
| Nginx | host process | Docker container |
| MCP server | host process, stdio | Docker container, Streamable HTTP |
| Purpose | see the code work while writing it | finish the release |
| Verified by | the agent looking at it | `preflight/done-check.sh` |

Only a deploy from the `deployment` repository onto the local Docker host, verified
by `preflight/done-check.sh`, finishes a release.

## Must not

- Point the frontend or the MCP server at a backend port. Everything goes through
  Nginx.
- Claim a release is done because the host processes run.
- Modify the knowledge files in this directory during normal project generation.
- Leave a port hard-coded in application code instead of reading it from config.
