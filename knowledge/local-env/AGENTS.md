# Local Environment Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/local-env/`

## Purpose

The local environment is the set of dependency containers a workspace needs while
its code is being written: PostgreSQL, Redis and Kafka. Agents start it themselves
so they can develop against something real.

This capability is **not owned by a specific agent**. Any agent that needs a
dependency while working may provision and start it. There is no approval step and
no gate.

## Provisioning

```text
${WORKSPACE_PATH}/local-env/
├── local-env.sh       # from knowledge/local-env/templates/local-env.sh
├── .env               # from knowledge/local-env/templates/env.example
├── postgres.yml       # from knowledge/database/templates/docker-compose.yml
├── redis.yml          # from knowledge/redis/templates/docker-compose.yml
└── kafka.yml          # from knowledge/kafka/templates/docker-compose.yml
```

Procedure:

1. Create `${WORKSPACE_PATH}/local-env/`.
2. Copy `local-env.sh` and `env.example` (to `.env`) from this knowledge directory.
3. Copy **only the dependencies the project actually needs** from the
   infrastructure knowledge templates, renaming each to `<service>.yml`.
4. Fill in `.env`. `WORKSPACE_NAME` is required. Mirror the values into the
   workspace's `config` repository under `local/`, which stays the authoritative
   copy.
5. `./local-env.sh up`

## Lifecycle

| Command | Effect |
|---|---|
| `local-env.sh up [service...]` | Start services. Default: every compose file present. |
| `local-env.sh down [service...]` | Stop containers. **Named volumes are kept, so data survives.** |
| `local-env.sh destroy --yes` | Stop containers and delete every volume. Requires the explicit flag. |
| `local-env.sh status` | Show what is running. |

Rules:

- The local environment **stays up across releases**. It is the workspace's
  environment, not a per-release resource, so nothing tears it down when a release
  locks.
- Only the human decides to stop or destroy it. An agent may run `up` and `status`
  freely; it must not run `destroy` unless the human asked for it.
- Data persists through `down`. `destroy` is the only command that deletes data.

## Isolation

Every command runs as `docker compose -p "$WORKSPACE_NAME"`, so containers,
networks and volumes are namespaced per workspace.

AI agents must not:

- Reuse a container, network or volume belonging to another workspace.
- Start a dependency outside this mechanism, so that nothing escapes the
  workspace's compose project.
- Modify the knowledge files in this directory during normal project generation.
- Run `destroy` on their own initiative.

## Relationship to the definition of done

The local environment is **development scaffolding, not the definition of done**.

- Here: dependency containers, plus backend, frontend and Nginx running as host
  processes (see `knowledge/nginx/`). This is the develop phase.
- Definition of done: the whole system deployed on the local Docker host from the
  `deployment` repository and verified with `preflight/done-check.sh`.

Getting the local environment running never counts as finishing a release.
