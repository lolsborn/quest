#!/usr/bin/env bash
# CPU profiling with samply
#
# Usage:
#   ./scripts/profile-cpu.sh                    # Profile test suite
#   ./scripts/profile-cpu.sh test/arrays/basic.q  # Profile specific test
#   ./scripts/profile-cpu.sh --repl             # Profile REPL

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Quest CPU Profiler${NC}"
echo "================================================"

# Check if samply is installed
if ! command -v samply &> /dev/null; then
    echo "Error: samply is not installed"
    echo "Install with: cargo install samply"
    exit 1
fi

# Build with profiling configuration
echo -e "${GREEN}Building with profiling configuration...${NC}"
cargo build --profile profiling --quiet

QUEST_BIN="./target/profiling/quest"

if [ "$1" == "--repl" ]; then
    echo -e "${GREEN}Profiling REPL...${NC}"
    echo "Type 'exit' or press Ctrl+D to finish profiling"
    samply record "$QUEST_BIN"
elif [ -z "$1" ]; then
    echo -e "${GREEN}Profiling test suite...${NC}"
    samply record "$QUEST_BIN" test
else
    echo -e "${GREEN}Profiling: $1${NC}"
    samply record "$QUEST_BIN" "$@"
fi

echo ""
echo -e "${GREEN}Profiling complete!${NC}"
echo "Firefox Profiler should open automatically with results."
