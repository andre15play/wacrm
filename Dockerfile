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
ENV NEXT_TELEMETRY_DISABLED=1

# Accept build arguments passed by Easypanel
ARG NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL

ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY

ARG NEXT_PUBLIC_SITE_URL
ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL

ARG NEXT_PUBLIC_APP_LOCALE
ENV NEXT_PUBLIC_APP_LOCALE=$NEXT_PUBLIC_APP_LOCALE

ARG SUPABASE_SERVICE_ROLE_KEY
ENV SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY

ARG ENCRYPTION_KEY
ENV ENCRYPTION_KEY=$ENCRYPTION_KEY

ARG META_APP_SECRET
ENV META_APP_SECRET=$META_APP_SECRET

ARG GIT_SHA
ENV GIT_SHA=$GIT_SHA

# Build the app (outputs to .next/standalone because of next.config.ts)
RUN npm run build

# 3. Production runner
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
# Set PORT to what Easypanel or similar expects (often 3000)
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

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
