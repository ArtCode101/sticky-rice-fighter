# Frontend Knowledge Rules

## Scope

This file applies to all files under:

`knowledge/frontend/`

and governs how a `frontend` repository is written, run and built into an image. The
versions are in `knowledge/tech-stack.yaml`.

## Two shapes, one codebase

A frontend runs on Node.js while it is developed, and as static files once it is an
image. One variable, `NEXT_OUTPUT`, selects the shape, and only the Dockerfile sets it.

| | Development | Docker image |
|---|---|---|
| Where | Host process | Container |
| Command | `npm run dev` | `NEXT_OUTPUT=export npm run build`, inside the Dockerfile |
| Result | `next dev` on Node.js | A static export served by Nginx, with no Node.js in the image |
| Port | 3000 | 3000 |
| Rule | `knowledge/local-run/AGENTS.md` | This file |

## Write only what the image can serve

The development server is more permissive than the image. A page that uses a server
feature can work under `npm run dev` and then fail the image build, or fail in the
running image. So the code is written for the image from the start:

| Needed | Do this | Not this |
|---|---|---|
| Data from a backend | Fetch in the browser, in a client component, with TanStack Query and Axios | Fetch during render on a server, or during the build. No backend exists at build time. |
| A record's page | A fixed route and a query string: `/accounts/detail?id=42`, read with `useSearchParams()` inside `<Suspense>` | `/accounts/[id]` when the ids come from a backend |
| A route from a fixed list | `[slug]` with `generateStaticParams()` returning the whole list | `generateStaticParams()` that calls a backend |
| A form submit | A call to a backend endpoint, through the gateway | A Server Action |
| An API | A backend endpoint | A Route Handler |
| A login check | A client-side redirect for the screen; the backend enforces access on every call | Middleware or `proxy.ts`, `cookies()`, `headers()` |
| A redirect or a header | In the page, or in the gateway's configuration | `rewrites`, `redirects` or `headers` in `next.config.ts` |
| An image | `next/image` with the template's `images.unoptimized` | The image optimization server |

Also unavailable in the image: Incremental Static Regeneration and Draft Mode.

Check while developing, without building an image:

```bash
NEXT_OUTPUT=export npm run build
```

## Reaching the backend

The browser calls the backend at a **relative** path such as `/api/example/accounts`.
Both shapes serve the frontend through the gateway, so that path reaches Nginx and no
API address is configured. This is how one image runs in every environment. See
`knowledge/nginx/AGENTS.md`.

Open the system through the gateway while developing, on port 8000, not on the
development server's port 3000.

## What the export exposes

Every file in the export can be downloaded without logging in, including the screens of
a user group that must authenticate.

- Text and logic in a page are public. Sensitive values come from a backend, after login.
- `NEXT_PUBLIC_*` values are embedded at build time, so they are public too, and a value
  that differs per environment forces one build per environment. Avoid them. See
  `knowledge/config/AGENTS.md`.
- A provider's login callback is a static page that reads the code from the query string
  and sends it to a backend, which holds the provider secret. See
  `knowledge/auth/AGENTS.md`.

## Templates

| Template | Copy to |
|---|---|
| `templates/next.config.ts` | `next.config.ts` |
| `templates/Dockerfile` | `Dockerfile` |
| `templates/nginx.conf` | `nginx.conf` |
| `templates/dockerignore` | `.dockerignore` |
| `templates/docker-compose.yml` | one service in the `deployment` repository's `local/compose.yml`, lock `deployment-local` |

`templates/nginx.conf` only serves files inside the frontend container. It is not the
gateway, and it never proxies to a backend.

## A requirement a static export cannot meet

Some requirements need a server behind each page, such as a preview for link sharing or
search engine content for every record, when the records change after the build. The
Requirement Analysis Agent asks the human about such a requirement before the analysis
is approved. A Coding Agent that meets one during a release stops and reports it; it does
not add a Node.js runtime to the image.

AI agents must not:

- Set `output` in `next.config.ts` other than through `NEXT_OUTPUT`.
- Set `NEXT_OUTPUT` anywhere but the Dockerfile, except for the check above.
- Run a Node.js server in a frontend image.
- Put a key, a provider secret or any other secret in a frontend build.
- Modify the knowledge files in this directory during normal project generation.
