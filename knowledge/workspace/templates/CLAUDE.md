# <workspace-name>

This workspace is built by the **sticky-rice-fighter** framework, installed as the
`srf` Claude Code plugin. Open Claude Code in this directory to work on it. The
framework itself lives in the plugin and is never edited from here.

## Driving the framework

| Skill | When | What it does |
|---|---|---|
| `/srf:preflight` | any time | checks that this machine is ready to build, and changes nothing |
| `/srf:init [requirement file]` | once, at the start | reads the requirement file if given, asks only the questions it does not answer, writes `workspace.yaml`, creates the phase 1 repositories |
| `/srf:analyze <requirement>` | for every new requirement | turns it into releases and screen specifications, then waits for your approval |
| `/srf:release` | after an approval | asks desktop or background mode for the journeys, then runs the next `draft` release until it is deployed, its journeys pass, and it locks |
| `/srf:journey-mode [desktop \| background \| ask]` | any time | sets how journeys run: a visible browser, headless, or ask at every `/srf:release` |

Raw requirements may be written in any language. Everything the framework produces
is in English.

## Rules every agent follows here

Each rule's home is a file in the framework; the skills read those files. This list
exists so the rules apply from the first message of every session.

- **`WORKSPACE_PATH` is this directory.** Every write lands inside it, and within it
  only where the agent's own definition allows. Nothing is written inside the
  framework.
- **One repository, one writer.** Shared files under `local-env/`, the `deployment`
  and `config` repositories' `local/` and the `tool` repository are written under the
  `mkdir` lock in `.locks/`.
- **Two checkpoints only.** You approve the requirement analysis; a release locks when
  `done-check.sh` and `journey-check.sh` pass. No agent reviews another's work.
- **Questions come one at a time**, as numbered options with a free-text slot last,
  and only for what you have not already written down: a stated answer in your
  requirement is taken as yours, a hint is still asked.
- **`workspace.yaml` is the memory.** `repo_layout`, `mcp_server`, `auto_recommend` and
  `release_execution` are read from it, never asked again. `release_execution` is
  yours to flip between `manual` and `auto`, and `journey_mode` yours to set with
  `/srf:journey-mode`.
- **Datastores only through the Python tools** in the `tool` repository; **backends
  only through Nginx**.
