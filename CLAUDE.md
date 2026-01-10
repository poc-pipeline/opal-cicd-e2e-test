# OPAL CI/CD End-to-End Test Repository

## Project Overview

This repository demonstrates end-to-end testing of a modular CI/CD pipeline with policy-based security gating:
- Real Snyk security scanning
- Real SonarQube Cloud quality analysis
- Gate evaluation using local Policy Management System
- Self-hosted runner for local API access

## Project Structure

```
opal-cicd-e2e-test/
├── .github/
│   ├── actions/
│   │   ├── setup-java-maven/             # Java/Maven environment setup
│   │   ├── download-build-artifacts/     # Artifact management
│   │   ├── generate-security-summary/    # Snyk report generation
│   │   ├── generate-quality-summary/     # SonarQube report generation
│   │   ├── parse-scan-results/           # Parse security & quality results
│   │   ├── evaluate-policy-gates/        # Call Policy Management System API
│   │   └── generate-gate-summary/        # Generate gate evaluation summary
│   └── workflows/
│       ├── e2e-pipeline.yml              # Main modular CI/CD pipeline
│       ├── build-application.yml         # Reusable: Maven build & test
│       ├── security-scanning.yml         # Reusable: Snyk vulnerability scanning
│       ├── quality-analysis.yml          # Reusable: SonarQube Cloud analysis
│       ├── gate-evaluation.yml           # Reusable: Policy gate evaluation
│       └── test-local-gates.yml          # Simple gate test workflow
├── microservice-moc-app/                 # Spring Boot test application
│   ├── pom.xml
│   ├── Dockerfile
│   └── src/
├── snyk-scanning/                        # Snyk configuration and results
│   ├── scripts/
│   └── results/
├── sonarqube-cloud-scanning/             # SonarQube configuration and results
│   ├── scripts/
│   └── results/
├── Makefile                              # Local development commands
└── README.md
```

## Pipeline Architecture

### Main Pipeline: `e2e-pipeline.yml`

The main pipeline uses modular reusable workflows:

```
┌─────────────────┐
│     Build       │  (build-application.yml)
│  Maven compile  │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐  ┌──────────┐
│ Snyk  │  │ SonarQube│  (security-scanning.yml, quality-analysis.yml)
│ Scan  │  │ Analysis │
└───┬───┘  └────┬─────┘
    │           │
    └─────┬─────┘
          ▼
┌─────────────────┐
│ Gate Evaluation │  (gate-evaluation.yml)
│ Policy System   │  Runs on self-hosted runner
└─────────────────┘
```

### Reusable Workflows

| Workflow | Description |
|----------|-------------|
| `build-application.yml` | Maven compile and unit tests |
| `security-scanning.yml` | Snyk vulnerability analysis |
| `quality-analysis.yml` | SonarQube Cloud analysis |
| `gate-evaluation.yml` | Policy gate evaluation via local API |

### Composite Actions

| Action | Description |
|--------|-------------|
| `setup-java-maven` | Setup Java and Maven with caching |
| `download-build-artifacts` | Download and verify build artifacts |
| `generate-security-summary` | Generate Snyk results summary |
| `generate-quality-summary` | Generate SonarQube results summary |
| `parse-scan-results` | Parse Snyk and SonarQube JSON results |
| `evaluate-policy-gates` | Call Policy Management System API |
| `generate-gate-summary` | Generate gate evaluation GitHub summary |

## Gate Evaluation

### Reusable Workflow: `gate-evaluation.yml`

The gate evaluation workflow:
1. Downloads security and quality scan artifacts
2. Parses results using `parse-scan-results` action
3. Calls Policy Management System via `evaluate-policy-gates` action
4. Generates summary using `generate-gate-summary` action

### API Call

```bash
curl -X POST http://localhost:8000/api/v1/pipeline/evaluate \
  -H "Content-Type: application/json" \
  -H "X-API-Key: dev-pipeline-key" \
  -d '{
    "repository": "owner/repo",
    "branch": "main",
    "vulnerabilities": {"critical": 0, "high": 2, "medium": 5, "low": 10},
    "quality_metrics": {"quality_gate_status": "PASSED", "bugs": 0}
  }'
```

### Response

```json
{
  "decision": "PASS",
  "exit_code": 0,
  "reason": "All security and quality gates passed"
}
```

### Exit Codes

| Code | Decision | Description |
|------|----------|-------------|
| 0 | PASS | All gates passed |
| 1 | PASS_WITH_EXCEPTION | Passed with approved exceptions |
| 2 | BLOCKED | Gates failed, deployment blocked |

## Required Secrets

| Secret | Description |
|--------|-------------|
| `SNYK_TOKEN` | Snyk authentication |
| `SNYK_ORG_ID` | Snyk organization ID |
| `SONAR_TOKEN` | SonarQube Cloud token |
| `SONAR_ORGANIZATION` | SonarQube organization |
| `SONAR_PROJECT_KEY` | SonarQube project key |
| `POLICY_API_KEY` | Policy Management System API key (optional) |

## Self-Hosted Runner

The gate evaluation job requires a self-hosted runner with access to:
- Policy Management System at `http://localhost:8000`

Setup:
```bash
# In the actions-runner directory
./config.sh --url https://github.com/OWNER/REPO --token YOUR_TOKEN
./run.sh
```

## Local Development

### Prerequisites
- Policy Management System running locally (port 8000)
- Java 17, Maven 3.8+

### Commands
```bash
# Build the test application
cd microservice-moc-app && mvn clean package

# Run Snyk scan locally
snyk test --json > snyk-scanning/results/snyk-results.json

# Run SonarQube analysis
mvn sonar:sonar -Dsonar.token=$SONAR_TOKEN

# Test gate evaluation manually
curl -X POST http://localhost:8000/api/v1/pipeline/evaluate \
  -H "X-API-Key: dev-pipeline-key" \
  -H "Content-Type: application/json" \
  -d '{"repository": "test", "vulnerabilities": {"critical": 0}}'
```

## Related Repositories

- `poc-pipeline/policy-management-system` - Policy Management UI (FastAPI + Vue 3)
- `poc-pipeline/cicd-gating-policies` - Rego policies
- `poc-pipeline/cicd-pipeline-poc` - Reference CI/CD pipeline
