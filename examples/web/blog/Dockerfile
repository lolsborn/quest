# Build stage - install Quest from crates.io
FROM rust:1.90 AS builder

# Install vibequest from crates.io
RUN cargo install vibequest

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libsqlite3-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the Quest binary from cargo install location
COPY --from=builder /usr/local/cargo/bin/quest /usr/local/bin/quest

# Copy the blog application
COPY . /app/

# Initialize the database
RUN quest init_db.q

# Expose the default port
EXPOSE 3000

# Run the Quest server
CMD ["quest", "serve", "/app/"]
