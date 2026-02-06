# Self-Hosted Runner Setup Guide

This guide covers setting up GitHub Actions self-hosted runners for the E2E OPAL CI/CD Pipeline.

## Overview

The **Gate Evaluation** job in the E2E pipeline runs on a self-hosted runner to access the Policy Management System API at `localhost:8000`. This enables real-time policy evaluation against OPA/OPAL without exposing the API publicly.

## Requirements

### For Gate Evaluation to work, ensure:
1. **Policy Management System** is running (API, OPA, OPAL Server, Kafka)
2. **Runner** can reach `http://localhost:8000` (the Policy API)
3. **Runner** is registered with the `self-hosted` label

### System Requirements
- **OS**: Linux (Ubuntu 20.04+), macOS, or Windows with WSL2
- **RAM**: 2GB minimum
- **Disk**: 10GB free space
- **Network**: Outbound HTTPS to `github.com` and `*.actions.githubusercontent.com`

---

## Setup Options

| Method | Best For | Complexity |
|--------|----------|------------|
| [Bare Metal](#1-bare-metal-setup) | Development, single machine | Low |
| [Docker](#2-docker-setup) | Isolation, reproducibility | Medium |
| [Kubernetes (ARC)](#3-kubernetes-arc-setup) | Production, auto-scaling | High |

---

## 1. Bare Metal Setup

### Quick Start (Linux/macOS)

```bash
# Run the setup script
./scripts/setup-linux.sh
```

### Manual Setup

#### Step 1: Create Runner Directory
```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
```

#### Step 2: Download Runner
```bash
# Get latest version from https://github.com/actions/runner/releases
RUNNER_VERSION="2.321.0"
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
```

#### Step 3: Get Registration Token
```bash
# Via GitHub CLI
gh api -X POST repos/poc-pipeline/opal-cicd-e2e-test/actions/runners/registration-token \
  --jq '.token'

# Or via Settings > Actions > Runners > New self-hosted runner
```

#### Step 4: Configure Runner
```bash
./config.sh \
  --url https://github.com/poc-pipeline/opal-cicd-e2e-test \
  --token <REGISTRATION_TOKEN> \
  --name "local-runner" \
  --labels "self-hosted,linux,x64" \
  --work "_work" \
  --runasservice
```

#### Step 5: Start Runner
```bash
# Interactive (foreground)
./run.sh

# Background
nohup ./run.sh > runner.log 2>&1 &
```

### Managing the Runner

```bash
# Start
./scripts/start-runner.sh

# Stop
./scripts/stop-runner.sh

# Check status
./scripts/status-runner.sh

# View logs
tail -f ~/actions-runner/runner.log
```

---

## 2. Docker Setup

### Prerequisites
- Docker 20.10+
- Docker Compose v2+

### Quick Start

```bash
cd docker/

# Copy and configure environment
cp .env.example .env
# Edit .env with your registration token

# Start runner
docker compose up -d

# View logs
docker compose logs -f
```

### Configuration

Edit `docker/.env`:
```bash
RUNNER_NAME=docker-runner
RUNNER_TOKEN=<your-registration-token>
GITHUB_REPOSITORY=poc-pipeline/opal-cicd-e2e-test
```

### Network Modes

#### Option A: Host Network (Recommended)
The runner shares the host network stack. `localhost:8000` works directly.

```yaml
# docker-compose.yml
services:
  runner:
    network_mode: host
```

#### Option B: Bridge Network with Host Access
Use Docker's special DNS name to reach host services.

```yaml
services:
  runner:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Then update the workflow to use `http://host.docker.internal:8000` as the API URL.

#### Option C: Shared Docker Network
If Policy Management System runs in Docker Compose, add the runner to the same network:

```yaml
services:
  runner:
    networks:
      - policy-management-system_default

networks:
  policy-management-system_default:
    external: true
```

### Building Custom Image

```bash
cd docker/
docker build -t custom-actions-runner:latest .
```

---

## 3. Kubernetes (ARC) Setup

GitHub's **Actions Runner Controller** (ARC) provides auto-scaling runners on Kubernetes.

### Prerequisites
- Kubernetes cluster (1.23+)
- Helm 3.x
- kubectl configured

### Installation

#### Step 1: Install ARC Controller
```bash
helm install arc \
  --namespace arc-systems \
  --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
```

#### Step 2: Create GitHub App or PAT Secret
```bash
kubectl create secret generic github-token \
  --namespace arc-runners \
  --from-literal=github_token=<YOUR_PAT>
```

#### Step 3: Deploy Runner Scale Set
```bash
helm install runner-set \
  --namespace arc-runners \
  --create-namespace \
  -f kubernetes/helm-values.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

### Accessing localhost Services

For runners to reach `localhost:8000`, the Policy Management System must be deployed in the same cluster. Use a Kubernetes Service:

```yaml
# In helm-values.yaml
template:
  spec:
    containers:
      - name: runner
        env:
          - name: POLICY_API_URL
            value: "http://policy-api.policy-system.svc.cluster.local:8000"
```

---

## Troubleshooting

### Runner not picking up jobs

1. **Check runner status**
   ```bash
   gh api repos/poc-pipeline/opal-cicd-e2e-test/actions/runners --jq '.runners[] | {name, status, busy}'
   ```

2. **Verify labels match workflow**
   ```yaml
   # Workflow expects:
   runs-on: self-hosted
   ```

3. **Check runner logs**
   ```bash
   tail -100 ~/actions-runner/_diag/Runner_*.log
   ```

### Cannot reach localhost:8000

1. **Verify Policy API is running**
   ```bash
   curl -sf http://localhost:8000/health
   ```

2. **Check from runner context**
   - Bare metal: Should work directly
   - Docker with `network_mode: host`: Should work directly
   - Docker with bridge: Use `host.docker.internal:8000`

3. **Test connectivity**
   ```bash
   # From inside Docker runner
   docker exec -it github-runner curl http://host.docker.internal:8000/health
   ```

### Runner crashes or restarts

1. **Check system resources**
   ```bash
   free -h
   df -h
   ```

2. **Review crash logs**
   ```bash
   ls -lt ~/actions-runner/_diag/
   cat ~/actions-runner/_diag/Runner_*.log | tail -100
   ```

### Token expired

Registration tokens expire after 1 hour. Generate a new one:
```bash
gh api -X POST repos/poc-pipeline/opal-cicd-e2e-test/actions/runners/registration-token --jq '.token'
```

---

## Security Considerations

1. **Runner isolation**: Self-hosted runners execute arbitrary code from workflows. Use dedicated machines or containers.

2. **Token security**: Never commit registration tokens. Use environment variables or secrets management.

3. **Network segmentation**: Limit runner network access to only required services (GitHub, Policy API).

4. **Regular updates**: Keep runner software updated:
   ```bash
   cd ~/actions-runner
   ./config.sh remove --token <REMOVAL_TOKEN>
   # Re-download and configure latest version
   ```

---

## Files in This Directory

```
self-hosted-runner/
├── README.md                    # This documentation
├── scripts/
│   ├── setup-linux.sh          # Automated Linux/WSL setup
│   ├── start-runner.sh         # Start runner in background
│   ├── stop-runner.sh          # Stop running runner
│   └── status-runner.sh        # Check runner status
├── docker/
│   ├── Dockerfile              # Custom runner image
│   ├── docker-compose.yml      # Docker Compose configuration
│   ├── docker-compose.bridge.yml  # Bridge network variant
│   └── .env.example            # Environment template
└── kubernetes/
    ├── helm-values.yaml        # ARC Helm values
    └── runner-deployment.yaml  # Manual K8s deployment
```

---

## References

- [GitHub Self-hosted Runners Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Actions Runner Releases](https://github.com/actions/runner/releases)
- [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller)
- [Docker-in-Docker Runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/deploying-runner-scale-sets-with-actions-runner-controller#using-docker-in-docker-mode)
