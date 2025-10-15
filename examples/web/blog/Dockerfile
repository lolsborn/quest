# Build stage - install Rust and Quest from crates.io
FROM debian:bookworm AS builder

# Install build dependencies and rustup
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    libudev-dev \
    libssl-dev \
    pkg-config \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Rust via rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install vibequest from crates.io
RUN cargo install vibequest

# Runtime stage - same Debian version ensures glibc compatibility
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libsqlite3-0 \
    sqlite3 \
    libudev1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the Quest binary from cargo install location
COPY --from=builder /root/.cargo/bin/quest /usr/local/bin/quest

# Copy the blog application
COPY . /app/

# Initialize the database with sqlite3 directly (only if it doesn't exist)
RUN test -f blog.sqlite3 || sqlite3 blog.sqlite3 < schema.sql

# Expose the default port
EXPOSE 3000

# Run the Quest server with logging (bind to 0.0.0.0 for Docker)
CMD ["sh", "-c", "quest serve /app --host 0.0.0.0 --port 3000 2>&1 | tee /app/quest.log"]
