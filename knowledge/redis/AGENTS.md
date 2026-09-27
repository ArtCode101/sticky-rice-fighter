# Redis Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/redis/`

## Purpose

The files in this directory are Redis knowledge and reusable reference templates
for AI agents.

## Docker Compose Usage

File:

`knowledge/redis/templates/docker-compose.yml`

Use this file as the standard Redis Docker Compose reference.

AI agents should:

- Read this file when Redis is required.
- Reuse the Redis configuration from this file.
- Keep the configured Redis version unchanged.
- Use the configured health check, volume, port, and restart policy when applicable.
- Copy or adapt this configuration into the target workspace/project when needed.

AI agents must not:

- Modify this knowledge file during normal project generation.
- Change the Redis version automatically.
- Replace the Redis image with another cache/database image.
- Use the `latest` Docker image tag.
- Store project-specific credentials in this knowledge directory.

## Current Redis Image

```text
redis:8.2
```
