#!/bin/sh
set -e

echo "Quest Blog - Starting up..."

# Always run migrations on startup
echo "Running database migrations..."
quest migrate.q
echo "✓ Migrations complete"

# Start the Quest web server
echo "Starting Quest web server on 0.0.0.0:3000..."
exec quest serve index.q --host 0.0.0.0 --port 3000
