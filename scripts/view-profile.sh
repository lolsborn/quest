#!/usr/bin/env bash
# View CPU profile in Firefox Profiler
#
# Usage:
#   ./scripts/view-profile.sh                  # View latest profile
#   ./scripts/view-profile.sh quest-profile.json.gz  # View specific profile

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Quest Profile Viewer${NC}"
echo "================================================"

# Find profile file
if [ -n "$1" ]; then
    PROFILE="$1"
elif [ -f "quest-profile.json.gz" ]; then
    PROFILE="quest-profile.json.gz"
elif [ -f "profile.json.gz" ]; then
    PROFILE="profile.json.gz"
elif [ -f "profile.json" ]; then
    PROFILE="profile.json"
else
    echo "Error: No profile file found"
    echo ""
    echo "Available profiles:"
    ls -lh *.json* 2>/dev/null | grep profile || echo "  (none)"
    exit 1
fi

echo -e "${GREEN}Profile file: ${PROFILE}${NC}"

# Get file size and age
SIZE=$(ls -lh "$PROFILE" | awk '{print $5}')
echo "Size: $SIZE"
echo ""

echo -e "${YELLOW}Opening Firefox Profiler...${NC}"
echo ""
echo "The profile will open in your browser."
echo ""
echo "What to look for:"
echo "  • Flame Graph tab - Visual representation"
echo "  • Call Tree tab - Function hierarchy"
echo "  • Wide bars = Functions using most CPU"
echo "  • Tall stacks = Deep recursion"
echo ""

# Open Firefox Profiler
open "https://profiler.firefox.com/"

echo "Waiting for browser to open..."
sleep 3

echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Drag and drop '${PROFILE}' onto the browser"
echo "  2. Click 'Flame Graph' tab for visual view"
echo "  3. Click on wide bars to see function names"
echo "  4. Use 'Invert call stack' to see bottom-up view"
echo ""
echo -e "${YELLOW}Tip:${NC} Look for these patterns:"
echo "  • eval_pair - Main interpreter loop"
echo "  • call_method - Method calls"
echo "  • parse/Parser - Parsing overhead"
echo "  • clone - Copying overhead"
echo ""
