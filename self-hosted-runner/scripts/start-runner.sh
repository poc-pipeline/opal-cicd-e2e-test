#!/bin/bash
#
# start-runner.sh - Start the GitHub Actions self-hosted runner
#
# Usage:
#   ./start-runner.sh [--dir /path/to/runner]
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Default runner directory
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            RUNNER_DIR="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Verify runner directory exists
if [ ! -d "$RUNNER_DIR" ]; then
    echo -e "${RED}Runner directory not found: $RUNNER_DIR${NC}"
    echo -e "Run setup-linux.sh first to install the runner."
    exit 1
fi

if [ ! -f "$RUNNER_DIR/run.sh" ]; then
    echo -e "${RED}Runner not installed in: $RUNNER_DIR${NC}"
    echo -e "Run setup-linux.sh first to install the runner."
    exit 1
fi

cd "$RUNNER_DIR"

# Check if already running
if pgrep -f "Runner.Listener" > /dev/null; then
    PID=$(pgrep -f "Runner.Listener")
    echo -e "${YELLOW}Runner is already running (PID: $PID)${NC}"
    exit 0
fi

# Start runner in background
echo -e "${YELLOW}Starting GitHub Actions runner...${NC}"
nohup ./run.sh > runner.log 2>&1 &
RUNNER_PID=$!

# Wait for runner to initialize
sleep 3

# Verify it started
if pgrep -f "Runner.Listener" > /dev/null; then
    ACTUAL_PID=$(pgrep -f "Runner.Listener")
    echo -e "${GREEN}Runner started successfully${NC}"
    echo -e "  PID: $ACTUAL_PID"
    echo -e "  Log: $RUNNER_DIR/runner.log"
    echo -e "  Diagnostics: $RUNNER_DIR/_diag/"
else
    echo -e "${RED}Runner failed to start${NC}"
    echo -e "Check logs: tail -50 $RUNNER_DIR/runner.log"
    exit 1
fi
