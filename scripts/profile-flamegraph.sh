#!/usr/bin/env bash
# Generate flame graphs with cargo-flamegraph
#
# Usage:
#   ./scripts/profile-flamegraph.sh                    # Profile test suite
#   ./scripts/profile-flamegraph.sh test/arrays/basic.q  # Profile specific test
#   ./scripts/profile-flamegraph.sh --output custom.svg # Custom output name

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Quest Flame Graph Generator${NC}"
echo "================================================"

# Check if cargo-flamegraph is installed
if ! cargo flamegraph --version &> /dev/null; then
    echo "Error: cargo-flamegraph is not installed"
    echo "Install with: cargo install flamegraph"
    exit 1
fi

# Parse arguments
OUTPUT="flamegraph.svg"
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --output|-o)
            OUTPUT="$2"
            shift 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Build command
if [ ${#ARGS[@]} -eq 0 ]; then
    echo -e "${GREEN}Generating flame graph for test suite...${NC}"
    FLAME_ARGS=("scripts/qtest")
else
    echo -e "${GREEN}Generating flame graph for: ${ARGS[*]}${NC}"
    FLAME_ARGS=("${ARGS[@]}")
fi

# Generate flame graph
echo "This may take a minute..."
cargo flamegraph --profile profiling --output "$OUTPUT" -- "${FLAME_ARGS[@]}"

echo ""
echo -e "${GREEN}Flame graph generated!${NC}"
echo "Output: $OUTPUT"
echo ""
echo -e "${YELLOW}To view:${NC}"
echo "  open $OUTPUT    # macOS"
echo "  xdg-open $OUTPUT    # Linux"
