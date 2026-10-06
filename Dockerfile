# ==============================================================================
# Telegram Local Bot API Server - Production Multi-Stage Dockerfile
# Official Source: https://github.com/tdlib/telegram-bot-api
# ==============================================================================

# --- Stage 1: Build Telegram Bot API from source ---
ARG ALPINE_VERSION=3.21
FROM alpine:${ALPINE_VERSION} AS builder

# Pinned commit from https://github.com/tdlib/telegram-bot-api
# Release: 10.3 (includes RichBlockDocument fix)
# Date: 2026-08-25
ARG TG_BOT_API_COMMIT=e3e9dd8e5b3d7ab8537cd5a10dc31d5ffa8f82d1

# Install build dependencies
RUN apk add --no-cache \
    alpine-sdk \
    linux-headers \
    git \
    zlib-dev \
    openssl-dev \
    gperf \
    cmake

WORKDIR /usr/src/telegram-bot-api

# Clone pinned commit and recursively checkout td submodule
RUN git clone https://github.com/tdlib/telegram-bot-api.git . \
    && git checkout ${TG_BOT_API_COMMIT} \
    && git submodule update --init --recursive

# Build and install release binary
RUN mkdir build \
    && cd build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. \
    && cmake --build . --target install -j$(nproc) \
    && strip /usr/local/bin/telegram-bot-api

# --- Stage 2: Clean minimal runtime image ---
FROM alpine:${ALPINE_VERSION}

# Install minimal runtime dependencies and curl for healthcheck
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    zlib \
    curl

ENV TELEGRAM_WORK_DIR="/var/lib/telegram-bot-api" \
    TELEGRAM_TEMP_DIR="/tmp/telegram-bot-api"

# Create dedicated non-root system user and group (UID 101, GID 101)
# Explicitly create and assign ownership of runtime directories to UID/GID 101
RUN addgroup -g 101 -S telegram-bot-api \
    && adduser -S -D -H -u 101 -h ${TELEGRAM_WORK_DIR} -s /sbin/nologin -G telegram-bot-api -g telegram-bot-api telegram-bot-api \
    && mkdir -p ${TELEGRAM_WORK_DIR} ${TELEGRAM_TEMP_DIR} \
    && chown -R 101:101 ${TELEGRAM_WORK_DIR} ${TELEGRAM_TEMP_DIR} \
    && chmod 770 ${TELEGRAM_WORK_DIR} ${TELEGRAM_TEMP_DIR}

# Copy compiled binary from builder stage
COPY --from=builder /usr/local/bin/telegram-bot-api /usr/local/bin/telegram-bot-api

# Persistent storage mount point
VOLUME ["/var/lib/telegram-bot-api"]

# Run as non-root user
USER telegram-bot-api
WORKDIR ${TELEGRAM_WORK_DIR}

# Expose internal HTTP port
EXPOSE 8081

ENTRYPOINT ["telegram-bot-api"]
CMD ["--local", "--http-port=8081", "--dir=/var/lib/telegram-bot-api", "--temp-dir=/tmp/telegram-bot-api"]
