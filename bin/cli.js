#!/usr/bin/env node
// Installs the srf Claude Code plugin: adds the marketplace, then installs the plugin.
// The framework itself is served from the GitHub repository, not from this package.

const { spawnSync } = require("node:child_process");

const MARKETPLACE = "ArtCode101/sticky-rice-fighter";
const PLUGIN = "srf@sticky-rice-fighter";

function claude(args) {
  return spawnSync("claude", args, { stdio: "inherit", shell: process.platform === "win32" });
}

if (process.argv.includes("--help") || process.argv.includes("-h")) {
  console.log(`Usage: npx sticky-rice-fighter [update]

  (none)   add the marketplace and install the srf plugin (user scope)
  update   update the installed srf plugin`);
  process.exit(0);
}

const probe =spawnSync("claude", ["--version"], { stdio: "ignore", shell: process.platform === "win32" });
if (probe.status !== 0) {
  console.error("Claude Code was not found on PATH. Install it first: https://claude.com/claude-code");
  process.exit(1);
}

const update = process.argv.includes("update");

const steps = update
  ? [["plugin", "update", PLUGIN]]
  : [
      ["plugin", "marketplace", "add", MARKETPLACE],
      ["plugin", "install", PLUGIN, "--scope", "user"],
    ];

for (const step of steps) {
  const result = claude(step);
  if (result.status !== 0) {
    console.error(`Failed: claude ${step.join(" ")}`);
    process.exit(result.status || 1);
  }
}

console.log(`
srf is ready. Next:
  mkdir my-workspace && cd my-workspace
  claude
Then run /srf:init, /srf:analyze and /srf:release inside Claude Code.`);
