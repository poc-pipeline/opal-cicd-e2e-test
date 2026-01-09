# OPAL CI/CD End-to-End Test Repository

## Project Overview

This repository demonstrates end-to-end testing of the OPAL-based CI/CD security gating pipeline with:
- Real Snyk security scanning
- Real SonarQube Cloud quality analysis
- Real Jira exception management
- Policy Management System UI (OPA + FastAPI + Vue 3)
- Policies from `https://github.com/poc-pipeline/cicd-gating-policies`

## Project Structure

```
opal-cicd-e2e-test/
├── .github/
│   ├── workflows/
│   │   ├── e2e-pipeline.yml              # Main CI/CD pipeline
│   │   └── opal-gate-evaluation.yml      # Reusable OPAL evaluation
│   └── scripts/
│       ├── evaluate-gates.sh             # Gate evaluation script
│       └── fetch-jira-exceptions.sh      # Jira exception fetcher
├── test-app/                             # Spring Boot test application
│   ├── pom.xml
│   ├── Dockerfile
│   └── src/
├── policy-management-stack/              # Docker Compose for full stack
│   └── docker-compose.yml
├── Makefile                              # Local development commands
└── README.md
```

## Key Components

### Test Application
- Spring Boot 3.1.5, Java 17
- Endpoints: `/api/hello`, `/api/status`, `/actuator/health`
- JaCoCo coverage with 50% threshold
- SonarQube integration

### Pipeline Stages
1. **Build** - Maven compile and unit tests
2. **Security Scan** - Snyk vulnerability analysis
3. **Quality Analysis** - SonarQube Cloud
4. **OPAL Gate Evaluation** - Policy-based gating
5. **Docker Build** - Container image creation
6. **Local Deployment** - Health check verification

### Gate Evaluation
- Policies cloned from `poc-pipeline/cicd-gating-policies`
- Exit codes: 0=PASS, 1=WARNING, 2=BLOCKED
- Jira exceptions can bypass blocked gates

## Required Secrets

| Secret | Description |
|--------|-------------|
| `SNYK_TOKEN` | Snyk authentication |
| `SNYK_ORG_ID` | Snyk organization ID |
| `SONAR_TOKEN` | SonarQube Cloud token |
| `SONAR_ORGANIZATION` | SonarQube organization |
| `SONAR_PROJECT_KEY` | SonarQube project key |
| `JIRA_BASE_URL` | Jira Cloud URL |
| `JIRA_USER_EMAIL` | Jira user email |
| `JIRA_API_TOKEN` | Jira API token |

## Local Development

```bash
make build         # Build test application
make start-stack   # Start full Policy Management Stack
make evaluate      # Run gate evaluation manually
make stop-stack    # Stop all services
```

## Services (when running locally)

| Service | Port | Description |
|---------|------|-------------|
| Test App | 8080 | Spring Boot application |
| OPA | 8181 | Policy engine |
| Policy API | 8000 | FastAPI backend |
| Policy UI | 3000 | Vue 3 management interface |

## Related Repositories

- `poc-pipeline/cicd-gating-policies` - Rego policies
- `poc-pipeline/policy-management-system` - Policy Management UI
- `poc-pipeline/cicd-pipeline-poc` - Reference CI/CD pipeline
