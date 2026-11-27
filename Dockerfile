# syntax=docker/dockerfile:1

# ---- Dependencies stage ----
FROM node:24-alpine AS deps

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev && mkdir -p node_modules

# ---- Runtime stage ----
FROM node:24-alpine AS runtime

ARG APP_VERSION=dev

LABEL org.opencontainers.image.title="aws-ecs-bluegreen" \
      org.opencontainers.image.description="Node.js service on AWS ECS Fargate" \
      org.opencontainers.image.source="https://github.com/devops-boilerplate/aws-ecs-bluegreen" \
      org.opencontainers.image.version="${APP_VERSION}"

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# The application only needs the node binary. Remove the package managers
# bundled in the base image so they are not shipped (and scanned) at runtime.
RUN rm -rf \
      /usr/local/lib/node_modules/npm \
      /usr/local/lib/node_modules/corepack \
      /usr/local/lib/node_modules/yarn \
      /opt/yarn-v1.22.22 \
      /usr/local/bin/npm \
      /usr/local/bin/npx \
      /usr/local/bin/corepack \
      /usr/local/bin/yarn \
      /usr/local/bin/yarnpkg

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY package*.json ./
COPY server.js ./

USER appuser

ENV NODE_ENV=production \
    PORT=8080 \
    APP_VERSION=${APP_VERSION}

EXPOSE 8080

STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/health || exit 1

CMD ["node", "server.js"]
