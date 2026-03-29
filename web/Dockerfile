# syntax=docker/dockerfile:1

FROM node:20-bookworm-slim AS builder
WORKDIR /app

ARG DEPS_MODE=host
ENV DEPS_MODE=${DEPS_MODE}
ENV NODE_OPTIONS=--dns-result-order=ipv4first
ARG API_URL=http://api:8080
ENV API_URL=$API_URL
ENV NEXT_TELEMETRY_DISABLED=1
ARG NPM_CONFIG_REGISTRY=

COPY package.json package-lock.json* ./
COPY . .

RUN set -e; \
    if [ -n "$NPM_CONFIG_REGISTRY" ]; then npm config set registry "$NPM_CONFIG_REGISTRY"; fi; \
    npm config set fetch-retries 15 && \
    npm config set fetch-retry-mintimeout 30000 && \
    npm config set fetch-retry-maxtimeout 300000

RUN --mount=type=cache,target=/root/.npm \
    if [ "$DEPS_MODE" = "docker" ]; then \
      rm -rf node_modules && npm ci --no-audit --fund=false; \
    else \
      if [ ! -d node_modules ] || [ -z "$(ls -A node_modules 2>/dev/null)" ]; then \
        echo >&2 "Missing web/node_modules. On the host: cd web && npm ci"; \
        echo >&2 "If npm times out, set a mirror: export NPM_CONFIG_REGISTRY=https://your.registry/ then rebuild."; \
        echo >&2 "Or in-container install: docker compose build --build-arg DEPS_MODE=docker web"; \
        exit 1; \
      fi; \
    fi

RUN npm run build

FROM node:20-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN groupadd --system --gid 1001 nodejs && \
    useradd --system --uid 1001 --gid nodejs nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
CMD ["node", "server.js"]
