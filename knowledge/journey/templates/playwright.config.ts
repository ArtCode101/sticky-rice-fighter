// Playwright configuration for web journeys.
//
// Version is pinned in knowledge/tech-stack.yaml. Journeys run against the TEST ZONE,
// where the application runs as a container - never against the develop zone the human
// is clicking through.
//
// Desktop or background mode is the human's answer to the mode question, passed in as
// JOURNEY_MODE. A journey that needs someone to click is forced to desktop and does not
// get asked; see knowledge/journey/AGENTS.md.

import { defineConfig } from '@playwright/test';

// 'desktop' shows the browser, 'background' is headless.
const MODE = process.env.JOURNEY_MODE ?? 'background';

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
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },

  // A failing journey reports. It does not gate a release: a failure becomes a
  // type: change release, like any defect found by clicking.
  reporter: [['list'], ['html', { open: 'never' }]],
});
