#!/usr/bin/env node
// guard-framework.js - PreToolUse hook: the framework is read-only wherever it is
// installed.
//
// Blocks Edit, Write and NotebookEdit when the target file lies inside the plugin
// root (the framework), unless Claude Code was opened in the framework itself or a
// folder inside it - which is the framework author. A project that merely contains the
// framework, such as its parent folder, gets no exception.
//
// Exit codes, per the Claude Code hooks contract:
//   0 - not a framework file: the call continues through normal permissions
//   2 - a framework file: the call is blocked and stderr is shown to the agent
//
// Node is used rather than bash so the hook runs the same on Windows (where plugin
// hooks fall back to PowerShell) and on macOS or Linux.
"use strict";

const path = require("path");

function normalize(p) {
  const resolved = path.resolve(p);
  return process.platform === "win32" ? resolved.toLowerCase() : resolved;
}

function isInside(target, root) {
  const rel = path.relative(normalize(root), normalize(target));
  return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => { raw += chunk; });
process.stdin.on("end", () => {
  let input = {};
  try { input = JSON.parse(raw || "{}"); } catch (_) { process.exit(0); }

  const toolInput = input.tool_input || {};
  const filePath = toolInput.file_path || toolInput.notebook_path || toolInput.path;
  if (!filePath) process.exit(0);

  const cwd = input.cwd || process.cwd();
  const target = path.resolve(cwd, filePath);
  const frameworkRoot = process.env.CLAUDE_PLUGIN_ROOT || path.join(__dirname, "..");
  const projectDir = process.env.CLAUDE_PROJECT_DIR || cwd;

  // The framework author, working in the framework repository itself.
  if (isInside(projectDir, frameworkRoot)) process.exit(0);

  if (isInside(target, frameworkRoot)) {
    process.stderr.write(
      `sticky-rice-fighter: ${filePath} is inside the framework (${frameworkRoot}). ` +
      "The framework is read-only; agents write only inside the workspace. " +
      "Stop and report this to the human instead of working around it.\n"
    );
    process.exit(2);
  }
  process.exit(0);
});
