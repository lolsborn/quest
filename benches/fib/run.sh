#!/usr/bin/env bash

# Fibonacci benchmark runner
# Runs each benchmark and outputs the runtime

echo "=== Fibonacci Benchmarks ==="
echo

# Rust benchmark
if command -v cargo &> /dev/null; then
  echo "Building Rust benchmark..."
  (cd fib.rs && cargo build --release --quiet > /dev/null 2>&1)
  if [ -f "fib.rs/target/release/fib" ]; then
    echo "Running Rust benchmark..."
    /usr/bin/time -p ./fib.rs/target/release/fib 2>&1 | grep -E "^(fib|real)"
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
  /usr/bin/time -p "$QUEST_BIN" fib.q 2>&1 | grep -E "^(fib|real)"
  echo
else
  echo "Quest binary not found at $QUEST_BIN, skipping..."
  echo
fi

# Python benchmark
if command -v python3 &> /dev/null; then
  echo "Running Python benchmark..."
  /usr/bin/time -p python3 fib.py 2>&1 | grep -E "^(fib|real)"
  echo
else
  echo "Python not found, skipping..."
  echo
fi

# Node.js benchmark
if command -v node &> /dev/null; then
  echo "Running Node.js benchmark..."
  /usr/bin/time -p node fib.js 2>&1 | grep -E "^(fib|real)"
  echo
else
  echo "Node.js not found, skipping..."
  echo
fi

# Ruby benchmark
if command -v ruby &> /dev/null; then
  echo "Running Ruby benchmark..."
  /usr/bin/time -p ruby fib.rb 2>&1 | grep -E "^(fib|real)"
  echo
else
  echo "Ruby not found, skipping..."
  echo
fi

# Lua benchmark
if command -v lua &> /dev/null; then
  echo "Running Lua benchmark..."
  /usr/bin/time -p lua fib.lua 2>&1 | grep -E "^(fib|real)"
  echo
else
  echo "Lua not found, skipping..."
  echo
fi

# LuaJIT benchmark
if command -v luajit &> /dev/null; then
  echo "Running LuaJIT benchmark..."
  /usr/bin/time -p luajit fib_jit.lua 2>&1 | grep -E "^(fib|real)"
  echo
else
  echo "LuaJIT not found, skipping..."
  echo
fi

echo "=== Benchmarks Complete ==="
