# =============================================================================
# OPAL CI/CD E2E Test Repository - Makefile
# =============================================================================
#
# Commands for local development and testing.
#
# Usage:
#   make build         - Build test application
#   make start-stack   - Start full Policy Management Stack
#   make stop-stack    - Stop all services
#   make evaluate      - Run gate evaluation manually
#   make test          - Run unit tests
#   make clean         - Clean build artifacts
#
# =============================================================================

.PHONY: build build-docker start-stack stop-stack evaluate test clean help

# Default target
.DEFAULT_GOAL := help

# Variables
MAVEN_OPTS ?= -B -q
DOCKER_TAG ?= latest
COMPOSE_FILE := policy-management-stack/docker-compose.yml

# =============================================================================
# Build Targets
# =============================================================================

## Build the test application with Maven
build:
	@echo "Building test application..."
	cd test-app && mvn clean package -DskipTests $(MAVEN_OPTS)
	@echo "Build completed successfully"

## Build Docker image for test application
build-docker: build
	@echo "Building Docker image..."
	cd test-app && docker build -t e2e-test-app:$(DOCKER_TAG) .
	@echo "Docker image built: e2e-test-app:$(DOCKER_TAG)"

# =============================================================================
# Test Targets
# =============================================================================

## Run unit tests with JaCoCo coverage
test:
	@echo "Running unit tests..."
	cd test-app && mvn test jacoco:report $(MAVEN_OPTS)
	@echo "Tests completed. Coverage report: test-app/target/site/jacoco/index.html"

## Run SonarQube analysis (requires SONAR_TOKEN)
sonar:
	@echo "Running SonarQube analysis..."
	cd test-app && mvn sonar:sonar $(MAVEN_OPTS)

# =============================================================================
# Stack Management
# =============================================================================

## Start the full Policy Management Stack
start-stack: build-docker
	@echo "Starting Policy Management Stack..."
	docker compose -f $(COMPOSE_FILE) up -d
	@echo ""
	@echo "Waiting for services to start (45 seconds)..."
	@sleep 45
	@echo ""
	@echo "Services are starting up:"
	@echo "  - Test Application:      http://localhost:8080"
	@echo "  - OPA Policy Engine:     http://localhost:8181"
	@echo "  - Policy Management API: http://localhost:8000"
	@echo "  - Policy Management UI:  http://localhost:3000"
	@echo ""
	@echo "Run 'make health' to check service status"

## Stop the Policy Management Stack
stop-stack:
	@echo "Stopping Policy Management Stack..."
	docker compose -f $(COMPOSE_FILE) down
	@echo "Stack stopped"

## Check health of all services
health:
	@echo "Checking service health..."
	@echo ""
	@echo "Test Application:"
	@curl -sf http://localhost:8080/actuator/health | jq '.' || echo "  NOT AVAILABLE"
	@echo ""
	@echo "OPA Policy Engine:"
	@curl -sf http://localhost:8181/health || echo "  NOT AVAILABLE"
	@echo ""
	@echo "Policy Management API:"
	@curl -sf http://localhost:8000/api/v1/health | jq '.' || echo "  NOT AVAILABLE"
	@echo ""
	@echo "Policy Management UI:"
	@curl -sf http://localhost:3000 > /dev/null && echo "  AVAILABLE" || echo "  NOT AVAILABLE"

## Show service logs
logs:
	docker compose -f $(COMPOSE_FILE) logs -f

## Show OPA logs only
logs-opa:
	docker compose -f $(COMPOSE_FILE) logs -f opa

# =============================================================================
# Gate Evaluation
# =============================================================================

## Run gate evaluation manually (requires OPA to be running)
evaluate:
	@echo "Running gate evaluation..."
	chmod +x .github/scripts/evaluate-gates.sh
	DEBUG=true ./.github/scripts/evaluate-gates.sh \
		snyk-scanning/results/snyk-results.json \
		sonarqube-cloud-scanning/results/quality-gate-result.json

## Test OPA policy with sample input
test-opa:
	@echo "Testing OPA policy evaluation..."
	curl -s -X POST \
		-H "Content-Type: application/json" \
		-d '{"input":{"user":{"key":"test-user"},"action":"deploy","resource":{"type":"deployment","key":"test","attributes":{"vulnerabilities":{"critical":0,"high":0,"medium":0,"low":0},"quality":{"quality_gate":{"status":"OK"}}}},"context":{"jira_exceptions":[]}}}' \
		http://localhost:8181/v1/data/cicd/gating/evaluation_response | jq '.'

## List loaded OPA policies
list-policies:
	@echo "Loaded OPA policies:"
	@curl -sf http://localhost:8181/v1/policies | jq '.result | length'
	@curl -sf http://localhost:8181/v1/policies | jq -r '.result[].id'

# =============================================================================
# Cleanup
# =============================================================================

## Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	cd test-app && mvn clean $(MAVEN_OPTS)
	rm -f docker-image.tar
	@echo "Cleanup completed"

## Deep clean including Docker images and volumes
clean-all: clean stop-stack
	@echo "Removing Docker images and volumes..."
	docker rmi e2e-test-app:$(DOCKER_TAG) 2>/dev/null || true
	docker volume rm policy-management-stack_policies 2>/dev/null || true
	docker volume rm policy-management-stack_data 2>/dev/null || true
	docker volume rm policy-management-stack_api-data 2>/dev/null || true
	@echo "Deep cleanup completed"

# =============================================================================
# Setup
# =============================================================================

## Create test fixture files
setup-fixtures:
	@echo "Creating test fixture directories..."
	mkdir -p snyk-scanning/results
	mkdir -p sonarqube-cloud-scanning/results
	@echo '{"vulnerabilities":[],"ok":true}' > snyk-scanning/results/snyk-results.json
	@echo '{"projectStatus":{"status":"OK"}}' > sonarqube-cloud-scanning/results/quality-gate-result.json
	@echo "Test fixtures created"

# =============================================================================
# Help
# =============================================================================

## Show this help message
help:
	@echo ""
	@echo "OPAL CI/CD E2E Test Repository"
	@echo "=============================="
	@echo ""
	@echo "Available targets:"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
