# Authentication Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/auth/`

and governs authentication in every system the framework builds.

## Purpose

A requirement says "the system has login". It almost never says *how*. That gap used to
be filled by assuming username and password. It is now filled by **asking**.

This file holds the login methods as patterns, what each one needs set up outside the
code, and the token rules that apply whichever one is chosen.

## Login methods are offered, not assumed

When a requirement implies login, the Requirement Analysis Agent asks which method,
through `knowledge/questions/AGENTS.md`, one question with these options:

| Option | Needs provider setup | Note |
|---|---|---|
| Username and password | no | **Allowed, but never the recommended option.** It stays on the list because a human may want it. |
| Google / Gmail | yes — Google Cloud Console | `gcloud` CLI exists, so the agent can do part of it |
| Azure AD | yes — Azure portal | `az` CLI exists, so the agent can do part of it |
| LINE | yes — LINE Developers Console | **No CLI.** Console only |
| Facebook | yes — Meta for Developers | |
| 2FA | on top of another method | Not a method on its own |

AI agents must not:

- Pick a login method because the requirement did not specify one.
- Recommend username and password. It is offered; it is not advised.
- Add 2FA as though it replaced a login method.

## Provider setup: two options, every time

Every method that needs something registered with a provider is offered the same two
ways. This is one question, asked after the method is chosen:

```text
Azure AD needs an app registration. How should it be created?

  1. The agent does it            — installs the az CLI, pops up Azure's own login
                                    for you to confirm, then does the rest unattended
  2. You do it in the portal      — the agent gives you a numbered list of what to
                                    click, and waits for the tenant ID and client ID
  3. Something else               — type your answer
```

### Option 1 — the agent does it

- Install the provider's CLI (`az`, `gcloud`).
- Trigger the provider's **own** login and let the human confirm it. The agent never
  asks for, handles or stores the human's provider credentials.
- After that, create the registration and read back what the code needs.

### Option 2 — the human does it

- The agent writes out the steps as a **numbered list of what to click**, in order,
  naming the actual screens and fields.
- It then waits for the values the code needs — tenant ID, client ID, channel ID,
  channel secret, whichever the provider issues.

Either way the outcome is the same: the configuration values reach the code and
development continues.

### LINE has no CLI

LINE Developers Console is the only path. Create a provider, create a **LINE Login
channel**, enable the web app, then take **Channel ID** and **Channel secret** from
Basic settings. Option 1 is not offered for LINE.

Callback URLs: one channel accepts several, one per line — which fits the
one-environment-at-a-time rule below.

### Optional: the agent drives the console

For a console with no CLI, the agent may drive the browser directly through the
**browser extension**, reading the live screen and clicking, while the human watches
every step. The human signs into the console first.

- This is **not** a Playwright script written in advance against a console's layout.
  It is a live agent looking at the page, so a redesigned console does not break it.
- It is an **extra option**, never the default. "You do it in the portal" stays the
  default for every provider.

## Redirect URIs: one environment at a time

A redirect URI is registered **when its environment appears**, not all of them up front.

Native development, a container, and each real environment are different URLs. Add the
new one at the point the new environment exists.

## Provider secrets

The agent does not decide where a provider secret lives. It **tells the human where it
goes** and the human puts it there.

- Default: the `config` repository's per-environment tree, with a placeholder committed
  and the real value only in the git-ignored file. See `knowledge/config/AGENTS.md`.
- If the human uses **HashiCorp Vault**, the agent points at the exact page to add it
  on, rather than describing Vault in general.

AI agents must not commit a provider secret, print it into a log, or embed it in a
frontend or mobile build.

## Tokens: JWE for identity, JWS for display

Two kinds of token, two purposes, and they are not interchangeable.

| Token | Format | Why |
|---|---|---|
| **Identity token** — proves who the caller is | **JWE.** Genuinely encrypted; unreadable without the key. | A signed-only token's payload is readable by anyone holding it. That is not acceptable for identity. |
| **Display data** — values the frontend renders | **JWS.** Signed, readable. | The frontend has to read it, so encrypting it would mean shipping a key to the browser. |

A plain signed token is **not** acceptable as an identity token, whatever the signing
algorithm. "JWT" names the family, not the protection: the common case is JWS, which is
readable. When this framework says the identity token is JWE, it means the payload
cannot be read without the key.

### Keys

- **RS256**, with a key pair, generated with OpenSSL.
- **A separate key pair per environment.** No pair is shared across environments.
- The **private key signs**. The **public key verifies**.
- The frontend holds **no key**. Verification is the backend's job. The public key
  exists so other services in the same environment can verify that a token was issued
  here.
- A service that must **decrypt** a JWE identity token needs the decryption key, not
  merely the public key. Which services need it is decided per system.

AI agents must not:

- Issue an identity token as JWS.
- Share one key pair across two environments.
- Ship any key to a browser or embed one in a mobile build.
- Put sensitive data in a JWS payload on the assumption that signing hides it.

Where key material lives, how long a token lasts, whether there is a refresh token, and
how keys are rotated are **not decided**. See `NOTES.md`.

## Journey tests and provider login

A journey test cannot type its way through a provider's own login screen, and it does
not try.

1. The first run opens the provider's login and **the human clicks through it**.
2. The browser's **storage state** — cookies and local storage — is saved to a file.
3. Later runs load that file and start already signed in.
4. When it expires, the login screen comes back up and the human clicks once more.

Because step 1 needs a human, a journey with provider login is **forced to desktop
mode** and the mode question is not asked. See `knowledge/journey/AGENTS.md`.

The storage state file holds a live session. It is git-ignored, never committed, and
never copied between environments.

## Must not

- Modify the knowledge files in this directory during normal project generation.
- Assume a login method, or recommend username and password.
- Offer the agent-does-it option for a provider with no CLI.
- Make the browser-extension path the default.
- Register every redirect URI up front.
- Commit a provider secret or a storage state file.
