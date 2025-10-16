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

# Initialize the database with sqlite3 directly (only if it doesn't exist)
RUN test -f blog.sqlite3 || sqlite3 blog.sqlite3 < schema.sql

# Expose the default port
EXPOSE 3000

# Run the Quest server with logging (bind to 0.0.0.0 for Docker)
CMD ["sh", "-c", "quest serve /app --host 0.0.0.0 --port 3000 2>&1 | tee /app/quest.log"]
