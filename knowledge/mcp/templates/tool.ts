// Generated tool: one file per OpenAPI operation.
//
// This file is a template for ONE operation taken from a backend's OpenAPI document
// in the registry repository. Copy it once per operation and fill in only the marked
// parts. Everything else is identical across tools on purpose.
//
// The mapping is mechanical. Do not select which operations get a tool, do not
// rename them, and do not invent one with no operation behind it:
//
//   operationId           -> the tool name and this file's name
//   summary, description  -> the description the calling agent reads
//   parameters, body      -> the Zod input schema
//   success response      -> the Zod output schema
//   method + path         -> the request below
//
// The request goes to the Nginx gateway, never to a backend port.

import type { McpServer } from '@modelcontextprotocol/server';
import { z } from 'zod';

import { exchangeForBackendJwt, type ExchangeConfig } from '../token-exchange.js';

// --- from the OpenAPI operation -------------------------------------------------

/** operationId */
const NAME = 'accountGetById';

/** summary, then description */
const DESCRIPTION = 'Get one account by id. Returns the account or a 404.';

/** method and path, exactly as the document spells them */
const METHOD = 'GET';
const PATH = '/api/account/accounts/{accountId}';

/** path, query and body parameters */
const Input = z.object({
  accountId: z.string().describe('Path parameter: the account id.'),
});

/** the success response schema */
const Output = z.object({
  id: z.string(),
  name: z.string(),
  currency: z.string(),
});

// --- fixed for every tool ------------------------------------------------------

export function register(server: McpServer, config: ExchangeConfig): void {
  server.registerTool(
    NAME,
    {
      description: DESCRIPTION,
      inputSchema: Input,
      outputSchema: Output,
    },
    async (input, { authInfo }) => {
      // The backend accepts JWT RS256 only, so the caller's token is exchanged
      // first. On stdio there is no caller token and the local credential is used.
      const jwt = await exchangeForBackendJwt(config, authInfo?.token);

      // Path parameters are substituted; whatever is left is the query or the body,
      // depending on the method.
      let path = PATH;
      const rest: Record<string, unknown> = { ...input };

      for (const [key, value] of Object.entries(input)) {
        const placeholder = `{${key}}`;
        if (path.includes(placeholder)) {
          path = path.replace(placeholder, encodeURIComponent(String(value)));
          delete rest[key];
        }
      }

      const url = new URL(path, config.GATEWAY_URL);
      const hasBody = METHOD !== 'GET' && METHOD !== 'DELETE';

      if (!hasBody) {
        for (const [key, value] of Object.entries(rest)) {
          url.searchParams.set(key, String(value));
        }
      }

      const response = await fetch(url, {
        method: METHOD,
        headers: {
          authorization: `Bearer ${jwt}`,
          ...(hasBody ? { 'content-type': 'application/json' } : {}),
        },
        ...(hasBody ? { body: JSON.stringify(rest) } : {}),
      });

      // The backend's own status is reported as it is. The MCP server does not
      // reinterpret it, retry it or hide it.
      if (!response.ok) {
        return {
          isError: true,
          content: [
            {
              type: 'text',
              text: `${METHOD} ${path} returned HTTP ${response.status}.`,
            },
          ],
        };
      }

      const data = Output.parse(await response.json());

      return {
        structuredContent: data,
        content: [{ type: 'text', text: JSON.stringify(data) }],
      };
    },
  );
}
