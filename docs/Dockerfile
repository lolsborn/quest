# Dockerfile for Quest Documentation
# Multi-stage build: builds Quest from source, builds docs, serves with nginx

# ==============================================================================
# Stage 1: Build Quest from source
# ==============================================================================
FROM rust:latest AS quest-builder

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
# Stage 2: Build documentation
# ==============================================================================
FROM rust:latest AS docs-builder

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libudev-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy Quest binary from builder stage
COPY --from=quest-builder /quest/target/release/quest /usr/local/bin/quest

WORKDIR /app

# Copy docs source files
COPY docs/ .

# Set QUEST_INCLUDE to include docs directory for module resolution
ENV QUEST_INCLUDE=/app

# Run the documentation build script
RUN quest build.q

# ==============================================================================
# Stage 3: Serve with nginx
# ==============================================================================
FROM nginx:mainline

# Copy the built documentation from builder stage
COPY --from=docs-builder /app/output/ /usr/share/nginx/html/

# Copy custom nginx configuration (optional)
# COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# nginx runs as daemon by default in the base image
CMD ["nginx", "-g", "daemon off;"]
