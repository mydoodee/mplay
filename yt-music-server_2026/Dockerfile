# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev

# Production stage
FROM node:20-alpine
WORKDIR /app

# Install yt-dlp + ffmpeg
RUN apk add --no-cache python3 ffmpeg curl \
    && curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp \
    && chmod a+rx /usr/local/bin/yt-dlp \
    && yt-dlp --version

# Copy dependencies from builder
COPY --from=builder /app/node_modules ./node_modules

# Copy app source
COPY package.json ./
COPY src/ ./src/
COPY .env* ./

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 3456

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://localhost:3456/health || exit 1

CMD ["node", "src/server.js"]
