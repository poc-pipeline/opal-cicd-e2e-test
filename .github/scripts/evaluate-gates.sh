#!/bin/bash
# =============================================================================
# Gate Evaluation Script
# =============================================================================
# Parses scan results and evaluates them via the Policy Management System API.
#
# Usage:
#   ./evaluate-gates.sh <snyk-results.json> <sonarqube-results.json>
#
# Environment Variables:
#   API_URL        - Policy Management System URL (default: http://localhost:8000)
#   API_KEY        - API key for authentication (default: dev-pipeline-key)
#   DEBUG          - Set to 'true' for verbose output
#   REPOSITORY     - Repository name (default: local/test)
#   BRANCH         - Branch name (default: main)
# =============================================================================

set -e

# Configuration
API_URL="${API_URL:-http://localhost:8000}"
API_KEY="${API_KEY:-dev-pipeline-key}"
REPOSITORY="${REPOSITORY:-local/test}"
BRANCH="${BRANCH:-main}"
COMMIT="${COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo 'local')}"
USER="${USER:-local-user}"

# Input files
SNYK_RESULTS="${1:-snyk-scanning/results/snyk-results.json}"
SONARQUBE_RESULTS="${2:-sonarqube-cloud-scanning/results/quality-gate-result.json}"

# Debug output
debug() {
    if [ "${DEBUG}" = "true" ]; then
        echo "[DEBUG] $*"
    fi
}

echo "========================================"
echo "  Gate Evaluation"
echo "========================================"
echo ""

# -----------------------------------------------------------------------------
# Parse Snyk Results
# -----------------------------------------------------------------------------
echo "Parsing security scan results..."

if [ -f "$SNYK_RESULTS" ]; then
    debug "Found Snyk results at $SNYK_RESULTS"
    CRITICAL=$(jq '[.vulnerabilities[]? | select(.severity == "critical")] | length' "$SNYK_RESULTS" 2>/dev/null || echo "0")
    HIGH=$(jq '[.vulnerabilities[]? | select(.severity == "high")] | length' "$SNYK_RESULTS" 2>/dev/null || echo "0")
    MEDIUM=$(jq '[.vulnerabilities[]? | select(.severity == "medium")] | length' "$SNYK_RESULTS" 2>/dev/null || echo "0")
    LOW=$(jq '[.vulnerabilities[]? | select(.severity == "low")] | length' "$SNYK_RESULTS" 2>/dev/null || echo "0")
else
    echo "WARNING: Snyk results not found at $SNYK_RESULTS"
    CRITICAL=0
    HIGH=0
    MEDIUM=0
    LOW=0
fi

echo "  Vulnerabilities:"
echo "    Critical: $CRITICAL"
echo "    High:     $HIGH"
echo "    Medium:   $MEDIUM"
echo "    Low:      $LOW"
echo ""

# -----------------------------------------------------------------------------
# Parse SonarQube Results
# -----------------------------------------------------------------------------
echo "Parsing quality scan results..."

if [ -f "$SONARQUBE_RESULTS" ]; then
    debug "Found SonarQube results at $SONARQUBE_RESULTS"
    QG_STATUS=$(jq -r '.quality_gate.status // "UNKNOWN"' "$SONARQUBE_RESULTS" 2>/dev/null || echo "UNKNOWN")
    BUGS=$(jq -r '.metrics.bugs // 0' "$SONARQUBE_RESULTS" 2>/dev/null || echo "0")
    CODE_SMELLS=$(jq -r '.metrics.code_smells // 0' "$SONARQUBE_RESULTS" 2>/dev/null || echo "0")
    COVERAGE=$(jq -r '.metrics.coverage // 0' "$SONARQUBE_RESULTS" 2>/dev/null || echo "0")
    SECURITY_RATING=$(jq -r '.metrics.ratings.security // "Unknown"' "$SONARQUBE_RESULTS" 2>/dev/null || echo "Unknown")
    RELIABILITY_RATING=$(jq -r '.metrics.ratings.reliability // "Unknown"' "$SONARQUBE_RESULTS" 2>/dev/null || echo "Unknown")
else
    echo "WARNING: SonarQube results not found at $SONARQUBE_RESULTS"
    QG_STATUS="UNKNOWN"
    BUGS=0
    CODE_SMELLS=0
    COVERAGE=0
    SECURITY_RATING="Unknown"
    RELIABILITY_RATING="Unknown"
fi

echo "  Quality Gate: $QG_STATUS"
echo "  Bugs:         $BUGS"
echo "  Code Smells:  $CODE_SMELLS"
echo "  Coverage:     $COVERAGE%"
echo "  Security:     $SECURITY_RATING"
echo "  Reliability:  $RELIABILITY_RATING"
echo ""

# -----------------------------------------------------------------------------
# Check API Health
# -----------------------------------------------------------------------------
echo "Checking Policy Management System health..."

for i in {1..5}; do
    if curl -sf "${API_URL}/health" > /dev/null 2>&1; then
        echo "  Policy Management System is healthy"
        break
    fi
    if [ $i -eq 5 ]; then
        echo "ERROR: Policy Management System is not reachable at ${API_URL}"
        echo "Make sure the Policy Management System is running (make start-stack)"
        exit 1
    fi
    debug "Attempt $i/5: Waiting for Policy Management System..."
    sleep 2
done
echo ""

# -----------------------------------------------------------------------------
# Call Policy Management System API
# -----------------------------------------------------------------------------
echo "Evaluating gates via Policy Management System..."
debug "API URL: ${API_URL}/api/v1/pipeline/evaluate"

PAYLOAD=$(cat <<EOF
{
  "repository": "${REPOSITORY}",
  "branch": "${BRANCH}",
  "commit": "${COMMIT}",
  "user": "${USER}",
  "environment": "development",
  "vulnerabilities": {
    "critical": ${CRITICAL},
    "high": ${HIGH},
    "medium": ${MEDIUM},
    "low": ${LOW}
  },
  "quality": {
    "status": "${QG_STATUS}",
    "security_rating": "${SECURITY_RATING}",
    "reliability_rating": "${RELIABILITY_RATING}",
    "coverage": ${COVERAGE}
  }
}
EOF
)

debug "Request payload:"
if [ "${DEBUG}" = "true" ]; then
    echo "$PAYLOAD" | jq .
fi

RESPONSE=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -H "X-API-Key: ${API_KEY}" \
    -d "$PAYLOAD" \
    "${API_URL}/api/v1/pipeline/evaluate" 2>&1) || {
        echo "ERROR: API call failed"
        echo "Response: $RESPONSE"
        exit 1
    }

debug "API Response:"
if [ "${DEBUG}" = "true" ]; then
    echo "$RESPONSE" | jq .
fi

# -----------------------------------------------------------------------------
# Process Response
# -----------------------------------------------------------------------------
DECISION=$(echo "$RESPONSE" | jq -r '.decision // "UNKNOWN"')
EXIT_CODE=$(echo "$RESPONSE" | jq -r '.exit_code // 1')
REASON=$(echo "$RESPONSE" | jq -r '.summary // .reason // "No reason provided"')
AUDIT_ID=$(echo "$RESPONSE" | jq -r '.audit_id // "N/A"')

echo ""
echo "========================================"
echo "  Gate Evaluation Result"
echo "========================================"
echo ""
echo "  Decision:  $DECISION"
echo "  Exit Code: $EXIT_CODE"
echo "  Reason:    $REASON"
echo "  Audit ID:  $AUDIT_ID"
echo ""
echo "========================================"

# -----------------------------------------------------------------------------
# Exit Based on Decision
# -----------------------------------------------------------------------------
case "$EXIT_CODE" in
    0)
        echo ""
        echo "PASS - Deployment authorized"
        exit 0
        ;;
    1)
        echo ""
        echo "WARNING - Non-blocking issues detected"
        echo "Pipeline continues but issues should be addressed"
        exit 0
        ;;
    2)
        echo ""
        echo "BLOCKED - Deployment not authorized"
        echo "Create a Jira exception ticket to bypass this gate"
        exit 1
        ;;
    *)
        echo ""
        echo "Unknown exit code: $EXIT_CODE"
        exit 1
        ;;
esac
