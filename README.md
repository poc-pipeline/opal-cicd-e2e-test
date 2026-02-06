# OPAL CI/CD End-to-End Test Repository

End-to-end testing of the OPAL-based CI/CD security gating pipeline with real integrations.

## Overview

This repository demonstrates a complete CI/CD workflow using:

- **Security Scanning**: Real Snyk vulnerability analysis
- **Quality Analysis**: Real SonarQube Cloud integration
- **Policy-Based Gating**: OPAL (Open Policy Agent) with Rego policies
- **Exception Management**: Real Jira Cloud integration
- **Policy Management UI**: Full-stack Vue 3 + FastAPI application

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Pipeline                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────┐   ┌─────────────┐   ┌───────────────┐              │
│  │  Build  │──▶│Security Scan│──▶│Quality Analysis│             │
│  │ (Maven) │   │   (Snyk)    │   │  (SonarQube)  │             │
│  └─────────┘   └─────────────┘   └───────────────┘             │
│                        │                  │                      │
│                        ▼                  ▼                      │
│               ┌───────────────────────────────────┐             │
│               │   OPAL Security Gate Evaluation    │             │
│               │   ┌───────────────────────────┐   │             │
│               │   │  Policies from GitHub     │   │             │
│               │   │  poc-pipeline/cicd-gating │   │             │
│               │   └───────────────────────────┘   │             │
│               └───────────────────────────────────┘             │
│                               │                                  │
│                    ┌──────────┴──────────┐                      │
│                    │                     │                       │
│               [PASS/WARN]           [BLOCKED]                   │
│                    │                     │                       │
│                    ▼                     ▼                       │
│             ┌────────────┐      ┌──────────────┐                │
│             │Docker Build│      │Fetch Jira    │                │
│             └────────────┘      │Exception     │                │
│                    │            └──────────────┘                │
│                    ▼                                            │
│             ┌────────────────────────────────────┐              │
│             │    Local Deployment Test           │              │
│             │  ┌──────┐ ┌─────┐ ┌────┐ ┌────┐  │              │
│             │  │ App  │ │ OPA │ │API │ │ UI │  │              │
│             │  │:8080 │ │:8181│ │:8K │ │:3K │  │              │
│             │  └──────┘ └─────┘ └────┘ └────┘  │              │
│             └────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Java 17
- Maven 3.8+
- Docker & Docker Compose
- Git
- GitHub CLI (`gh`) - for triggering workflows

### Local Development

```bash
# Clone the repository
git clone https://github.com/poc-pipeline/opal-cicd-e2e-test.git
cd opal-cicd-e2e-test

# Build the test application
make build

# Start the full stack
make start-stack

# Check service health
make health

# View the Policy Management UI
open http://localhost:3000
```

## Running the E2E Pipeline Locally

The Gate Evaluation job runs on a **self-hosted runner** to access the local Policy Management System. Follow these steps to run the complete E2E pipeline locally.

### Step 1: Start the Policy Management System

The Policy Management System must be running before triggering the pipeline:

```bash
# Navigate to the policy-management-system repository
cd /path/to/policy-management-system

# Start all containers (Zookeeper, Kafka, OPAL Server, OPA, API, UI)
docker compose up -d

# Verify containers are running
docker compose ps

# Check API health
curl http://localhost:8000/api/v1/health
```

**Services started:**
| Service | Port | Description |
|---------|------|-------------|
| Policy API | 8000 | FastAPI backend |
| Policy UI | 3000 | Vue 3 management interface |
| OPA | 8181 | Open Policy Agent |
| OPAL Server | 7002 | Policy synchronization |
| Kafka | 9092 | Event streaming |
| Zookeeper | 2181 | Kafka coordination |

### Step 2: Start the Self-Hosted Runner

The GitHub Actions self-hosted runner must be running to execute the Gate Evaluation job:

```bash
# Navigate to the actions-runner directory
cd ~/actions-runner

# Start the runner (foreground)
./run.sh

# Or start in background
nohup ./run.sh > /tmp/runner.log 2>&1 &

# Verify runner is online
gh api repos/poc-pipeline/opal-cicd-e2e-test/actions/runners \
  --jq '.runners[] | {name: .name, status: .status}'
```

**Expected output:**
```json
{"name":"wsl-local-runner","status":"online"}
```

---

## Local Runner Setup Guide

This section provides detailed instructions for setting up and running a GitHub Actions self-hosted runner for local development.

### Prerequisites

Before setting up the runner, ensure you have:

- **Operating System**: Linux (x64), macOS, or Windows
- **Git**: Installed and configured
- **GitHub CLI**: Installed (`gh auth login` completed)
- **Network Access**: Outbound HTTPS (443) to GitHub
- **Docker**: Running (required for Policy Management System)

### Installation

#### Step 1: Create Runner Directory

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
```

#### Step 2: Download the Runner

Download the latest runner package for your platform:

**Linux (x64):**
```bash
RUNNER_VERSION="2.321.0"
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
```

**macOS (x64):**
```bash
RUNNER_VERSION="2.321.0"
curl -o actions-runner-osx-x64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-osx-x64-${RUNNER_VERSION}.tar.gz
tar xzf actions-runner-osx-x64-${RUNNER_VERSION}.tar.gz
```

**macOS (ARM64/Apple Silicon):**
```bash
RUNNER_VERSION="2.321.0"
curl -o actions-runner-osx-arm64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-osx-arm64-${RUNNER_VERSION}.tar.gz
tar xzf actions-runner-osx-arm64-${RUNNER_VERSION}.tar.gz
```

> **Tip**: Check [GitHub Actions Runner Releases](https://github.com/actions/runner/releases) for the latest version.

#### Step 3: Generate Registration Token

Get a registration token from GitHub:

**Option A - Using GitHub CLI:**
```bash
gh api repos/poc-pipeline/opal-cicd-e2e-test/actions/runners/registration-token \
  --method POST --jq '.token'
```

**Option B - Using GitHub UI:**
1. Go to repository **Settings** → **Actions** → **Runners**
2. Click **New self-hosted runner**
3. Copy the token from the configuration command

#### Step 4: Configure the Runner

```bash
cd ~/actions-runner

./config.sh \
  --url https://github.com/poc-pipeline/opal-cicd-e2e-test \
  --token YOUR_REGISTRATION_TOKEN \
  --name wsl-local-runner \
  --labels self-hosted,linux,x64,local \
  --work _work
```

**Configuration options:**
| Option | Description |
|--------|-------------|
| `--name` | Unique name for this runner |
| `--labels` | Comma-separated labels for job targeting |
| `--work` | Working directory for job execution |
| `--replace` | Replace existing runner with same name |

### Running the Runner

#### Foreground Mode (Development)

```bash
cd ~/actions-runner
./run.sh
```

Press `Ctrl+C` to stop.

#### Background Mode

```bash
cd ~/actions-runner
nohup ./run.sh > /tmp/runner.log 2>&1 &

# View logs
tail -f /tmp/runner.log
```

#### As a Systemd Service (Linux - Recommended for Production)

```bash
cd ~/actions-runner

# Install the service
sudo ./svc.sh install

# Start the service
sudo ./svc.sh start

# Check status
sudo ./svc.sh status

# View logs
journalctl -u actions.runner.poc-pipeline-opal-cicd-e2e-test.wsl-local-runner -f
```

**Service management commands:**
```bash
sudo ./svc.sh stop      # Stop the service
sudo ./svc.sh start     # Start the service
sudo ./svc.sh status    # Check status
sudo ./svc.sh uninstall # Remove the service
```

### Verification

Verify the runner is online and ready:

```bash
# Check runner status via GitHub API
gh api repos/poc-pipeline/opal-cicd-e2e-test/actions/runners \
  --jq '.runners[] | {name: .name, status: .status, busy: .busy, labels: [.labels[].name]}'

# Check local runner process
pgrep -f "Runner.Listener" && echo "Runner process is running"

# Test connectivity to Policy Management System
curl -sf http://localhost:8000/api/v1/health && echo "Policy API is accessible"
```

**Expected output:**
```json
{
  "name": "wsl-local-runner",
  "status": "online",
  "busy": false,
  "labels": ["self-hosted", "linux", "x64", "local"]
}
```

### Updating the Runner

```bash
cd ~/actions-runner

# Stop the runner
./svc.sh stop  # If running as service
# Or Ctrl+C if running in foreground

# Download new version
RUNNER_VERSION="2.322.0"  # Replace with latest version
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Start the runner
./run.sh  # Or: sudo ./svc.sh start
```

### Removing the Runner

```bash
cd ~/actions-runner

# Stop the runner first
sudo ./svc.sh stop 2>/dev/null || pkill -f "Runner.Listener"

# Generate removal token
REMOVE_TOKEN=$(gh api repos/poc-pipeline/opal-cicd-e2e-test/actions/runners/remove-token \
  --method POST --jq '.token')

# Remove configuration
./config.sh remove --token $REMOVE_TOKEN

# Uninstall service (if installed)
sudo ./svc.sh uninstall 2>/dev/null

# Clean up directory (optional)
cd ~ && rm -rf ~/actions-runner
```

### Environment Variables

The runner can use environment variables from a `.env` file:

```bash
# Create .env in the runner directory
cat > ~/actions-runner/.env << 'EOF'
POLICY_API_URL=http://localhost:8000
POLICY_API_KEY=dev-pipeline-key
EOF
```

### Runner Labels

The gate evaluation workflow targets runners with the `self-hosted` label. Ensure your runner has this label:

```yaml
# In .github/workflows/gate-evaluation.yml
jobs:
  evaluate:
    runs-on: self-hosted  # Targets self-hosted runners
```

---

### Step 3: Trigger the Pipeline

Trigger the E2E pipeline using the GitHub CLI:

```bash
# Trigger the workflow
gh workflow run e2e-pipeline.yml --repo poc-pipeline/opal-cicd-e2e-test

# Watch the workflow execution
gh run watch --repo poc-pipeline/opal-cicd-e2e-test

# Or list recent runs
gh run list --repo poc-pipeline/opal-cicd-e2e-test --workflow=e2e-pipeline.yml --limit 5
```

### Step 4: View Results

After the pipeline completes:

```bash
# View run summary
gh run view <RUN_ID> --repo poc-pipeline/opal-cicd-e2e-test

# View failed logs (if any)
gh run view <RUN_ID> --repo poc-pipeline/opal-cicd-e2e-test --log-failed

# Check gate evaluation in Policy Management UI
open http://localhost:3000
```

### Troubleshooting

**Runner shows as offline:**
```bash
# Check if runner process is running
pgrep -f "Runner.Listener"

# Restart the runner
cd ~/actions-runner && ./run.sh
```

**Gate Evaluation job stuck in "queued":**
- Verify the runner is online and not busy
- Check that the runner has the `self-hosted` label

**API connection refused:**
```bash
# Verify Policy Management System is running
docker compose -f /path/to/policy-management-system/docker-compose.yml ps

# Check API is responding
curl http://localhost:8000/api/v1/health
```

**Gate returns BLOCKED:**
- This is expected behavior when vulnerabilities exceed thresholds
- Check thresholds in Policy Management UI at http://localhost:3000
- Review the gate evaluation summary in GitHub Actions

### Running the Pipeline

The pipeline runs automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Manual trigger via `workflow_dispatch`

## Project Structure

```
opal-cicd-e2e-test/
├── .github/
│   ├── workflows/
│   │   ├── e2e-pipeline.yml          # Main CI/CD pipeline
│   │   └── opal-gate-evaluation.yml  # Reusable OPAL workflow
│   └── scripts/
│       ├── evaluate-gates.sh         # Gate evaluation script
│       └── fetch-jira-exceptions.sh  # Jira exception fetcher
├── test-app/                         # Spring Boot test application
│   ├── pom.xml
│   ├── Dockerfile
│   └── src/
├── policy-management-stack/          # Docker Compose for full stack
│   └── docker-compose.yml
├── Makefile                          # Development commands
└── README.md
```

## Pipeline Stages

| Stage | Tool | Description |
|-------|------|-------------|
| Build | Maven | Compile, run unit tests, generate coverage |
| Security Scan | Snyk | Analyze dependencies for vulnerabilities |
| Quality Analysis | SonarQube Cloud | Code quality metrics and ratings |
| Gate Evaluation | OPA | Policy-based deployment decision |
| Docker Build | Docker | Build container image |
| Deployment Test | Docker Compose | Health check verification |

## Gate Evaluation

### Exit Codes

| Code | Decision | Description |
|------|----------|-------------|
| 0 | PASS | All gates passed |
| 0 | PASS_WITH_EXCEPTION | Blocked gates bypassed via Jira |
| 1 | WARNING | Non-blocking issues detected |
| 2 | BLOCKED | Requires Jira exception |

### Security Gates

| Gate ID | Severity | Threshold | Strength |
|---------|----------|-----------|----------|
| gatr-01 | Critical | 0 | ENFORCING |
| gatr-02 | High | 5 | NON_ENFORCING |
| gatr-03 | Medium | 20 | NON_ENFORCING |

### Quality Gates

| Gate ID | Metric | Threshold | Strength |
|---------|--------|-----------|----------|
| gatr-07 | Security Rating | A | ENFORCING |
| gatr-08 | Reliability Rating | A | NON_ENFORCING |
| gatr-10 | Coverage | 50% | NON_ENFORCING |

## Required Secrets

Configure these in your GitHub repository settings:

| Secret | Description | Required |
|--------|-------------|----------|
| `SNYK_TOKEN` | Snyk authentication token | Yes |
| `SNYK_ORG_ID` | Snyk organization ID | Yes |
| `SONAR_TOKEN` | SonarQube Cloud token | Yes |
| `SONAR_ORGANIZATION` | SonarQube organization | Yes |
| `SONAR_PROJECT_KEY` | SonarQube project key | Yes |
| `JIRA_BASE_URL` | Jira Cloud URL | Optional |
| `JIRA_USER_EMAIL` | Jira user email | Optional |
| `JIRA_API_TOKEN` | Jira API token | Optional |

## Services (Local Development)

| Service | Port | Description |
|---------|------|-------------|
| Test Application | 8080 | Spring Boot REST API |
| OPA | 8181 | Policy engine |
| Policy API | 8000 | FastAPI backend |
| Policy UI | 3000 | Vue 3 management interface |

## Make Commands

```bash
make build         # Build test application
make test          # Run unit tests
make build-docker  # Build Docker image
make start-stack   # Start all services
make stop-stack    # Stop all services
make health        # Check service health
make evaluate      # Run gate evaluation
make test-opa      # Test OPA policy
make logs          # View service logs
make clean         # Clean build artifacts
```

## Related Repositories

- [poc-pipeline/cicd-gating-policies](https://github.com/poc-pipeline/cicd-gating-policies) - Rego policies
- [poc-pipeline/policy-management-system](https://github.com/poc-pipeline/policy-management-system) - Policy Management UI
- [poc-pipeline/cicd-pipeline-poc](https://github.com/poc-pipeline/cicd-pipeline-poc) - Reference CI/CD pipeline

## License

MIT
