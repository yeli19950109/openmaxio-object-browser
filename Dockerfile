# Build stage for frontend
FROM node:20-alpine AS frontend-builder
WORKDIR /app/web-app

# Git is required for some dependencies pulled from repositories
RUN apk add --no-cache git

# Install JS dependencies using BuildKit cache for faster subsequent builds
COPY web-app/package.json web-app/yarn.lock ./
RUN --mount=type=cache,target=/root/.cache/yarn \
    corepack enable && corepack prepare yarn@4.4.0 --activate && yarn install --immutable

# Build React static assets
COPY web-app/ ./
RUN yarn install --immutable --check-cache
RUN yarn build

# Build stage for backend
FROM golang:1.23-alpine AS backend-builder
WORKDIR /app

# Download Go modules using cache layer
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download -x

# Copy the rest of the source code (excluding /web-app/build which isn't present yet)
COPY . .

# Bring in the pre-built frontend assets and embed them
COPY --from=frontend-builder /app/web-app/build ./web-app/build

# Produce a fully static binary
RUN CGO_ENABLED=0 GOOS=linux \
    go build -trimpath --tags=kqueue --ldflags "-s -w" -o console ./cmd/console

# -------- Runtime stage --------
FROM alpine:latest

# Add certificates and create an unprivileged user
RUN apk --no-cache add ca-certificates \
    && addgroup -S console && adduser -S console -G console

WORKDIR /home/console

# Copy the statically-linked binary
COPY --from=backend-builder /app/console ./

# Switch to non-root user for better security
USER console

EXPOSE 9090

# Basic healthcheck — adjust path if your server exposes another endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s CMD wget -qO- http://127.0.0.1:9090/health || exit 1


CMD ["./console", "server"]
