#!/usr/bin/env bash

# Base64 benchmark runner
# Runs each benchmark and outputs the runtime

echo "=== Base64 Benchmarks ==="
echo

# Rust benchmark
if command -v cargo &> /dev/null; then
  echo "Building Rust benchmark..."
  cargo build --release --quiet > /dev/null 2>&1
  if [ -f "target/release/test" ]; then
    echo "Running Rust benchmark..."
    /usr/bin/time -p ./target/release/test 2>&1 | grep -E "^(encode|decode|real)"
    echo
  else
    echo "Rust build failed, skipping..."
    echo
  fi
else
  echo "Cargo not found, skipping Rust benchmark..."
  echo
fi

# Quest benchmark
QUEST_BIN="../../target/release/quest"
if [ -f "$QUEST_BIN" ]; then
  echo "Running Quest benchmark..."
  /usr/bin/time -p "$QUEST_BIN" test.q 2>&1 | grep -E "^(encode|decode|real)"
  echo
else
  echo "Quest binary not found at $QUEST_BIN, skipping..."
  echo
fi

# Python benchmark
if command -v python3 &> /dev/null; then
  echo "Running Python benchmark..."
  /usr/bin/time -p python3 test.py 2>&1 | grep -E "^(encode|decode|real)"
  echo
else
  echo "Python not found, skipping..."
  echo
fi

# Node.js benchmark
if command -v node &> /dev/null; then
  echo "Running Node.js benchmark..."
  /usr/bin/time -p node test.js 2>&1 | grep -E "^(encode|decode|real)"
  echo
else
  echo "Node.js not found, skipping..."
  echo
fi

# Ruby benchmark
if command -v ruby &> /dev/null; then
  echo "Running Ruby benchmark..."
  /usr/bin/time -p ruby test.rb 2>&1 | grep -E "^(encode|decode|real)"
  echo
else
  echo "Ruby not found, skipping..."
  echo
fi

echo "=== Benchmarks Complete ==="
