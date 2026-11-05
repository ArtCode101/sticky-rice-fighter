# Frontend image for the definition-of-done deploy.
#
# The image holds static files only: the build stage exports the site, and Nginx serves
# it. There is no Node.js process in the running container. On the host, during
# development, the frontend still runs on Node.js with `npm run dev`.
#
# The tags are pinned in knowledge/tech-stack.yaml. Never use the latest tag.

FROM node:24.21.0-alpine3.24 AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Only here does the build become a static export. A page that cannot be exported fails
# this step, which is why next.config.ts reads the variable rather than always exporting.
ENV NEXT_OUTPUT=export
RUN npm run build

FROM nginx:1.30.5

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/out /usr/share/nginx/html

# The same port the development server uses. The gateway proxies to it.
EXPOSE 3000
