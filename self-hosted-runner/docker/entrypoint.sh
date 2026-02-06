#!/bin/bash
#
# entrypoint.sh - Docker entrypoint for GitHub Actions runner
#
# Required environment variables:
#   RUNNER_TOKEN         - Registration token from GitHub
#   GITHUB_REPOSITORY    - Repository in format owner/repo
#
# Optional environment variables:
#   RUNNER_NAME          - Runner name (default: hostname)
#   RUNNER_LABELS        - Comma-separated labels (default: self-hosted,linux,x64,docker)
#   RUNNER_WORKDIR       - Working directory (default: _work)
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Validate required environment variables
if [ -z "$RUNNER_TOKEN" ]; then
    echo -e "${RED}Error: RUNNER_TOKEN environment variable is required${NC}"
    exit 1
fi

if [ -z "$GITHUB_REPOSITORY" ]; then
    echo -e "${RED}Error: GITHUB_REPOSITORY environment variable is required${NC}"
    exit 1
fi

# Set defaults
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,x64,docker}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-_work}"
GITHUB_URL="https://github.com/${GITHUB_REPOSITORY}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}GitHub Actions Runner (Docker)${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Repository: ${YELLOW}${GITHUB_REPOSITORY}${NC}"
echo -e "Runner Name: ${YELLOW}${RUNNER_NAME}${NC}"
echo -e "Labels: ${YELLOW}${RUNNER_LABELS}${NC}"
echo ""

# Change to runner home directory
cd /home/runner

# Remove existing configuration if present (for container restarts)
if [ -f ".runner" ]; then
    echo -e "${YELLOW}Removing existing runner configuration...${NC}"
    ./config.sh remove --token "${RUNNER_TOKEN}" 2>/dev/null || true
fi

# Configure the runner
echo -e "${YELLOW}Configuring runner...${NC}"
./config.sh \
    --url "${GITHUB_URL}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --work "${RUNNER_WORKDIR}" \
    --replace \
    --unattended

# Cleanup function for graceful shutdown
cleanup() {
    echo ""
    echo -e "${YELLOW}Received shutdown signal, cleaning up...${NC}"

    # Remove runner from GitHub
    if [ -n "$RUNNER_TOKEN" ]; then
        ./config.sh remove --token "${RUNNER_TOKEN}" 2>/dev/null || true
    fi

    echo -e "${GREEN}Runner removed successfully${NC}"
    exit 0
}

# Trap signals for graceful shutdown
trap cleanup SIGTERM SIGINT SIGQUIT

# Start the runner
echo ""
echo -e "${GREEN}Starting runner...${NC}"
./run.sh &

# Wait for the runner process
wait $!
