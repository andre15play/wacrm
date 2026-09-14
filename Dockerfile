# syntax=docker/dockerfile:1

FROM node:20-alpine AS base
# libc6-compat is required for some Node modules on Alpine
RUN apk add --no-cache libc6-compat
WORKDIR /app

# 1. Install dependencies
FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json ./
# Clean install for reproducible builds
RUN npm ci

# 2. Build the Next.js app
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Disable telemetry during build
ENV NEXT_TELEMETRY_DISABLED 1

# Build the app (outputs to .next/standalone because of next.config.ts)
RUN npm run build

# 3. Production runner
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1
# Set PORT to what Easypanel or similar expects (often 3000)
ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy the public directory so static assets are available
COPY --from=builder /app/public ./public

# Setup permissions for the .next cache directory
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Copy the standalone Next.js server and static files
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Switch to the non-root user
USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
