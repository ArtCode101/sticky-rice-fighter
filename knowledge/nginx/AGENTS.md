# Nginx Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/nginx/`

## Purpose

Nginx is the gateway between the frontend and the backends. It exists in every
workspace that has both.

## The rule that never bends

**The frontend calls the backend through Nginx only.**

A frontend never calls a backend service directly, not in development and not in a
deployed system. Every call goes to Nginx, which routes it to the right backend.

AI agents must not:

- Point a frontend at a backend port directly.
- Bypass Nginx "just for local development".
- Remove or reroute an existing backend upstream to work around a problem.

When a backend repository is added to the workspace, its upstream and its route are
added to the Nginx configuration in the same change.

## Two runtime shapes

Nginx runs in two different shapes depending on the phase, and they are not
interchangeable.

| Phase | Shape | Configuration |
|---|---|---|
| Development | **Host process.** Nginx runs directly on the machine, alongside the host-run backends and frontend. This phase is not counted as Docker. | `templates/nginx.dev.conf` |
| Definition of done | **Docker container.** Nginx is a service in the deployment compose file, like any other. | `templates/docker-compose.yml` |

The development shape proxies to `127.0.0.1:<port>` because the backends are host
processes. The container shape proxies to compose service names because everything
runs inside the compose network. Do not copy one form of upstream into the other.

## Template usage

| Template | Copy to | Used in |
|---|---|---|
| `templates/nginx.dev.conf` | `${WORKSPACE_PATH}/local-env/nginx/nginx.conf` | development |
| `templates/docker-compose.yml` | the `deployment` repository's `local/compose.yml` | definition of done |

AI agents should:

- Keep the pinned Nginx version unchanged.
- Add one `upstream` block and one `location` per backend repository.
- Read ports from the workspace's `config` repository, never hard-code them.

AI agents must not:

- Modify the knowledge files in this directory during normal project generation.
- Use the `latest` Docker image tag.
- Change the pinned version.

## Current Nginx version

```text
nginx:1.30.5
```

Stable branch. Pinned in `knowledge/tech-stack.yaml`.
