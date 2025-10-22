# ==============================================================================
# Quest Blog Application
# ==============================================================================
FROM rust:bookworm

# Install build and runtime dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libudev-dev \
    libsqlite3-0 \
    sqlite3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Quest from crates.io
RUN cargo install vibequest

WORKDIR /app

# Copy the blog application
COPY . /app/

# Make entrypoint script executable
RUN chmod +x docker-entrypoint.sh

# Expose the default port
EXPOSE 3000

# Use entrypoint script that handles DB init and migrations
ENTRYPOINT ["./docker-entrypoint.sh"]
