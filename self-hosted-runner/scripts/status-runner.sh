#!/bin/bash
#
# status-runner.sh - Check the status of the GitHub Actions self-hosted runner
#
# Usage:
#   ./status-runner.sh [--dir /path/to/runner] [--verbose]
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"
VERBOSE=false
REPO="poc-pipeline/opal-cicd-e2e-test"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            RUNNER_DIR="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --repo)
            REPO="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitHub Actions Runner Status${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check local process
echo -e "${YELLOW}Local Process:${NC}"
if pgrep -f "Runner.Listener" > /dev/null; then
    PID=$(pgrep -f "Runner.Listener")
    echo -e "  Status: ${GREEN}RUNNING${NC}"
    echo -e "  PID: $PID"

    # Get process details
    if [ "$VERBOSE" = true ]; then
        echo -e "  Memory: $(ps -o rss= -p $PID | awk '{printf "%.1f MB", $1/1024}')"
        echo -e "  CPU: $(ps -o %cpu= -p $PID)%"
        echo -e "  Started: $(ps -o lstart= -p $PID)"
    fi
else
    echo -e "  Status: ${RED}STOPPED${NC}"
fi

# Check runner configuration
echo ""
echo -e "${YELLOW}Configuration:${NC}"
if [ -f "$RUNNER_DIR/.runner" ]; then
    RUNNER_NAME=$(jq -r '.agentName // "unknown"' "$RUNNER_DIR/.runner" 2>/dev/null || echo "unknown")
    echo -e "  Name: $RUNNER_NAME"
    echo -e "  Directory: $RUNNER_DIR"

    if [ -f "$RUNNER_DIR/.credentials" ]; then
        echo -e "  Credentials: ${GREEN}Configured${NC}"
    else
        echo -e "  Credentials: ${RED}Missing${NC}"
    fi
else
    echo -e "  ${RED}Not configured${NC}"
    echo -e "  Run setup-linux.sh to configure the runner"
fi

# Check GitHub API for runner status (if gh CLI available)
echo ""
echo -e "${YELLOW}GitHub Status:${NC}"
if command -v gh &> /dev/null; then
    RUNNER_INFO=$(gh api "repos/$REPO/actions/runners" --jq '.runners[] | select(.name == "'"$RUNNER_NAME"'") | {status, busy, labels: [.labels[].name]}' 2>/dev/null || echo "")

    if [ -n "$RUNNER_INFO" ]; then
        GH_STATUS=$(echo "$RUNNER_INFO" | jq -r '.status')
        GH_BUSY=$(echo "$RUNNER_INFO" | jq -r '.busy')
        GH_LABELS=$(echo "$RUNNER_INFO" | jq -r '.labels | join(", ")')

        if [ "$GH_STATUS" = "online" ]; then
            echo -e "  Status: ${GREEN}ONLINE${NC}"
        else
            echo -e "  Status: ${RED}OFFLINE${NC}"
        fi

        if [ "$GH_BUSY" = "true" ]; then
            echo -e "  Busy: ${YELLOW}Yes (running a job)${NC}"
        else
            echo -e "  Busy: No"
        fi

        echo -e "  Labels: $GH_LABELS"
    else
        echo -e "  ${YELLOW}Runner not found in GitHub (may not be registered)${NC}"
    fi
else
    echo -e "  ${YELLOW}GitHub CLI not available (install 'gh' for remote status)${NC}"
fi

# Check recent logs
if [ "$VERBOSE" = true ] && [ -f "$RUNNER_DIR/runner.log" ]; then
    echo ""
    echo -e "${YELLOW}Recent Logs:${NC}"
    tail -10 "$RUNNER_DIR/runner.log" 2>/dev/null | sed 's/^/  /'
fi

# Check Policy API connectivity
echo ""
echo -e "${YELLOW}Policy API Connectivity:${NC}"
if curl -sf "http://localhost:8000/health" > /dev/null 2>&1; then
    echo -e "  http://localhost:8000: ${GREEN}REACHABLE${NC}"
else
    echo -e "  http://localhost:8000: ${RED}UNREACHABLE${NC}"
    echo -e "  ${YELLOW}(Gate Evaluation will fail without Policy API)${NC}"
fi

echo ""
