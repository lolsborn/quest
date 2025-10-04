#!/usr/bin/env bash
# Heap memory profiling with dhat-rs
#
# Usage:
#   ./scripts/profile-memory.sh                    # Profile test suite
#   ./scripts/profile-memory.sh test/arrays/basic.q  # Profile specific test
#   ./scripts/profile-memory.sh --repl             # Profile REPL

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Quest Memory Profiler (dhat-rs)${NC}"
echo "================================================"

# Build with profiling configuration and dhat-heap feature
echo -e "${GREEN}Building with heap profiling enabled...${NC}"
cargo build --profile profiling --features dhat-heap --quiet

QUEST_BIN="./target/profiling/quest"

# Remove old profiling data
rm -f dhat-heap.json

if [ "$1" == "--repl" ]; then
    echo -e "${GREEN}Profiling REPL memory usage...${NC}"
    echo "Type 'exit' or press Ctrl+D to finish profiling"
    "$QUEST_BIN"
elif [ -z "$1" ]; then
    echo -e "${GREEN}Profiling test suite memory usage...${NC}"
    "$QUEST_BIN" scripts/qtest
else
    echo -e "${GREEN}Profiling: $1${NC}"
    "$QUEST_BIN" "$@"
fi

echo ""
if [ -f "dhat-heap.json" ]; then
    echo -e "${GREEN}Profiling complete!${NC}"
    echo "Heap profiling data saved to: dhat-heap.json"
    echo ""
    echo -e "${YELLOW}To view results:${NC}"
    echo "1. Open: https://nnethercote.github.io/dh_view/dh_view.html"
    echo "2. Load the dhat-heap.json file"
    echo ""

    # Show quick summary if jq is available
    if command -v jq &> /dev/null; then
        echo -e "${BLUE}Quick Summary:${NC}"
        TOTAL_BYTES=$(jq '.total_bytes' dhat-heap.json)
        TOTAL_BLOCKS=$(jq '.total_blocks' dhat-heap.json)
        MAX_BYTES=$(jq '.max_bytes' dhat-heap.json)
        MAX_BLOCKS=$(jq '.max_blocks' dhat-heap.json)

        echo "  Total allocated:    $(numfmt --to=iec $TOTAL_BYTES 2>/dev/null || echo $TOTAL_BYTES bytes)"
        echo "  Total allocations:  $(printf "%'d" $TOTAL_BLOCKS)"
        echo "  Peak memory:        $(numfmt --to=iec $MAX_BYTES 2>/dev/null || echo $MAX_BYTES bytes)"
        echo "  Peak allocations:   $(printf "%'d" $MAX_BLOCKS)"
    fi
else
    echo -e "${YELLOW}Warning: dhat-heap.json not found${NC}"
    echo "Make sure the program ran to completion"
fi
