# QuantDinger Frontend — multi-arch image published to GHCR.
#
# Stage 1: build the Vue 2 SPA with vue-cli.
# Stage 2: serve the static dist via nginx, with BACKEND_URL injected at
# container start by the official image's envsubst step.

ARG NODE_IMAGE=node:18-alpine
ARG NGINX_IMAGE=nginx:1.25-alpine

FROM ${NODE_IMAGE} AS builder
WORKDIR /app

# git is needed by git-revision-webpack-plugin at build time.
# corepack ships with Node 16.13+; `enable` installs the pnpm shim. The
# concrete pnpm version is pinned by `packageManager` in package.json,
# which corepack auto-downloads on first use.
RUN apk add --no-cache git && corepack enable

# Copy lockfile + manifest first so the install layer caches.
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build

FROM ${NGINX_IMAGE}

RUN apk add --no-cache curl

# Pin the envsubst filter so only ${BACKEND_URL} is substituted — otherwise
# nginx's own $-variables ($host, $remote_addr, ...) would also be clobbered.
ENV NGINX_ENVSUBST_FILTER=BACKEND_URL \
    BACKEND_URL=http://backend:5000

COPY deploy/nginx-docker.conf.template /etc/nginx/templates/default.conf.template
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
