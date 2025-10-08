#!/usr/bin/env bash

# Matrix multiplication benchmark runner
# Runs each benchmark and outputs the runtime

echo "=== Matrix Multiplication Benchmarks ==="
echo

# Rust benchmark (skipped - missing common/rust dependency)
if command -v cargo &> /dev/null; then
  echo "Building Rust benchmark..."
  cd matmul.rs && cargo build --release --quiet > /dev/null 2>&1
  if [ -f "target/release/matmul" ]; then
    echo "Running Rust benchmark..."
    /usr/bin/time -p ./target/release/matmul 2>&1 | grep -E "^(Matrix|real)"
    echo
  else
    echo "Rust build failed, skipping..."
    echo
  fi
  cd ..
else
  echo "Cargo not found, skipping Rust benchmark..."
  echo
fi

# Quest benchmark (ndarray version)
QUEST_BIN="../../target/release/quest"
if [ -f "$QUEST_BIN" ]; then
  echo "Running Quest benchmark (ndarray)..."
  /usr/bin/time -p "$QUEST_BIN" matmul-ndarray.q 2>&1 | grep -E "^(Matrix|real)"
  echo
else
  echo "Quest binary not found at $QUEST_BIN, skipping..."
  echo
fi

# Quest benchmark (basic version)
if [ -f "$QUEST_BIN" ]; then
  echo "Running Quest benchmark (basic)..."
  /usr/bin/time -p "$QUEST_BIN" matmul.q 2>&1 | grep -E "^(Matrix|real)"
  echo
else
  echo "Quest binary not found at $QUEST_BIN, skipping..."
  echo
fi

# Python benchmark
if command -v python3 &> /dev/null; then
  echo "Running Python benchmark..."
  /usr/bin/time -p python3 matmul.py 2>&1 | grep -E "^(Matrix|real)"
  echo
else
  echo "Python not found, skipping..."
  echo
fi

# Node.js benchmark
if command -v node &> /dev/null; then
  echo "Running Node.js benchmark..."
  /usr/bin/time -p node matmul.js 2>&1 | grep -E "^(Matrix|real)"
  echo
else
  echo "Node.js not found, skipping..."
  echo
fi

# Ruby benchmark
if command -v ruby &> /dev/null; then
  echo "Running Ruby benchmark..."
  /usr/bin/time -p ruby matmul.rb 2>&1 | grep -E "^(Matrix|real)"
  echo
else
  echo "Ruby not found, skipping..."
  echo
fi

echo "=== Benchmarks Complete ==="
