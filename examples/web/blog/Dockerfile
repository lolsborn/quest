FROM debian:bookworm-slim

# Install build and runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    pkg-config \
    libssl-dev \
    libsqlite3-0 \
    sqlite3 \
    libudev-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Rust and vibequest in one layer
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . "$HOME/.cargo/env" && \
    cargo install vibequest

ENV PATH="/root/.cargo/bin:${PATH}"

# Copy the blog application
COPY . /app/

# Make entrypoint script executable
RUN chmod +x docker-entrypoint.sh

# Expose the default port
EXPOSE 3000

# Use entrypoint script that handles DB init and migrations
ENTRYPOINT ["./docker-entrypoint.sh"]
