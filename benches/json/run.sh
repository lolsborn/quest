#!/usr/bin/env bash

# JSON parsing benchmark runner
# Runs each benchmark and outputs the runtime

echo "=== JSON Parsing Benchmarks ==="
echo

# Generate test data if needed
if [ ! -f "/tmp/1.json" ]; then
  echo "Generating test data..."
  if command -v ruby &> /dev/null; then
    ruby generate_json.rb
    echo
  else
    echo "Ruby not found, cannot generate test data. Skipping all benchmarks..."
    exit 1
  fi
fi

# Rust benchmarks (multiple binaries)
if command -v cargo &> /dev/null; then
  echo "Building Rust benchmarks..."
  cd json.rs

  # Build individual binaries (excluding jq variant which requires system libjq)
  for bin in json-value-rs json-struct-rs json-pull-rs; do
    cargo build --release --bin "$bin" --quiet > /dev/null 2>&1
  done

  # Run each Rust variant
  for bin in json-value-rs json-struct-rs json-pull-rs; do
    if [ -f "target/release/$bin" ]; then
      echo "Running Rust benchmark ($bin)..."
      /usr/bin/time -p "./target/release/$bin" 2>&1 | grep -E "^(Coordinate|real)"
      echo
    fi
  done

  cd ..
else
  echo "Cargo not found, skipping Rust benchmarks..."
  echo
fi

# Quest benchmark
QUEST_BIN="../../target/release/quest"
if [ -f "$QUEST_BIN" ]; then
  echo "Running Quest benchmark..."
  /usr/bin/time -p "$QUEST_BIN" test.q 2>&1 | grep -E "^(Coordinate|real)"
  echo
else
  echo "Quest binary not found at $QUEST_BIN, skipping..."
  echo
fi

# Python benchmark
if command -v python3 &> /dev/null; then
  echo "Running Python benchmark..."
  /usr/bin/time -p python3 test.py 2>&1 | grep -E "^(Coordinate|real)"
  echo
else
  echo "Python not found, skipping..."
  echo
fi

# Node.js benchmark
if command -v node &> /dev/null; then
  echo "Running Node.js benchmark..."
  /usr/bin/time -p node test.js 2>&1 | grep -E "^(Coordinate|real)"
  echo
else
  echo "Node.js not found, skipping..."
  echo
fi

# Ruby benchmark
if command -v ruby &> /dev/null; then
  echo "Running Ruby benchmark..."
  /usr/bin/time -p ruby test.rb 2>&1 | grep -E "^(Coordinate|real)"
  echo
else
  echo "Ruby not found, skipping..."
  echo
fi

echo "=== Benchmarks Complete ==="
