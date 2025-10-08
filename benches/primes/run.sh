#!/usr/bin/env bash

# Primes benchmark runner
# Runs each benchmark and outputs the runtime

echo "=== Primes Benchmarks ==="
echo

# Rust benchmark
if command -v cargo &> /dev/null; then
  echo "Building Rust benchmark..."
  (cd primes.rs && cargo build --release --quiet > /dev/null 2>&1)
  if [ -f "primes.rs/target/release/primes" ]; then
    echo "Running Rust benchmark..."
    /usr/bin/time -p ./primes.rs/target/release/primes 2>&1 | grep -E "^(Primes|real)"
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
  /usr/bin/time -p "$QUEST_BIN" primes.q 2>&1 | grep -E "^(Primes|real)"
  echo
else
  echo "Quest binary not found at $QUEST_BIN, skipping..."
  echo
fi

# Python benchmark
if command -v python3 &> /dev/null; then
  echo "Running Python benchmark..."
  /usr/bin/time -p python3 primes.py 2>&1 | grep -E "^(Primes|real)"
  echo
else
  echo "Python not found, skipping..."
  echo
fi

# Node.js benchmark
if command -v node &> /dev/null; then
  echo "Running Node.js benchmark..."
  /usr/bin/time -p node primes.js 2>&1 | grep -E "^(Primes|real)"
  echo
else
  echo "Node.js not found, skipping..."
  echo
fi

# Ruby benchmark
if command -v ruby &> /dev/null; then
  echo "Running Ruby benchmark..."
  /usr/bin/time -p ruby primes.rb 2>&1 | grep -E "^(Primes|real)"
  echo
else
  echo "Ruby not found, skipping..."
  echo
fi

# Lua benchmark
if command -v lua &> /dev/null; then
  echo "Running Lua benchmark..."
  /usr/bin/time -p lua primes.lua 2>&1 | grep -E "^(Primes|real)"
  echo
else
  echo "Lua not found, skipping..."
  echo
fi

# LuaJIT benchmark
if command -v luajit &> /dev/null; then
  echo "Running LuaJIT benchmark..."
  /usr/bin/time -p luajit primes_jit.lua 2>&1 | grep -E "^(Primes|real)"
  echo
else
  echo "LuaJIT not found, skipping..."
  echo
fi

echo "=== Benchmarks Complete ==="
