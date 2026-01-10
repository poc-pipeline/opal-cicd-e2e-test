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
│   │   └── generate-quality-summary/     # SonarQube report generation
│   └── workflows/
│       ├── e2e-pipeline.yml              # Main modular CI/CD pipeline
│       ├── build-application.yml         # Reusable build workflow
│       ├── security-scanning.yml         # Reusable Snyk workflow
│       ├── quality-analysis.yml          # Reusable SonarQube workflow
│       ├── docker-build.yml              # Reusable Docker workflow
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

1. **Build** (`build-application.yml`)
   - Maven compile and unit tests
   - Artifact upload for downstream jobs

2. **Security Scan** (`security-scanning.yml`)
   - Snyk vulnerability analysis
   - Container scanning (optional)
   - Results uploaded as artifacts

3. **Quality Analysis** (`quality-analysis.yml`)
   - SonarQube Cloud analysis
   - Quality gate evaluation
   - Results uploaded as artifacts

4. **Gate Evaluation** (runs on self-hosted runner)
   - Downloads scan results
   - Calls local Policy Management System API
   - Returns PASS/BLOCKED decision

5. **Docker Build** (`docker-build.yml`)
   - Only runs if gates pass
   - Creates container image

### Simple Test: `test-local-gates.yml`

For quick testing of gate evaluation with manual inputs:
- Runs on self-hosted runner
- Direct API call to Policy Management System
- Customizable vulnerability counts

## Key Components

### Test Application
- Spring Boot 3.1.5, Java 17
- Endpoints: `/api/hello`, `/api/status`, `/actuator/health`
- JaCoCo coverage with 50% threshold
- SonarQube integration

### Gate Evaluation API

The gate evaluation calls the local Policy Management System:

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

Response:
```json
{
  "decision": "PASS",
  "exit_code": 0,
  "reason": "All security and quality gates passed"
}
```

Exit codes:
- `0` = PASS
- `1` = WARNING (pass with conditions)
- `2` = BLOCKED

## Required Secrets

| Secret | Description |
|--------|-------------|
| `SNYK_TOKEN` | Snyk authentication |
| `SNYK_ORG_ID` | Snyk organization ID |
| `SONAR_TOKEN` | SonarQube Cloud token |
| `SONAR_ORGANIZATION` | SonarQube organization |
| `SONAR_PROJECT_KEY` | SonarQube project key |
| `POLICY_API_KEY` | Policy Management System API key (optional, defaults to dev-pipeline-key) |

## Self-Hosted Runner Setup

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
- Docker (for container builds)

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
