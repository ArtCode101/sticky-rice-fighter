# Datastore Tool Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/tools/`

and governs the content of the workspace's `tool` repository.

## The rule that never bends

**An agent reaches PostgreSQL, Kafka and Redis through a Python tool only.**

There is no direct access. To run a query, the agent runs SQL through the database
tool. To put a message on a queue, it goes through the Kafka tool. To read or write
a key, it goes through the Redis tool.

AI agents must not:

- Connect to PostgreSQL, Kafka or Redis from anywhere but these tools.
- Use `psql`, `redis-cli`, `kafka-console-producer`, `docker exec` into a datastore
  container, or any other direct client.
- Embed datastore credentials or ad-hoc connection code in a service repository in
  order to poke at data.

If something cannot be done through the existing tools, the agent extends a tool or
writes a new one in the `tool` repository. It does not go around them.

## Where the tools live

The workspace's `tool` repository, one per workspace, declared in the manifest with
`type: tool`.

```text
<workspace>-tool/
├── db_tool.py
├── kafka_tool.py
├── redis_tool.py
├── requirements.txt        # pinned from knowledge/tech-stack.yaml
└── README.md
```

| Template | Copy to |
|---|---|
| `knowledge/tools/templates/db_tool.py` | `db_tool.py` |
| `knowledge/tools/templates/kafka_tool.py` | `kafka_tool.py` |
| `knowledge/tools/templates/redis_tool.py` | `redis_tool.py` |

Run them on the Python version pinned in `knowledge/tech-stack.yaml`, with the
clients pinned in the same file: `psycopg`, `confluent-kafka` and `redis`.

## Privileges: full, and local only

On the **local** workspace datastores the agent has **full privileges**:

- PostgreSQL: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, DDL, anything.
- Generating and inserting **mock data** to exercise a backend or frontend it just
  built is expressly allowed and expected.
- Kafka: producing messages onto any topic.
- Redis: reading and writing any key.

The scope is **local level only**. Never a dev, sys, staging or production
datastore.

Each tool enforces this itself: it refuses to run when the target host is not
`localhost`, `127.0.0.1`, `::1` or `0.0.0.0`. The grant is broad, but it cannot
reach past the local machine.

The human has been told what this allows — a mistaken script or an unscoped
statement can destroy local data — and **accepts that risk**. No backups, sandboxes
or approval steps are required before an agent writes to a local datastore. This is
a settled decision; do not add guardrails that reintroduce a gate.

## Connection settings

Every tool reads its connection settings from the environment, which mirrors the
workspace's `config` repository under `local/`. No tool hard-codes a host, a port or
a credential.

## Must not

- Modify the knowledge files in this directory during normal project generation.
- Relax the local-host check in any tool.
- Point a tool at a non-local datastore, whatever the reason.
- Add an approval step or confirmation prompt in front of a local write.
