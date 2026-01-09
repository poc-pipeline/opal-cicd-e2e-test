#!/bin/bash

# =============================================================================
# OPAL-Based CI/CD Security Gate Evaluation Script
# =============================================================================
#
# Evaluates security and quality gates using OPA via OPAL.
# This is the main script for gate evaluation in CI/CD pipelines.
#
# Exit codes:
#   0 - All gates passed (or passed with approved Jira exception)
#   1 - Soft gate warning (non-blocking issues detected)
#   2 - Hard gate failure (blocking, requires Jira exception)
#
# Usage:
#   ./evaluate-gates.sh [SNYK_RESULTS_FILE] [SONARQUBE_RESULTS_FILE] [JIRA_EXCEPTIONS_FILE]
#
# Environment Variables:
#   OPA_URL          - OPA REST API URL (default: http://localhost:8181)
#   USER_KEY         - GitHub actor username
#   DEBUG            - Enable debug output (true/false)
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

OPA_URL="${OPA_URL:-http://localhost:8181}"
SNYK_RESULTS_FILE="${1:-snyk-scanning/results/snyk-results.json}"
SONARQUBE_RESULTS_FILE="${2:-sonarqube-cloud-scanning/results/quality-gate-result.json}"
JIRA_EXCEPTIONS_FILE="${3:-}"

USER_KEY="${USER_KEY:-${GITHUB_ACTOR:-local-user}}"
DEBUG="${DEBUG:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Colors and Output Formatting
# -----------------------------------------------------------------------------

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

print_header() {
    echo ""
    print_color "$BLUE" "================================================================"
    print_color "$BLUE" "  $1"
    print_color "$BLUE" "================================================================"
}

print_section() {
    echo ""
    print_color "$CYAN" "-- $1 --"
}

debug_log() {
    if [ "$DEBUG" = "true" ]; then
        print_color "$YELLOW" "[DEBUG] $1" >&2
    fi
}

# -----------------------------------------------------------------------------
# Health Check Functions
# -----------------------------------------------------------------------------

check_opa_ready() {
    local max_attempts=30
    local attempt=1
    local wait_times=(2 2 4 4 8 8 15 15 30 30)

    print_section "Checking OPA Readiness"

    while [ $attempt -le $max_attempts ]; do
        if curl -sf "${OPA_URL}/health" > /dev/null 2>&1; then
            print_color "$GREEN" "OPA is ready"
            return 0
        fi

        local wait_time=${wait_times[$((attempt - 1))]}
        wait_time=${wait_time:-30}

        debug_log "Attempt $attempt/$max_attempts: OPA not ready, waiting ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
    done

    print_color "$RED" "OPA failed to become ready after $max_attempts attempts"
    return 1
}

# -----------------------------------------------------------------------------
# Data Parsing Functions
# -----------------------------------------------------------------------------

parse_snyk_results() {
    local results_file=$1

    if [ ! -f "$results_file" ]; then
        print_color "$YELLOW" "Snyk results not found: $results_file"
        echo '{"critical": 0, "high": 0, "medium": 0, "low": 0}'
        return
    fi

    debug_log "Parsing Snyk results from: $results_file"

    local critical=$(jq '[.vulnerabilities[]? | select(.severity == "critical")] | length // 0' "$results_file" 2>/dev/null || echo 0)
    local high=$(jq '[.vulnerabilities[]? | select(.severity == "high")] | length // 0' "$results_file" 2>/dev/null || echo 0)
    local medium=$(jq '[.vulnerabilities[]? | select(.severity == "medium")] | length // 0' "$results_file" 2>/dev/null || echo 0)
    local low=$(jq '[.vulnerabilities[]? | select(.severity == "low")] | length // 0' "$results_file" 2>/dev/null || echo 0)

    echo "{\"critical\": $critical, \"high\": $high, \"medium\": $medium, \"low\": $low}"
}

parse_sonarqube_results() {
    local results_file=$1

    if [ ! -f "$results_file" ]; then
        print_color "$YELLOW" "SonarQube results not found: $results_file"
        echo '{"quality_gate": {"status": "UNKNOWN"}, "metrics": {}}'
        return
    fi

    debug_log "Parsing SonarQube results from: $results_file"
    cat "$results_file"
}

parse_jira_exceptions() {
    local results_file=$1

    if [ -z "$results_file" ] || [ ! -f "$results_file" ]; then
        debug_log "No Jira exceptions file provided"
        echo '[]'
        return
    fi

    debug_log "Parsing Jira exceptions from: $results_file"
    jq '.exceptions // []' "$results_file" 2>/dev/null || echo '[]'
}

# -----------------------------------------------------------------------------
# OPA Input Creation
# -----------------------------------------------------------------------------

create_opa_input() {
    local vuln_data=$1
    local quality_data=$2
    local jira_exceptions=$3

    local repository="${GITHUB_REPOSITORY:-unknown}"
    local commit="${GITHUB_SHA:-unknown}"
    local environment="${GITHUB_REF_NAME:-development}"
    local workflow="${GITHUB_WORKFLOW:-manual}"

    cat <<EOF
{
    "input": {
        "user": {
            "key": "$USER_KEY"
        },
        "action": "deploy",
        "resource": {
            "type": "deployment",
            "key": "$(date +%s)-$(head /dev/urandom | tr -dc a-z0-9 | head -c 8 2>/dev/null || echo 'local')",
            "attributes": {
                "vulnerabilities": $vuln_data,
                "quality": $quality_data
            }
        },
        "context": {
            "environment": "$environment",
            "repository": "$repository",
            "commit": "$commit",
            "workflow": "$workflow",
            "jira_exceptions": $jira_exceptions
        }
    }
}
EOF
}

# -----------------------------------------------------------------------------
# OPA Policy Evaluation
# -----------------------------------------------------------------------------

evaluate_policy() {
    local input=$1

    debug_log "Evaluating policy via OPA..."

    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$input" \
        "${OPA_URL}/v1/data/cicd/gating/evaluation_response")

    if [ -z "$response" ]; then
        print_color "$RED" "Empty response from OPA"
        return 1
    fi

    echo "$response"
}

# -----------------------------------------------------------------------------
# Results Processing and Display
# -----------------------------------------------------------------------------

display_results() {
    local response=$1

    local allow=$(echo "$response" | jq -r '.result.allow // false')
    local decision=$(echo "$response" | jq -r '.result.decision // "UNKNOWN"')
    local exit_code=$(echo "$response" | jq -r '.result.exit_code // 2')

    print_header "OPAL GATE EVALUATION RESULTS"

    # User Context
    print_section "User Context"
    echo "  User:        $USER_KEY"
    echo "  Role:        developer (all users)"

    # Vulnerability Summary
    print_section "Vulnerability Summary"
    echo "$response" | jq -r '.result.gates.security.summary // {} |
        "  Critical:    \(.critical // 0)\n  High:        \(.high // 0)\n  Medium:      \(.medium // 0)\n  Low:         \(.low // 0)"'

    # Security Gates
    print_section "Security Gates"
    echo "$response" | jq -r '.result.gates.security.all_gates // [] | .[] |
        "  \(.gate_id): \(if .exceeded then "EXCEEDED \(.status)" else "PASSED" end) (\(.vulnerability_count)/\(.threshold))"'

    # Quality Gates
    print_section "Quality Gates"
    local qg_status=$(echo "$response" | jq -r '.result.gates.quality.sonarqube_status // "UNKNOWN"')
    echo "  SonarQube Status: $qg_status"
    echo "$response" | jq -r '.result.gates.quality.all_gates // [] | .[] |
        "  \(.gate_id): \(if .exceeded then "EXCEEDED \(.status)" else "PASSED" end)"'

    # Jira Exception Status
    print_section "Jira Exception Status"
    local has_exception=$(echo "$response" | jq -r '.result.exception.has_exception // false')
    if [ "$has_exception" = "true" ]; then
        local ticket=$(echo "$response" | jq -r '.result.exception.ticket // "N/A"')
        local expiry=$(echo "$response" | jq -r '.result.exception.expiry // "N/A"')
        print_color "$GREEN" "  Valid exception found"
        echo "  Ticket:      $ticket"
        echo "  Expiry:      $expiry"
    else
        print_color "$YELLOW" "  No valid exception"
    fi

    # Final Decision
    print_section "Final Decision"
    case "$decision" in
        "PASS")
            print_color "$GREEN" "  PASS - All gates passed"
            ;;
        "PASS_WITH_EXCEPTION")
            print_color "$GREEN" "  PASS WITH EXCEPTION - Blocked gates bypassed via Jira"
            ;;
        "WARNING")
            print_color "$YELLOW" "  WARNING - Non-blocking issues detected"
            ;;
        "BLOCKED")
            print_color "$RED" "  BLOCKED - Enforcing gates failed"
            print_color "$RED" "    -> Create Jira exception to bypass"
            ;;
        *)
            print_color "$RED" "  UNKNOWN - Unexpected decision"
            ;;
    esac

    echo ""
    print_color "$BLUE" "================================================================"

    return $exit_code
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

main() {
    print_header "OPAL Gate Evaluation"
    echo "  Started at: $(date -Iseconds)"

    check_opa_ready || exit 2

    print_section "Parsing Scan Results"
    local vuln_data=$(parse_snyk_results "$SNYK_RESULTS_FILE")
    print_color "$GREEN" "Security scan results parsed"

    local quality_data=$(parse_sonarqube_results "$SONARQUBE_RESULTS_FILE")
    print_color "$GREEN" "Quality gate results parsed"

    local jira_exceptions=$(parse_jira_exceptions "$JIRA_EXCEPTIONS_FILE")
    debug_log "Jira exceptions: $jira_exceptions"

    local opa_input=$(create_opa_input "$vuln_data" "$quality_data" "$jira_exceptions")

    if [ "$DEBUG" = "true" ]; then
        print_section "OPA Input (Debug)"
        echo "$opa_input" | jq '.'
    fi

    echo "$opa_input" > /tmp/opa-input.json

    local opa_response=$(evaluate_policy "$opa_input")

    if [ "$DEBUG" = "true" ]; then
        print_section "OPA Response (Debug)"
        echo "$opa_response" | jq '.'
    fi

    display_results "$opa_response"
    local exit_code=$?

    echo "  Completed at: $(date -Iseconds)"

    exit $exit_code
}

main "$@"
