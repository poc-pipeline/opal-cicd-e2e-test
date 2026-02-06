#!/bin/bash
#
# stop-runner.sh - Stop the GitHub Actions self-hosted runner
#
# Usage:
#   ./stop-runner.sh [--force]
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check if runner is running
if ! pgrep -f "Runner.Listener" > /dev/null; then
    echo -e "${YELLOW}Runner is not running${NC}"
    exit 0
fi

PID=$(pgrep -f "Runner.Listener")
echo -e "${YELLOW}Stopping runner (PID: $PID)...${NC}"

if [ "$FORCE" = true ]; then
    # Force kill
    pkill -9 -f "Runner.Listener" 2>/dev/null || true
    pkill -9 -f "Runner.Worker" 2>/dev/null || true
    echo -e "${GREEN}Runner force stopped${NC}"
else
    # Graceful stop
    pkill -f "Runner.Listener" 2>/dev/null || true

    # Wait for graceful shutdown
    for i in {1..10}; do
        if ! pgrep -f "Runner.Listener" > /dev/null; then
            echo -e "${GREEN}Runner stopped gracefully${NC}"
            exit 0
        fi
        sleep 1
    done

    # Force kill if still running
    echo -e "${YELLOW}Graceful shutdown timed out, forcing...${NC}"
    pkill -9 -f "Runner.Listener" 2>/dev/null || true
    pkill -9 -f "Runner.Worker" 2>/dev/null || true
    echo -e "${GREEN}Runner stopped${NC}"
fi
