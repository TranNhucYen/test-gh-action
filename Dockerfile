# ---------------------------------------------------
# Stage Base (chỉ dùng để BUILD): có pnpm
# ---------------------------------------------------
ARG NODE_VERSION=24-slim

FROM node:${NODE_VERSION} AS base
RUN npm install -g pnpm@12.14.0
WORKDIR /app

# ---------------------------------------------------
# Stage 1: Dependencies
# ---------------------------------------------------
FROM base AS deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

# ---------------------------------------------------
# Stage 2: Builder
# ---------------------------------------------------
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm build

# ---------------------------------------------------
# Stage 3: Runner - image sạch, KHÔNG kế thừa từ base
# ---------------------------------------------------
FROM node:${NODE_VERSION} AS runner
WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

# xoá npm/npx/corepack (runtime chỉ cần `node`),
# tạo user non-root
RUN rm -rf /usr/local/lib/node_modules/npm \
           /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm \
           /usr/local/bin/npx \
           /usr/local/bin/corepack \
    && groupadd --system --gid 1001 nodejs \
    && useradd --system --uid 1001 --gid nodejs nextjs

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]