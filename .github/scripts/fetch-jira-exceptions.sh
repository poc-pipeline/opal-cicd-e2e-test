#!/bin/bash

# =============================================================================
# Jira Exception Fetcher for OPAL Security Gating
# =============================================================================
#
# Fetches approved security gate exceptions from Jira Cloud API.
# Returns exceptions in JSON format compatible with OPAL policy evaluation.
#
# Usage:
#   ./fetch-jira-exceptions.sh [OPTIONS]
#
# Options:
#   -a, --app-id       Application ID (repository name)
#   -g, --gate-id      Specific gate ID to query (optional, fetches all if omitted)
#   -o, --output       Output file path (default: stdout)
#   -v, --verbose      Enable verbose output
#   -h, --help         Show help message
#
# Environment Variables:
#   JIRA_BASE_URL      Jira Cloud URL (e.g., https://your-domain.atlassian.net)
#   JIRA_USER_EMAIL    Email for Jira authentication
#   JIRA_API_TOKEN     Jira API token
#   JIRA_PROJECT_KEY   Jira project key (default: GATES)
#
# Exit Codes:
#   0 - Success (exceptions found or no exceptions needed)
#   1 - Configuration error
#   2 - API error
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

JIRA_BASE_URL="${JIRA_BASE_URL:-}"
JIRA_USER_EMAIL="${JIRA_USER_EMAIL:-}"
JIRA_API_TOKEN="${JIRA_API_TOKEN:-}"
JIRA_PROJECT_KEY="${JIRA_PROJECT_KEY:-GATES}"

# Custom field names (configured for Jira GATES project)
CF_GATE_ID="${JIRA_CF_GATE_ID:-cf_gate_id}"
CF_APPLICATION_ID="${JIRA_CF_APPLICATION_ID:-cf_application_id}"
CF_APPROVAL_STATUS="${JIRA_CF_APPROVAL_STATUS:-cf_exception_approval_status}"
CF_APPROVAL_DECISION="${JIRA_CF_APPROVAL_DECISION:-cf_exception_approval_decision}"
CF_EXPIRY_DATE="${JIRA_CF_EXPIRY_DATE:-cf_exception_expiry_date}"

# Script defaults
APP_ID=""
GATE_ID=""
OUTPUT_FILE=""
VERBOSE=false

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_color() {
    if [ -t 1 ] || [ "$VERBOSE" = "true" ]; then
        echo -e "${1}${2}${NC}" >&2
    fi
}

log_info() {
    print_color "$CYAN" "[INFO] $1"
}

log_success() {
    print_color "$GREEN" "[OK] $1"
}

log_warning() {
    print_color "$YELLOW" "[WARN] $1"
}

log_error() {
    print_color "$RED" "[ERROR] $1"
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        print_color "$CYAN" "[DEBUG] $1"
    fi
}

show_help() {
    cat << 'EOF'
Jira Exception Fetcher for OPAL Security Gating

Usage:
  ./fetch-jira-exceptions.sh [OPTIONS]

Options:
  -a, --app-id       Application ID (repository name, e.g., org/repo-name)
  -g, --gate-id      Specific gate ID to query (optional)
  -o, --output       Output file path (default: stdout)
  -v, --verbose      Enable verbose output
  -h, --help         Show this help message

Environment Variables:
  JIRA_BASE_URL      Jira Cloud URL (required)
  JIRA_USER_EMAIL    Email for Jira authentication (required)
  JIRA_API_TOKEN     Jira API token (required)
  JIRA_PROJECT_KEY   Jira project key (default: GATES)

Examples:
  # Fetch all exceptions for an application
  ./fetch-jira-exceptions.sh -a "poc-pipeline/opal-cicd-e2e-test"

  # Fetch exceptions for specific gate
  ./fetch-jira-exceptions.sh -a "org/repo" -g "gatr-01"

  # Save to file
  ./fetch-jira-exceptions.sh -a "org/repo" -o /tmp/exceptions.json

EOF
    exit 0
}

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--app-id)
                APP_ID="$2"
                shift 2
                ;;
            -g|--gate-id)
                GATE_ID="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

validate_config() {
    local errors=0

    if [ -z "$JIRA_BASE_URL" ]; then
        log_error "JIRA_BASE_URL is not set"
        errors=$((errors + 1))
    fi

    if [ -z "$JIRA_USER_EMAIL" ]; then
        log_error "JIRA_USER_EMAIL is not set"
        errors=$((errors + 1))
    fi

    if [ -z "$JIRA_API_TOKEN" ]; then
        log_error "JIRA_API_TOKEN is not set"
        errors=$((errors + 1))
    fi

    if [ -z "$APP_ID" ]; then
        log_error "Application ID (-a) is required"
        errors=$((errors + 1))
    fi

    if [ $errors -gt 0 ]; then
        echo "Use --help for usage information" >&2
        exit 1
    fi

    log_verbose "Configuration validated"
    log_verbose "  Jira URL: $JIRA_BASE_URL"
    log_verbose "  Project: $JIRA_PROJECT_KEY"
    log_verbose "  App ID: $APP_ID"
    [ -n "$GATE_ID" ] && log_verbose "  Gate ID: $GATE_ID" || true
}

# -----------------------------------------------------------------------------
# Jira API Functions
# -----------------------------------------------------------------------------

jira_api_request() {
    local endpoint=$1
    local method=${2:-GET}
    local data=${3:-}

    local url="${JIRA_BASE_URL}${endpoint}"
    local auth=$(echo -n "${JIRA_USER_EMAIL}:${JIRA_API_TOKEN}" | base64 -w0)

    log_verbose "API Request: $method $url"

    local response
    local http_code

    if [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" \
            -X "$method" \
            -H "Authorization: Basic $auth" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url")
    else
        response=$(curl -s -w "\n%{http_code}" \
            -X "$method" \
            -H "Authorization: Basic $auth" \
            -H "Content-Type: application/json" \
            "$url")
    fi

    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')

    if [ "$http_code" -ge 400 ]; then
        log_error "API request failed with HTTP $http_code"
        log_verbose "Response: $response"
        return 2
    fi

    echo "$response"
}

test_connection() {
    log_info "Testing Jira API connection..."

    local result
    result=$(jira_api_request "/rest/api/3/myself") || {
        log_error "Failed to connect to Jira API"
        log_error "Check JIRA_BASE_URL, JIRA_USER_EMAIL, and JIRA_API_TOKEN"
        exit 2
    }

    local display_name
    display_name=$(echo "$result" | jq -r '.displayName // "Unknown"')
    log_success "Connected as: $display_name"
}

# -----------------------------------------------------------------------------
# Exception Fetching
# -----------------------------------------------------------------------------

build_jql_query() {
    local jql="project = \"${JIRA_PROJECT_KEY}\""

    # Add application filter
    jql="${jql} AND \"${CF_APPLICATION_ID}\" = \"${APP_ID}\""

    # Add approval filters
    jql="${jql} AND \"${CF_APPROVAL_STATUS}\" = \"DECISION MADE\""
    jql="${jql} AND \"${CF_APPROVAL_DECISION}\" = \"Approved\""

    # Add expiry date filter (not expired)
    jql="${jql} AND \"${CF_EXPIRY_DATE}\" >= now()"

    # Add specific gate filter if provided
    if [ -n "$GATE_ID" ]; then
        jql="${jql} AND \"${CF_GATE_ID}\" = \"${GATE_ID}\""
    fi

    echo "$jql"
}

fetch_exceptions() {
    log_info "Fetching exceptions from Jira..."

    local jql
    jql=$(build_jql_query)
    log_verbose "JQL: $jql"

    local endpoint="/rest/api/3/search/jql"

    local request_body
    request_body=$(jq -n \
        --arg jql "$jql" \
        '{
            jql: $jql,
            fields: ["key", "summary", "customfield_10113", "customfield_10114", "customfield_10115", "customfield_10116", "customfield_10117"],
            maxResults: 100
        }')

    local response
    response=$(jira_api_request "$endpoint" "POST" "$request_body") || {
        log_error "Failed to fetch exceptions"
        exit 2
    }

    local total
    total=$(echo "$response" | jq -r '.total // (.issues | length) // 0')
    log_info "Found $total exception(s)"

    echo "$response"
}

# -----------------------------------------------------------------------------
# Response Transformation
# -----------------------------------------------------------------------------

transform_to_opal_format() {
    local jira_response=$1

    log_verbose "Transforming Jira response to OPAL format..."

    local exceptions
    exceptions=$(echo "$jira_response" | jq --arg cf_gate "$CF_GATE_ID" \
        --arg cf_app "$CF_APPLICATION_ID" \
        --arg cf_status "$CF_APPROVAL_STATUS" \
        --arg cf_decision "$CF_APPROVAL_DECISION" \
        --arg cf_expiry "$CF_EXPIRY_DATE" '
        {
            exceptions: [
                .issues[]? | {
                    ticket_id: .key,
                    gate_id: (
                        .fields["customfield_10113"] //
                        .fields[$cf_gate] //
                        (.fields | to_entries | map(select(.key | startswith("customfield_"))) |
                         map(select(.value | type == "string" and startswith("gatr-"))) |
                         .[0].value // null)
                    ),
                    application_id: (
                        .fields["customfield_10114"] //
                        .fields[$cf_app] //
                        null
                    ),
                    approval_status: (
                        .fields["customfield_10115"].value //
                        .fields[$cf_status].value //
                        .fields[$cf_status] //
                        "DECISION MADE"
                    ),
                    approval_decision: (
                        .fields["customfield_10116"].value //
                        .fields[$cf_decision].value //
                        .fields[$cf_decision] //
                        "Approved"
                    ),
                    expiry_date: (
                        .fields["customfield_10117"] //
                        .fields[$cf_expiry] //
                        null
                    ),
                    summary: .fields.summary
                }
            ] | map(select(.gate_id != null and .expiry_date != null))
        }
    ')

    local count
    count=$(echo "$exceptions" | jq '.exceptions | length')
    log_success "Transformed $count valid exception(s)"

    echo "$exceptions"
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

main() {
    parse_args "$@"
    validate_config

    test_connection

    local jira_response
    jira_response=$(fetch_exceptions)

    local opal_exceptions
    opal_exceptions=$(transform_to_opal_format "$jira_response")

    if [ -n "$OUTPUT_FILE" ]; then
        echo "$opal_exceptions" | jq '.' > "$OUTPUT_FILE"
        log_success "Exceptions saved to: $OUTPUT_FILE"
    else
        echo "$opal_exceptions" | jq '.'
    fi

    local count
    count=$(echo "$opal_exceptions" | jq '.exceptions | length')
    if [ "$count" -eq 0 ]; then
        log_warning "No valid exceptions found for $APP_ID"
    else
        log_success "Found $count valid exception(s) for $APP_ID"
        if [ "$VERBOSE" = "true" ]; then
            echo "$opal_exceptions" | jq -r '.exceptions[] | "  - \(.ticket_id): \(.gate_id) (expires: \(.expiry_date))"' >&2
        fi
    fi
}

main "$@"
