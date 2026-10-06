// MCP server entry point.
//
// This file is the fixed part of the server. Nothing system-specific belongs here:
// the tools are generated one file per OpenAPI operation under src/tools/ and
// registered through src/tools/index.ts.
//
// Flow, which never bends:
//   AI Agent -> MCP Client -> MCP Server -> Nginx -> Backend API -> Database
//
// This server never opens a database, Kafka or Redis connection. It calls the
// backend API through Nginx and nothing else.

import { McpServer } from '@modelcontextprotocol/server';
import { StdioServerTransport } from '@modelcontextprotocol/server/stdio';
import { StreamableHttpServerTransport } from '@modelcontextprotocol/server/streamable-http';
import { z } from 'zod';

import { registerTools } from './tools/index.js';

// Every value comes from the environment, which the config repository fills in.
// Nothing here is hard-coded: not the gateway address, not a credential.
const Config = z.object({
  // The Nginx gateway. Never a backend port.
  GATEWAY_URL: z.string().url(),

  // The backend endpoint that exchanges a caller's token for the identity token.
  TOKEN_EXCHANGE_PATH: z.string().default('/api/auth/token-exchange'),

  // stdio for local development, streamable-http when deployed.
  MCP_TRANSPORT: z.enum(['stdio', 'streamable-http']).default('stdio'),
  MCP_PORT: z.coerce.number().int().positive().default(8100),

  // Local development only: the credential used to obtain a token when there is no
  // OAuth flow to carry one. Absent when the transport is streamable-http.
  LOCAL_EXCHANGE_CREDENTIAL: z.string().optional(),
});

const config = Config.parse(process.env);

const server = new McpServer({
  name: 'mcp-server',
  version: '0.1.0',
});

registerTools(server, config);

switch (config.MCP_TRANSPORT) {
  case 'stdio': {
    // Local development. There is no HTTP layer here, so there is no OAuth flow;
    // the token exchange uses LOCAL_EXCHANGE_CREDENTIAL instead.
    await server.connect(new StdioServerTransport());
    break;
  }
  case 'streamable-http': {
    // Deployed. The caller arrives with an OAuth 2.1 token, which every tool
    // exchanges for the identity token at the backend before calling through the gateway.
    await server.connect(
      new StreamableHttpServerTransport({ port: config.MCP_PORT }),
    );
    break;
  }
}
