#!/usr/bin/env node
// Installs the srf Claude Code plugin: adds the marketplace, then installs the plugin.
// The framework itself is served from the GitHub repository, not from this package.
// `preflight` runs the installed plugin's machine readiness check.

const { spawnSync } = require("node:child_process");
const { readFileSync, existsSync } = require("node:fs");
const { join } = require("node:path");
const { homedir } = require("node:os");

const MARKETPLACE = "ArtCode101/sticky-rice-fighter";
const PLUGIN = "srf@sticky-rice-fighter";
const WINDOWS = process.platform === "win32";

function claude(args) {
  return spawnSync("claude", args, { stdio: "inherit", shell: WINDOWS });
}

if (process.argv.includes("--help") || process.argv.includes("-h")) {
  console.log(`Usage: npx sticky-rice-fighter [update|preflight]

  (none)     add the marketplace and install the srf plugin (user scope)
  update     update the installed srf plugin
  preflight  check that this machine is ready: Java 25, Node.js 24 with npm,
             Docker and Python 3.13 (the same check /srf:init runs first)`);
  process.exit(0);
}

const probe = spawnSync("claude", ["--version"], { stdio: "ignore", shell: WINDOWS });
if (probe.status !== 0) {
  console.error("Claude Code was not found on PATH. Install it first: https://claude.com/claude-code");
  process.exit(1);
}

// Where Claude Code put the installed plugin. The framework is not in this package,
// so the readiness check has to be run from the installed copy.
function installedPluginRoot() {
  const configDir = process.env.CLAUDE_CONFIG_DIR || join(homedir(), ".claude");
  const registry = join(configDir, "plugins", "installed_plugins.json");
  if (!existsSync(registry)) return null;
  let entries;
  try {
    entries = JSON.parse(readFileSync(registry, "utf8")).plugins?.[PLUGIN];
  } catch {
    return null;
  }
  if (!Array.isArray(entries)) return null;
  const found = entries.find((e) => e.installPath && existsSync(e.installPath));
  return found ? found.installPath : null;
}

function preflight() {
  const root = installedPluginRoot();
  if (!root) {
    console.error(`The srf plugin is not installed. Run: npx sticky-rice-fighter`);
    process.exit(1);
  }
  // checker.sh runs under Git Bash on Windows too, and finds the real Python there.
  // checker.bat is the fallback for a Windows machine without Bash.
  const sh = join(root, "preflight", "checker.sh");
  const bat = join(root, "preflight", "checker.bat");
  const hasBash = spawnSync("bash", ["--version"], { stdio: "ignore", shell: WINDOWS }).status === 0;
  const result = hasBash
    ? spawnSync("bash", [sh], { stdio: "inherit" })
    : WINDOWS
      ? spawnSync("cmd.exe", ["/c", bat], { stdio: "inherit" })
      : null;
  if (!result) {
    console.error("bash was not found on PATH, and checker.bat runs on Windows only.");
    process.exit(1);
  }
  process.exit(result.status ?? 1);
}

if (process.argv.includes("preflight")) {
  preflight();
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
  npx sticky-rice-fighter preflight   # is this machine ready to build?
  mkdir my-workspace && cd my-workspace
  claude
Then run /srf:init, /srf:analyze and /srf:release inside Claude Code.`);
