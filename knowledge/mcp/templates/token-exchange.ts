// Token exchange.
//
// This server holds NO signing key and NO RSA key pair. The backend owns the
// authentication group's key pair, so the backend is what turns the caller's token
// into a JWT RS256 for that same user.
//
// Two shapes, one backend code path:
//
//   remote (streamable-http): the caller's OAuth 2.1 token is exchanged
//   local  (stdio):           LOCAL_EXCHANGE_CREDENTIAL is exchanged
//
// The resulting JWT is what every tool sends through the gateway. The backend sees
// the real end user and applies its own authorization rules unchanged.

export interface ExchangeConfig {
  GATEWAY_URL: string;
  TOKEN_EXCHANGE_PATH: string;
  LOCAL_EXCHANGE_CREDENTIAL?: string;
}

export class TokenExchangeError extends Error {}

/**
 * Exchanges the caller's credential for a JWT RS256 issued by the backend.
 *
 * `callerToken` is the OAuth 2.1 token when the transport is streamable-http, and
 * undefined on stdio, where the local credential is used instead.
 */
export async function exchangeForBackendJwt(
  config: ExchangeConfig,
  callerToken?: string,
): Promise<string> {
  const subject = callerToken ?? config.LOCAL_EXCHANGE_CREDENTIAL;

  if (!subject) {
    throw new TokenExchangeError(
      'No caller token and no LOCAL_EXCHANGE_CREDENTIAL: nothing to exchange.',
    );
  }

  // The exchange endpoint is a backend endpoint, so it goes through the gateway
  // like every other call.
  const response = await fetch(
    new URL(config.TOKEN_EXCHANGE_PATH, config.GATEWAY_URL),
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${subject}`,
      },
      body: JSON.stringify({ requested_token_type: 'jwt-rs256' }),
    },
  );

  if (!response.ok) {
    throw new TokenExchangeError(
      `Token exchange failed with HTTP ${response.status}.`,
    );
  }

  const body = (await response.json()) as { access_token?: unknown };

  if (typeof body.access_token !== 'string') {
    throw new TokenExchangeError('Token exchange returned no access_token.');
  }

  return body.access_token;
}
