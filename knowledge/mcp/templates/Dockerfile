# MCP server image for the definition-of-done deploy.
#
# The tag is pinned in knowledge/tech-stack.yaml. Never use the latest tag.

FROM node:24.21.0-alpine3.24 AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:24.21.0-alpine3.24

WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY --from=build /app/dist ./dist

# Deployed, the server speaks Streamable HTTP. Locally it speaks stdio and is not
# containerized at all.
ENV MCP_TRANSPORT=streamable-http
EXPOSE 8100

USER node
CMD ["node", "dist/server.js"]
