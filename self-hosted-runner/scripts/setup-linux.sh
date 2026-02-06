#!/bin/bash
#
# setup-linux.sh - Automated GitHub Actions self-hosted runner setup for Linux/WSL
#
# Usage:
#   ./setup-linux.sh [OPTIONS]
#
# Options:
#   --name NAME         Runner name (default: hostname-runner)
#   --labels LABELS     Additional labels (default: self-hosted,linux,x64)
#   --work-dir DIR      Working directory (default: ~/actions-runner)
#   --token TOKEN       Registration token (or will prompt)
#   --repo REPO         Repository (default: poc-pipeline/opal-cicd-e2e-test)
#   --version VERSION   Runner version (default: latest)
#   --help              Show this help
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Defaults
RUNNER_NAME="${HOSTNAME:-local}-runner"
RUNNER_LABELS="self-hosted,linux,x64"
WORK_DIR="$HOME/actions-runner"
REPO="poc-pipeline/opal-cicd-e2e-test"
RUNNER_VERSION=""
REGISTRATION_TOKEN=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            RUNNER_NAME="$2"
            shift 2
            ;;
        --labels)
            RUNNER_LABELS="$2"
            shift 2
            ;;
        --work-dir)
            WORK_DIR="$2"
            shift 2
            ;;
        --token)
            REGISTRATION_TOKEN="$2"
            shift 2
            ;;
        --repo)
            REPO="$2"
            shift 2
            ;;
        --version)
            RUNNER_VERSION="$2"
            shift 2
            ;;
        --help)
            head -20 "$0" | tail -15
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitHub Actions Self-Hosted Runner Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for required tools
for cmd in curl tar jq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is required but not installed.${NC}"
        exit 1
    fi
done

# Check for gh CLI (optional but recommended)
if command -v gh &> /dev/null; then
    GH_AVAILABLE=true
    echo -e "${GREEN}  GitHub CLI: Available${NC}"
else
    GH_AVAILABLE=false
    echo -e "${YELLOW}  GitHub CLI: Not available (manual token entry required)${NC}"
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        RUNNER_ARCH="x64"
        ;;
    aarch64|arm64)
        RUNNER_ARCH="arm64"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac
echo -e "${GREEN}  Architecture: $ARCH ($RUNNER_ARCH)${NC}"

# Detect OS
OS=$(uname -s)
case $OS in
    Linux)
        RUNNER_OS="linux"
        ;;
    Darwin)
        RUNNER_OS="osx"
        ;;
    *)
        echo -e "${RED}Unsupported OS: $OS${NC}"
        exit 1
        ;;
esac
echo -e "${GREEN}  OS: $OS ($RUNNER_OS)${NC}"

# Get latest runner version if not specified
if [ -z "$RUNNER_VERSION" ]; then
    echo -e "${YELLOW}Fetching latest runner version...${NC}"
    RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
    if [ -z "$RUNNER_VERSION" ] || [ "$RUNNER_VERSION" = "null" ]; then
        RUNNER_VERSION="2.321.0"  # Fallback
    fi
fi
echo -e "${GREEN}  Runner version: $RUNNER_VERSION${NC}"

# Get registration token if not provided
if [ -z "$REGISTRATION_TOKEN" ]; then
    echo ""
    if [ "$GH_AVAILABLE" = true ]; then
        echo -e "${YELLOW}Fetching registration token via GitHub CLI...${NC}"
        REGISTRATION_TOKEN=$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq '.token' 2>/dev/null)
        if [ -z "$REGISTRATION_TOKEN" ]; then
            echo -e "${RED}Failed to get token. Make sure you're authenticated with 'gh auth login'${NC}"
            exit 1
        fi
        echo -e "${GREEN}  Token obtained successfully${NC}"
    else
        echo -e "${YELLOW}Please enter your registration token:${NC}"
        echo -e "  (Get it from: https://github.com/$REPO/settings/actions/runners/new)"
        read -s -p "Token: " REGISTRATION_TOKEN
        echo ""
    fi
fi

# Create working directory
echo ""
echo -e "${YELLOW}Creating runner directory: $WORK_DIR${NC}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Check if runner is already configured
if [ -f ".runner" ]; then
    echo -e "${YELLOW}Existing runner configuration found.${NC}"
    read -p "Remove existing configuration and reconfigure? (y/N): " CONFIRM
    if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
        echo -e "${YELLOW}Removing existing configuration...${NC}"
        ./config.sh remove --token "$REGISTRATION_TOKEN" 2>/dev/null || true
    else
        echo -e "${GREEN}Keeping existing configuration.${NC}"
        exit 0
    fi
fi

# Download runner
RUNNER_FILE="actions-runner-${RUNNER_OS}-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_FILE}"

if [ ! -f "$RUNNER_FILE" ]; then
    echo ""
    echo -e "${YELLOW}Downloading runner v${RUNNER_VERSION}...${NC}"
    curl -L -o "$RUNNER_FILE" "$RUNNER_URL"
fi

# Extract runner
echo -e "${YELLOW}Extracting runner...${NC}"
tar xzf "$RUNNER_FILE"

# Configure runner
echo ""
echo -e "${YELLOW}Configuring runner...${NC}"
echo -e "  Name: ${GREEN}$RUNNER_NAME${NC}"
echo -e "  Labels: ${GREEN}$RUNNER_LABELS${NC}"
echo -e "  Repository: ${GREEN}$REPO${NC}"
echo ""

./config.sh \
    --url "https://github.com/$REPO" \
    --token "$REGISTRATION_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --work "_work" \
    --replace \
    --unattended

# Create start/stop scripts in runner directory
cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
if pgrep -f "Runner.Listener" > /dev/null; then
    echo "Runner is already running"
    exit 0
fi
nohup ./run.sh > runner.log 2>&1 &
echo "Runner started with PID $!"
EOF
chmod +x start.sh

cat > stop.sh << 'EOF'
#!/bin/bash
pkill -f "Runner.Listener" && echo "Runner stopped" || echo "Runner was not running"
EOF
chmod +x stop.sh

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Runner setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "To start the runner:"
echo -e "  ${BLUE}cd $WORK_DIR && ./start.sh${NC}"
echo ""
echo -e "To stop the runner:"
echo -e "  ${BLUE}cd $WORK_DIR && ./stop.sh${NC}"
echo ""
echo -e "To run interactively:"
echo -e "  ${BLUE}cd $WORK_DIR && ./run.sh${NC}"
echo ""

# Ask to start now
read -p "Start the runner now? (Y/n): " START_NOW
if [ "$START_NOW" != "n" ] && [ "$START_NOW" != "N" ]; then
    echo ""
    echo -e "${YELLOW}Starting runner...${NC}"
    ./start.sh
    sleep 2
    if pgrep -f "Runner.Listener" > /dev/null; then
        echo -e "${GREEN}Runner is now active and listening for jobs.${NC}"
    else
        echo -e "${RED}Runner failed to start. Check runner.log for details.${NC}"
    fi
fi
