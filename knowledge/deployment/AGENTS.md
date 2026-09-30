# Deployment Repository Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/deployment/`

and governs the content of the workspace's `deployment` repository.

## Purpose

The `deployment` repository holds every script that deploys the system. It owns no
application code and no configuration values of its own: it reads configuration
from the workspace's `config` repository at deploy time.

It is created empty in phase 1 and filled in as releases need it.

## Layout

```text
<workspace>-deployment/
├── local/
│   ├── deploy.sh          # deploy to the local Docker host
│   └── compose.yml        # composed from the knowledge templates
├── environments/
│   ├── dev/
│   │   └── deploy.sh
│   └── sys/
│       └── deploy.sh
└── README.md
```

- `local/` deploys to the developer's own Docker host. This is the target the
  definition of done is measured against.
- `environments/<env>/` deploys to a real environment. Separate concern, separate
  scripts, never required by the definition of done.

## Templates

| Template | Copy to |
|---|---|
| `knowledge/deployment/templates/deploy-local.sh` | `local/deploy.sh` |

Infrastructure services in `local/compose.yml` come from the infrastructure
knowledge templates, not from scratch:

- `knowledge/database/templates/docker-compose.yml`
- `knowledge/redis/templates/docker-compose.yml`
- `knowledge/kafka/templates/docker-compose.yml`
- `knowledge/nginx/templates/docker-compose.yml`
- `knowledge/mcp/templates/docker-compose.yml`, only when the workspace has an
  `mcp-server`

The Nginx service is required whenever the release has both a frontend and a
backend: every caller reaches the backend through Nginx only. Unlike the develop
phase, where Nginx runs as a host process, here it is a container like the rest, and
its upstreams are compose service names.

The MCP service is included only when `workspace.mcp_server` is `true`. Deployed, it
is a container speaking Streamable HTTP, unlike the develop phase where it is a host
process on stdio. It reaches the backend through the `nginx` service and has no
datastore connection of any kind.

AI agents should:

- Reuse those templates as-is, keeping the pinned image versions, health checks,
  volumes, ports and restart policies.
- Read every configuration value from the `config` repository.
- Verify a local deploy with `preflight/done-check.sh`, passing
  `--gateway <url>` whenever the release has a frontend.

AI agents must not:

- Modify the knowledge files in this directory during normal project generation.
- Hard-code configuration values or credentials into a deploy script.
- Change a pinned image version, or use a `latest` Docker tag.
- Treat a real-environment deploy as part of a release's definition of done.
