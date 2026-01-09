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
