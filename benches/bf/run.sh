#!/usr/bin/env bash

# Brainfuck benchmark runner
# Runs each interpreter with mandel.b and outputs the runtime

BENCHMARK="mandel.b"

echo "=== Brainfuck Interpreter Benchmarks ==="
echo "Running: $BENCHMARK"
echo

# Quest benchmark
QUEST_BIN="../../target/release/quest"
if [ -f "$QUEST_BIN" ]; then
  echo "Running Quest benchmark..."
  /usr/bin/time -p "$QUEST_BIN" bf.q "$BENCHMARK" 2>&1 | tail -1
  echo
else
  echo "Quest binary not found at $QUEST_BIN, skipping..."
  echo
fi

# Node.js benchmark
if command -v node &> /dev/null; then
  echo "Running Node.js benchmark..."
  /usr/bin/time -p node bf.js "$BENCHMARK" 2>&1 | tail -1
  echo
else
  echo "Node.js not found, skipping..."
  echo
fi

# Ruby benchmark
if command -v ruby &> /dev/null; then
  echo "Running Ruby benchmark..."
  /usr/bin/time -p ruby bf.rb "$BENCHMARK" 2>&1 | tail -1
  echo
else
  echo "Ruby not found, skipping..."
  echo
fi

# Lua benchmark
if command -v lua &> /dev/null; then
  echo "Running Lua benchmark..."
  /usr/bin/time -p lua bf.lua "$BENCHMARK" 2>&1 | tail -1
  echo
else
  echo "Lua not found, skipping..."
  echo
fi

# Lua JIT benchmark
if command -v luajit &> /dev/null; then
  echo "Running LuaJIT benchmark..."
  /usr/bin/time -p luajit bf_jit.lua "$BENCHMARK" 2>&1 | tail -1
  echo
else
  echo "LuaJIT not found, skipping..."
  echo
fi

echo "=== Benchmarks Complete ==="
