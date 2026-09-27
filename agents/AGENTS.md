# Agent Rules

## Scope

This file applies to all files under:

`agents/`

## Agents

| Agent | Definition | Human gate |
|---|---|---|
| Workspace Init Agent | `agents/workspace-init-agent.md` | no |
| Requirement Analysis Agent | `agents/requirement-analysis-agent.md` | **yes** |
| Coding Agent | `agents/coding-agent.md` | no |

There is deliberately no QA agent and no reviewer agent. Adding one reintroduces
the loop this framework exists to avoid.

## Flow

```text
raw requirement
      |
      v
Requirement Analysis Agent  --->  human approves  (the only gate)
      |
      v
Workspace Init Agent        --->  creates phase 2 repositories
      |
      v
Coding Agent x N            --->  one per repository, in parallel
      |
      v
release runs on local Docker host  --->  release is locked
      |
      v
flag.yml release_execution:  manual -> wait for human
                             auto   -> next release
```

## Gates

The framework has exactly two checkpoints:

1. The human approves the Requirement Analysis Agent's output, once, before any
   code is written.
2. A release deploys and runs on the local Docker host and can be clicked through.

No agent has its own completion gate. No agent judges whether its own work is good
enough. Any rule of the form "prove this is complete before continuing" is what
produces the loop this framework is built to avoid, and must not be added.

## Concurrency

- One repository is owned by exactly one agent at a time. Two agents must never
  write product code to the same repository.
- Agents working on different repositories run in parallel.
- The number of coding agents for a release equals the number of repositories that
  release touches, as decided by the Requirement Analysis Agent.
- A Coding Agent may spawn helper agents, for example to start and watch a local
  process. A helper inherits its parent's boundaries and does not become a second
  writer for the parent's repository.

## Priority

A newer release always wins over an earlier one. Overlapping or contradicting code
is overwritten, not reconciled. Defects surface when the human clicks through the
running system and come back as a `type: change` release.

## Shared rules

Every agent must:

- Read `flag.yml` before writing, and never write inside the framework repository
  while `mode: working`.
- Never write `flag.yml`, in either mode.
- Write only inside `WORKSPACE_PATH`, and within it only where its own definition
  says it may. Product code goes in the one repository it was assigned; the
  supporting paths each agent may also touch are listed in its definition.
- Reach PostgreSQL, Kafka and Redis only through the Python tools in the `tool`
  repository, against a local host.
- Route frontend-to-backend traffic through Nginx only.
- Produce all output in English.
- Stop and report to the human rather than working around a rule in this file.
