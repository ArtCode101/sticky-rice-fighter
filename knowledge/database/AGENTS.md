# Database Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/database/`

## Purpose

The files in this directory are database knowledge and reusable reference templates
for AI agents.

## Docker Compose Usage

File:

`knowledge/database/templates/docker-compose.yml`

Use this file as the standard PostgreSQL Docker Compose reference.

AI agents should:

- Read this file when PostgreSQL is required.
- Reuse the PostgreSQL configuration from this file.
- Keep the configured PostgreSQL version unchanged.
- Use the configured health check, volume, port, and restart policy when applicable.
- Copy or adapt this configuration into the target workspace/project when needed.

AI agents must not:

- Modify this knowledge file during normal project generation.
- Change the PostgreSQL version automatically.
- Replace the PostgreSQL image with another database image.
- Use the `latest` Docker image tag.
- Store project-specific credentials in this knowledge directory.

## Current PostgreSQL Image

```text
postgres:16.15