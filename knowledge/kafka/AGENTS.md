# Kafka Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/kafka/`

## Purpose

The files in this directory are Kafka knowledge and reusable reference templates
for AI agents.

## Docker Compose Usage

File:

`knowledge/kafka/templates/docker-compose.yml`

Use this file as the standard Kafka Docker Compose reference.
Kafka 4.x runs in KRaft mode (no ZooKeeper is required or used).

AI agents should:

- Read this file when Kafka is required.
- Reuse the Kafka configuration from this file.
- Keep the configured Kafka version unchanged.
- Use the configured health check, volume, port, and restart policy when applicable.
- Copy or adapt this configuration into the target workspace/project when needed.

AI agents must not:

- Modify this knowledge file during normal project generation.
- Change the Kafka version automatically.
- Add a ZooKeeper service back in.
- Use the `latest` Docker image tag.
- Store project-specific credentials in this knowledge directory.

## Current Kafka Image

```text
apache/kafka:4.0.0
```
