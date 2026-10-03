# Config Repository Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/config/`

and governs the content of the workspace's `config` repository.

## Purpose

The `config` repository holds the configuration for every part of the system:
backend services, frontend applications and deployment. The `deployment`
repository reads from it at deploy time. It is the single place a value is defined,
so no value is duplicated across repositories.

It is created empty in phase 1 and filled in as releases need it.

## Layout

```text
<workspace>-config/
├── local/
│   ├── .env.example       # every key the local deploy needs, with safe defaults
│   └── <repo>/            # per-repository configuration, if a repo needs its own
├── environments/
│   ├── dev/
│   │   └── .env.example
│   └── sys/
│       └── .env.example
├── keys/
│   └── README.md          # how key pairs are laid out; never the keys themselves
└── README.md
```

- One directory per environment. `local/` is the one the definition of done uses.
- `.env.example` is committed. The real `.env` is git-ignored and never committed.

## Authentication keys

Each authentication group has its own RS256 key pair, as decided by the
Requirement Analysis Agent.

- Key pairs are generated per authentication group. Two groups never share one.
- A user group that does not authenticate has no key pair.
- Private keys are **never** committed to any repository. `keys/README.md` records
  which groups exist, the expected file names and how to generate them; the key
  material itself stays out of git.
- Public keys may be committed if a service needs them to verify tokens.

Generate a pair with:

```bash
openssl genrsa -out <group>-private.pem 2048
openssl rsa -in <group>-private.pem -pubout -out <group>-public.pem
```

## The MCP server's local credential

When the workspace has an `mcp-server`, the develop phase runs it on stdio, where
there is no HTTP layer and therefore no OAuth flow. It exchanges a local credential
for a JWT RS256 at the backend instead.

That credential is a configuration value like any other:

- It lives under `local/` as `LOCAL_EXCHANGE_CREDENTIAL`, with a placeholder in
  `local/.env.example` and the real value only in the git-ignored `.env`.
- The gateway address and the token exchange path live beside it: `GATEWAY_URL` is
  always the Nginx address, never a backend port, and `TOKEN_EXCHANGE_PATH` names the
  backend endpoint.
- Deployed, there is no such credential: the caller arrives with an OAuth 2.1 token
  and that is what gets exchanged.

The MCP server never has a private key or an RSA key pair of its own. It is not an
authentication group. See `knowledge/mcp/AGENTS.md`.

## Mobile configuration is embedded at build time

A mobile app cannot read configuration at runtime the way a server can: it is built into
a file and installed on a device.

- Values still live here, once, per environment, like everything else.
- At **build time** the mobile build pulls that environment's values and embeds them, so
  there is one build per environment.
- **Only public values.** The gateway URL and the like. A user can unpack an installed
  app and read every embedded value, so nothing secret goes into one — no client secret,
  no private key, no datastore credential. Those stay on the backend.

See `knowledge/mobile/AGENTS.md`.

## Rules

AI agents should:

- Define every configurable value here, once.
- Keep `.env.example` complete: every key the deploy needs, with a safe default or
  an explicit placeholder.
- Use the versions pinned in `knowledge/tech-stack.yaml` when a config value names
  a version.

AI agents must not:

- Modify the knowledge files in this directory during normal project generation.
- Commit a real `.env`, a private key, a password or any other secret.
- Duplicate a configuration value into a backend, frontend or deployment
  repository.
