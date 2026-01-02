# Use official Bun image
FROM oven/bun:1 AS base
WORKDIR /app

# Install dependencies
FROM base AS install
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile --production

# Copy source and build
FROM base AS release
COPY --from=install /app/node_modules node_modules
COPY . .

# Set environment defaults
ENV PORT=8080
ENV HOST=0.0.0.0

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Run the server
USER bun
CMD ["bun", "run", "src/index.ts"]

