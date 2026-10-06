# Notes — recorded, not built

**Nothing in this file is implemented, and no agent may start building from it.**

This is where an idea is written down so it is not lost, after the human decided
*not* to build it yet. A note here is not a backlog item waiting to be picked up, not
a hint, and not permission. It is a record of a conversation.

If an agent reads a note here and starts work, the note has failed at its only job.

Rules:

- No agent creates, edits or removes anything in this file. The human does.
- No agent treats a note as a requirement, a spec or a definition of done.
- When the human decides to build one of these, it stops being a note: it becomes a
  requirement, goes through the Requirement Analysis Agent, and its rules land in
  `knowledge/`.

---

## Quality and change control

Raised 2026-09-28. The human's words: note it, do not build it, "I want to study it
more first".

The three the human picked as most useful, in that order:

1. **Traceability** — each requirement traceable to the API, table, test and file it
   produced, so changing a requirement shows its blast radius.
2. **Impact analyzer / change planner** — asked to add a field, the framework answers
   *what this touches* instead of regenerating the system.
3. **Verification gate** — before claiming done: build passes, tests pass, the API
   spec matches the implementation, migrations run, the frontend reaches real
   endpoints.

> ⚠ **The verification gate contradicts this framework's core design.**
> `agents/AGENTS.md` states that any rule of the form "prove this is complete before
> continuing" is what produces the loop this framework exists to avoid, and must not
> be added. Building it would be a deliberate reversal of that decision, not an
> incremental feature. Whoever picks this up decides that question first.

The rest, recorded without an order:

- **Spec / contract registry** — one source of truth for the current API, database
  schema, events, permissions and business rules, so frontend, backend and tests never
  read different versions. Partly answered already: as of release 3 each backend
  publishes an OpenAPI document to `registry/openapi/`, which is the contract the MCP
  server is built from. A full registry would cover schema, events and permissions too.
- **Recovery and rollback** — return to the checkpoint before an agent broke
  something, know which step failed, and retry that step instead of starting over.
- **Environment generator** — generate `local` / SIT / UAT / PROD configuration,
  compose files, `.env.example`, migrations and seeds to one standard.
- **Observability generator** — logging, metrics, tracing, health checks and
  correlation IDs present from the first release rather than added later.
- **Security baseline** — auth, authorization, secret handling, input validation,
  rate limits, dependency scanning and security headers as framework defaults instead
  of a per-project decision.
- **Documentation generator** — architecture, API usage, runbook, deployment guide and
  onboarding generated from the same source as the code.
- **Project capability manifest** — a `capabilities.yaml` per project stating what the
  system can do, feeding the MCP generator, the test generator and the documentation
  generator from one place.

### The speed concern, and the answer given

The human asked whether traceability, impact analysis and verification would slow the
fast feedback loop down. They would, if all three ran on every cycle. The recorded
answer:

- Split a **fast loop** from a **deep verification** pass.
- Run traceability and impact analysis **incrementally**, on the diff only.
- Save the deep pass for the end of a feature, before a merge or before a deploy.

Anyone building these starts from that split, not from bolting three checks onto every
iteration.

## Authentication details left open

Raised 2026-10-03 while deciding the login patterns. Each was explicitly put off, not
forgotten.

- **Where key material lives.** The human asked for a recommendation but said "no need
  to decide this now". What *is* decided: RS256 with a key pair, a separate pair per
  environment, and private keys never committed. Where the pair is stored is open.
- **Token lifetime and refresh.** How long an access token lasts and whether there is a
  refresh token. The human's words: "park it for now".
- **Key rotation.** How a key pair is replaced without invalidating every live token at
  once. Deferred with the item above.

Until these are decided, a system is built with a key pair per environment and tokens
that work; nothing here blocks a release.

## Journey details left open

Raised by the assistant while the journey rules were being settled, and never answered.
These are gaps in the rules as written, not features:

- **Preconditions as a formal field.** A journey document states its starting state in
  prose. It is not formally tied to a named mock-data set, so nothing mechanically
  guarantees a journey and its data stay in step.
- **Journeys that are not the happy path.** Everything decided describes the path that
  succeeds. A wrong password or an incomplete form has no place in the journey document
  yet.
- **What happens to a journey when the system changes.** If a new feature changes an
  existing step, the old journey is either rewritten or dropped, and nothing says who
  decides which.

## Mobile, second tier

Raised 2026-10-03 and set aside by the human as "secondary":

- **Internationalization**, if an app has to support more than one language.
- **Error tracking**, Sentry or similar.

## Code index and code graph

Raised 2026-09-28. Noted, not built: "let me go study it first".

The idea: give agents a symbol-level index so they can ask *what calls this, what
implements this, where is it referenced* before or while editing, instead of loading
the repository into context.

- **SCIP** as the index format, with existing indexers per language rather than
  anything written here, optionally with Sourcegraph on top.
- It fits fast feedback: the agent queries the index and pulls in only the relevant
  code.
- It is also the natural foundation for the impact analyzer above. If both get built,
  this one comes first.
