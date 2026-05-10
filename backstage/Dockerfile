# Multi-stage Dockerfile for Backstage

# Stage 1: Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Install build tools
RUN apk add --no-cache python3 make g++

# Install nvm and use it to manage Node.js
RUN apk add --no-cache curl bash && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Copy application files
COPY . .

# Enable Corepack and install Yarn
RUN corepack enable && yarn set version 4.4.1

# Install dependencies
RUN yarn install --frozen-lockfile

# Build Backstage
RUN yarn build

# Stage 2: Runtime stage
FROM node:20-alpine

WORKDIR /app

# Install dumb-init to handle signals properly
RUN apk add --no-cache dumb-init

# Copy built application from builder stage
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/plugins ./plugins
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/app-config.yaml ./app-config.yaml
COPY --from=builder /app/yarn.lock ./yarn.lock
COPY --from=builder /app/.yarn ./.yarn
COPY --from=builder /app/.yarnrc.yml ./.yarnrc.yml

# Expose ports
EXPOSE 3000 7007

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:7007/api/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

# Use dumb-init to handle signals
ENTRYPOINT ["/sbin/dumb-init", "--"]

# Start Backstage
CMD ["yarn", "start"]
