import { defineConfig } from 'vitest/config';

// The MCP server has no datastore and no framework, so there is nothing to spin up
// here. Tests exercise the tool schemas and the request each tool builds.
export default defineConfig({
  test: {
    environment: 'node',
    include: ['test/**/*.test.ts'],
  },
});
