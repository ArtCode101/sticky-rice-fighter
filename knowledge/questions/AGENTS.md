# Question Protocol Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/questions/`

and governs **every** question any agent asks the human, anywhere in the framework.

## Purpose

A requirement is never complete. Agents will always reach a point where they need the
human to decide something. This file defines the one shape that question takes.

Before this existed, the human had to type the instruction into every requirement to
get a usable question, and without it they got a wall of prose containing ten or
twenty questions at once, which has to be sorted out before any of it can be answered.

## The shape of a question

Every question an agent asks follows this form:

```text
<the question, one sentence>

  1. <option>            — <one line: what this means or what happens>
  2. <option>            — <one line>  [recommended]
  3. <option>            — <one line>
  4. Something else      — type your answer

Pick a number, or type your own answer.
```

Rules:

- **Numbered options.** The human answers with a number. Never a paragraph that
  expects them to work out what the choices were.
- **Always a free-text slot**, as the last option. A human whose answer is not on the
  list must be able to say so without fighting the format.
- **Two options minimum.** A question with one option is not a question; make the
  decision and say what was decided.
- **One line per option** saying what it means or what follows from it. An option the
  human cannot evaluate is not an option.
- **Mark the recommended option** when there is a clear best one, and only then. See
  **Recommendations** below.

## Read before asking

A question is asked only when the human has not already answered it. Before asking
anything, the agent reads what the human has already given it: a requirement file
passed on the command line, a requirement in the workspace, a mockup. If the answer is
**stated** there, the agent records it as the human's answer and does not ask.

The test is *stated*, not *implied*:

| What the material says | What the agent does |
|---|---|
| "The system needs an MCP server so our support bot can drive it." | `mcp_server: true`, no question. |
| "Everything in one git repository." | `repo_layout: mono`, no question. |
| "Users sign in with Google." | login method Google, no question. |
| Nothing about an MCP server | ask. |
| "There may be an AI integration later." | ask. Later is not an answer. |
| A diagram that happens to show one repository | ask. A picture of a layout is not a decision about git. |

Rules:

- **An explicit statement is an answer.** It has the same standing as the human typing
  it in reply to the question. It is recorded the same way, in the same file, and the
  agent says in its report which answers came from the material and where.
- **Anything less is not an answer.** A hint, a default the agent would pick, something
  the agent would recommend, a statement that contradicts itself: ask. Reading before
  asking removes questions whose answer is already written down; it never becomes a way
  to skip a question.
- **The material does not replace the question's format.** When the agent does ask, it
  asks in the shape above, whatever the material looked like.
- **This holds in both modes.** `auto_recommend` below decides what happens to a
  question that has a recommended option. A question already answered in the material
  is not asked in either mode, and a question the material does not answer follows the
  mode's own rule.

Where a skill names a question in its definition, that skill says which file the
answer lands in. The Workspace Init Agent's three questions land in `workspace.yaml`;
the Requirement Analysis Agent's land in the release specifications.

## One decision at a time

**Ask one question. Wait for the answer. Then ask the next.**

AI agents must not:

- Send several questions in one message.
- Send a numbered list of questions, each with its own options.
- Summarize a batch of open decisions and ask the human to work through them.

This is the failure the protocol exists to fix. Ten questions at once is not ten times
as efficient; it is a document the human now has to project-manage. If there are ten
decisions, ask the first one.

Order the questions so that the answer to one can remove the need for another. A
question whose answer no longer matters is not asked.

## Recommendations

An option is marked `[recommended]` when the agent can defend it as the best choice
for this situation, with the reason stated in its one-line description.

- **At most one** option per question is marked.
- A question where no option is better than the others carries **no** recommendation.
  Say so plainly rather than inventing one to look decisive.
- A recommendation is not a default that gets applied silently. Outside auto-recommend
  mode the human still answers.

## Auto-recommend mode

`workspace.auto_recommend` in `${WORKSPACE_PATH}/workspace.yaml` records, once, whether
the human has allowed agents to take the recommended option without asking.

| Value | Behavior |
|---|---|
| `false` | Every question is asked. This is the default when the human does not answer. |
| `true` | A question whose option set has a `[recommended]` option is **not** asked. The agent takes that option, records the choice, and continues. |

The hard floor, which `true` never overrides:

- **A question with no recommended option is always asked**, in either mode. If the
  agent genuinely cannot pick a best option, auto mode has nothing to apply, and
  guessing is not a substitute.
- An agent must not invent a recommendation in order to avoid asking. If the only
  reason an option is marked is that auto mode would otherwise stop, the mark is wrong.

When an agent takes an option automatically it says which option it took and why, in
its report. Auto mode removes the interruption, not the record.

## Questions are inputs, not gates

A question collects a parameter the agent needs in order to work. It is not a
checkpoint, nothing is being approved, and no agent judges another's output through
one.

The framework has exactly two checkpoints, listed in `knowledge/flow/AGENTS.md`, and this file
adds none. An agent must never use a question to hold work for review, to ask whether
its own output is good enough, or to ask permission to continue with something it is
already allowed to do.

## Must not

- Ask more than one question at a time.
- Ask a question the human has already answered in the material they gave, or treat a
  hint in that material as an answer. See **Read before asking**.
- Omit the free-text option.
- Mark more than one option as recommended.
- Apply a recommendation in `auto_recommend: false`.
- Skip a question that has no recommended option, in either mode.
- Modify the knowledge files in this directory during normal project generation.
- Write `workspace.auto_recommend`. Only the Workspace Init Agent writes it, once,
  from the human's answer.
