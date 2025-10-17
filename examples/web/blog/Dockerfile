# ==============================================================================
# Stage 1: Build Quest from source
# ==============================================================================
FROM rust:bookworm AS quest-builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libudev-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /quest

# Copy Quest source code (parent directory context required)
COPY Cargo.toml Cargo.lock ./
COPY src/ ./src/
COPY lib/ ./lib/

# Build Quest in release mode
RUN cargo build --release

# ==============================================================================
# Stage 2: Runtime
# ==============================================================================
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 \
    libsqlite3-0 \
    sqlite3 \
    libudev1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Quest binary from builder stage
COPY --from=quest-builder /quest/target/release/quest /usr/local/bin/quest

# Copy the blog application
COPY examples/web/blog/ /app/

# Make entrypoint script executable
RUN chmod +x docker-entrypoint.sh

# Expose the default port
EXPOSE 3000

# Use entrypoint script that handles DB init and migrations
ENTRYPOINT ["./docker-entrypoint.sh"]
