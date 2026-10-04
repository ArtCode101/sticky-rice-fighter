// Playwright configuration for web journeys.
//
// Version is pinned in knowledge/tech-stack.yaml. Journeys run against the TEST ZONE,
// where the application runs as a container - never against the develop zone the human
// is clicking through.
//
// Desktop or background mode is the human's answer to the mode question, passed in as
// JOURNEY_MODE. Desktop is the default. A journey that needs someone to click is forced
// to desktop and does not get asked; see knowledge/journey/AGENTS.md.

import { defineConfig, devices } from '@playwright/test';

// 'desktop' shows the browser, 'background' is headless. Default: desktop.
const MODE = process.env.JOURNEY_MODE ?? 'desktop';

export default defineConfig({
  testDir: '.',
  testMatch: '*.spec.ts',

  // A journey is a path, not a unit test: the steps are ordered and the later ones
  // depend on the earlier ones, so a journey file does not run its steps in parallel.
  fullyParallel: false,
  workers: 1,

  use: {
    // The test zone's gateway. Always Nginx, never a backend port.
    baseURL: process.env.JOURNEY_BASE_URL,
    headless: MODE !== 'desktop',
    // Evidence for the run report when a journey fails. Deleted at cleanup, once the
    // run report has recorded what it showed.
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },

  // Journeys run in a desktop browser at a desktop viewport, in both modes. The mode
  // only decides whether the window is visible.
  projects: [{ name: 'desktop-chrome', use: { ...devices['Desktop Chrome'] } }],

  // A journey passes only by running. A failing required journey sends the release
  // into rework (at most 3 rounds), and its retry is the rework round, not a
  // Playwright retry: a journey that passes on the second try still failed once.
  retries: 0,
  reporter: [['list'], ['html', { open: 'never' }]],
});
