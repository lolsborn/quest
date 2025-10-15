# Build stage
FROM rust:1.75 AS builder

WORKDIR /build

# Copy the entire Quest project
COPY . .

# Build Quest in release mode
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libsqlite3-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the Quest binary
COPY --from=builder /build/target/release/quest /usr/local/bin/quest

# Copy the blog application
COPY . /app/

# Initialize the database
RUN quest init_db.q

# Expose the default port
EXPOSE 3000

# Run the Quest server
CMD ["quest", "serve", "/app/"]
