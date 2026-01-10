#!/bin/bash

# Snyk OAuth 2.0 Local Testing Script
# This script tests Snyk security scanning locally using OAuth 2.0 authentication
#
# Reference: https://docs.snyk.io/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo ""
    print_color "$BLUE" "================================================================"
    print_color "$BLUE" "           SNYK OAUTH 2.0 LOCAL TEST RUNNER"
    print_color "$BLUE" "================================================================"
    echo ""
}

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OAUTH_CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$OAUTH_CONFIG_DIR/../.." && pwd)"
RESULTS_DIR="$OAUTH_CONFIG_DIR/results"

# Regional endpoints
declare -A OAUTH_ENDPOINTS=(
    ["us"]="https://api.snyk.io/oauth2/token"
    ["eu"]="https://api.eu.snyk.io/oauth2/token"
    ["au"]="https://api.au.snyk.io/oauth2/token"
)

# Global variables
OAUTH_ACCESS_TOKEN=""
TOKEN_EXPIRES_IN=""
TOKEN_ACQUIRED_AT=""
SCAN_EXIT_CODE=0

# Load environment variables
load_environment() {
    print_color "$CYAN" "Step 1: Loading environment variables..."

    # Look for .env file in multiple possible locations
    local env_files=(
        "$OAUTH_CONFIG_DIR/.env.oauth"
        "$PROJECT_ROOT/.env"
        ".env.oauth"
        ".env"
    )

    local loaded=false
    for env_file in "${env_files[@]}"; do
        if [ -f "$env_file" ]; then
            print_color "$GREEN" "  Found: $env_file"
            set -a
            source "$env_file"
            set +a
            loaded=true
            break
        fi
    done

    if [ "$loaded" = false ]; then
        if [ -n "$SNYK_CLIENT_ID" ] && [ -n "$SNYK_CLIENT_SECRET" ]; then
            print_color "$GREEN" "  Using environment variables (CI mode)"
        else
            print_color "$RED" "  No .env file found and OAuth credentials not set"
            echo "Please set SNYK_CLIENT_ID and SNYK_CLIENT_SECRET"
            exit 1
        fi
    fi

    # Set default region
    SNYK_REGION="${SNYK_REGION:-us}"

    # Ensure results directory exists
    mkdir -p "$RESULTS_DIR"
}

# Validate configuration by calling validate script
validate_configuration() {
    print_color "$CYAN" "Step 2: Validating OAuth configuration..."

    chmod +x "$SCRIPT_DIR/validate-snyk-oauth.sh"

    # Run validation script (it will exit on failure)
    "$SCRIPT_DIR/validate-snyk-oauth.sh"

    if [ $? -eq 0 ]; then
        print_color "$GREEN" "  Configuration validation passed"
    else
        print_color "$RED" "  Configuration validation failed"
        exit 1
    fi
}

# Acquire OAuth token
acquire_oauth_token() {
    print_color "$CYAN" "Step 3: Acquiring fresh OAuth token..."

    local region="${SNYK_REGION:-us}"
    region=$(echo "$region" | tr '[:upper:]' '[:lower:]')
    local oauth_endpoint="${OAUTH_ENDPOINTS[$region]:-https://api.snyk.io/oauth2/token}"

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "$oauth_endpoint" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -d "client_id=$SNYK_CLIENT_ID" \
        -d "client_secret=$SNYK_CLIENT_SECRET")

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        OAUTH_ACCESS_TOKEN=$(echo "$body" | jq -r '.access_token // empty')
        TOKEN_EXPIRES_IN=$(echo "$body" | jq -r '.expires_in // empty')
        TOKEN_ACQUIRED_AT=$(date +%s)

        if [ -n "$OAUTH_ACCESS_TOKEN" ]; then
            export SNYK_OAUTH_TOKEN="$OAUTH_ACCESS_TOKEN"
            print_color "$GREEN" "  Token acquired (expires in ${TOKEN_EXPIRES_IN}s)"
            return 0
        fi
    fi

    print_color "$RED" "  Failed to acquire OAuth token (HTTP $http_code)"
    return 1
}

# Check if token needs refresh
check_token_expiry() {
    if [ -z "$TOKEN_ACQUIRED_AT" ] || [ -z "$TOKEN_EXPIRES_IN" ]; then
        return 1  # Need new token
    fi

    local current_time=$(date +%s)
    local elapsed=$((current_time - TOKEN_ACQUIRED_AT))
    local remaining=$((TOKEN_EXPIRES_IN - elapsed))

    # Refresh if less than 5 minutes remaining
    if [ $remaining -lt 300 ]; then
        return 1  # Need refresh
    fi

    return 0  # Token still valid
}

# Refresh token if needed
refresh_token_if_needed() {
    if ! check_token_expiry; then
        print_color "$YELLOW" "  Token expired or expiring soon, refreshing..."
        acquire_oauth_token
    fi
}

# Setup Snyk CLI
setup_snyk_cli() {
    print_color "$CYAN" "Step 4: Setting up Snyk CLI..."

    if command -v snyk &> /dev/null; then
        local version=$(snyk --version 2>/dev/null || echo "unknown")
        print_color "$GREEN" "  Snyk CLI found (version: $version)"
    else
        print_color "$YELLOW" "  Snyk CLI not found, installing..."

        if command -v npm &> /dev/null; then
            npm install -g snyk
            print_color "$GREEN" "  Snyk CLI installed successfully"
        else
            print_color "$RED" "  Cannot install Snyk CLI (npm not found)"
            echo "  Please install Snyk CLI manually: npm install -g snyk"
            exit 1
        fi
    fi
}

# Build project (if needed)
build_project() {
    print_color "$CYAN" "Step 5: Building project for analysis..."

    local app_dir="$PROJECT_ROOT/microservice-moc-app"

    if [ -f "$app_dir/pom.xml" ]; then
        print_color "$YELLOW" "  Maven project detected"

        cd "$app_dir"

        # Check if compiled classes exist
        if [ -d "target/classes" ] && [ "$(ls -A target/classes 2>/dev/null)" ]; then
            print_color "$GREEN" "  Compiled classes already exist"
        else
            print_color "$YELLOW" "  Compiling project..."
            mvn clean compile -DskipTests -q
            print_color "$GREEN" "  Project compiled successfully"
        fi

        cd "$PROJECT_ROOT"
    else
        print_color "$YELLOW" "  No Maven project found, skipping build"
    fi
}

# Run Snyk security scan
run_snyk_scan() {
    print_color "$CYAN" "Step 6: Running Snyk security scan with OAuth..."

    local app_dir="$PROJECT_ROOT/microservice-moc-app"

    if [ ! -d "$app_dir" ]; then
        print_color "$YELLOW" "  microservice-moc-app directory not found"
        print_color "$YELLOW" "  Running scan on project root instead"
        app_dir="$PROJECT_ROOT"
    fi

    cd "$app_dir"

    # Refresh token if needed before long operation
    refresh_token_if_needed

    print_color "$YELLOW" "  Running vulnerability scan..."

    # Output files
    local json_output="$RESULTS_DIR/snyk-oauth-results.json"
    local sarif_output="$RESULTS_DIR/snyk-oauth-results.sarif"
    local log_output="$RESULTS_DIR/scan.log"

    # Run Snyk test with OAuth token
    set +e
    SNYK_OAUTH_TOKEN="$OAUTH_ACCESS_TOKEN" snyk test \
        --json-file-output="$json_output" \
        --sarif-file-output="$sarif_output" \
        2>&1 | tee "$log_output"

    SCAN_EXIT_CODE=$?
    set -e

    # Check for token expiry during scan
    if grep -q "401\|Unauthorized\|invalid_token" "$log_output" 2>/dev/null; then
        print_color "$YELLOW" "  Token may have expired during scan, retrying..."
        acquire_oauth_token

        set +e
        SNYK_OAUTH_TOKEN="$OAUTH_ACCESS_TOKEN" snyk test \
            --json-file-output="$json_output" \
            --sarif-file-output="$sarif_output" \
            2>&1 | tee "$log_output"

        SCAN_EXIT_CODE=$?
        set -e
    fi

    cd "$PROJECT_ROOT"

    # Interpret exit code
    case $SCAN_EXIT_CODE in
        0)
            print_color "$GREEN" "  Scan completed: No vulnerabilities found"
            ;;
        1)
            print_color "$YELLOW" "  Scan completed: Vulnerabilities found"
            ;;
        2)
            print_color "$RED" "  Scan error: Check log for details"
            ;;
        3)
            print_color "$RED" "  No supported projects detected"
            ;;
        *)
            print_color "$YELLOW" "  Scan completed with exit code: $SCAN_EXIT_CODE"
            ;;
    esac
}

# Run Snyk code analysis
run_snyk_code_analysis() {
    print_color "$CYAN" "Step 7: Running Snyk code analysis (SAST)..."

    local app_dir="$PROJECT_ROOT/microservice-moc-app"

    if [ ! -d "$app_dir" ]; then
        app_dir="$PROJECT_ROOT"
    fi

    cd "$app_dir"

    # Refresh token if needed
    refresh_token_if_needed

    local code_json="$RESULTS_DIR/snyk-oauth-code-results.json"
    local code_sarif="$RESULTS_DIR/snyk-oauth-code-results.sarif"

    print_color "$YELLOW" "  Running code analysis..."

    set +e
    SNYK_OAUTH_TOKEN="$OAUTH_ACCESS_TOKEN" snyk code test \
        --json-file-output="$code_json" \
        --sarif-file-output="$code_sarif" \
        2>&1 | tee "$RESULTS_DIR/code-scan.log"

    local code_exit=$?
    set -e

    cd "$PROJECT_ROOT"

    case $code_exit in
        0)
            print_color "$GREEN" "  Code analysis completed: No issues found"
            ;;
        1)
            print_color "$YELLOW" "  Code analysis completed: Issues found"
            ;;
        *)
            print_color "$YELLOW" "  Code analysis completed with exit code: $code_exit"
            ;;
    esac
}

# Parse and analyze results
analyze_results() {
    print_color "$CYAN" "Step 8: Analyzing scan results..."

    local json_output="$RESULTS_DIR/snyk-oauth-results.json"

    if [ -f "$json_output" ]; then
        # Parse vulnerability counts
        local total=$(jq '.vulnerabilities | length // 0' "$json_output" 2>/dev/null || echo "0")
        local critical=$(jq '[.vulnerabilities[] | select(.severity == "critical")] | length' "$json_output" 2>/dev/null || echo "0")
        local high=$(jq '[.vulnerabilities[] | select(.severity == "high")] | length' "$json_output" 2>/dev/null || echo "0")
        local medium=$(jq '[.vulnerabilities[] | select(.severity == "medium")] | length' "$json_output" 2>/dev/null || echo "0")
        local low=$(jq '[.vulnerabilities[] | select(.severity == "low")] | length' "$json_output" 2>/dev/null || echo "0")

        print_color "$CYAN" "  Vulnerability Summary:"
        echo "    Total: $total"
        [ "$critical" -gt 0 ] && print_color "$RED" "    Critical: $critical"
        [ "$high" -gt 0 ] && print_color "$RED" "    High: $high"
        [ "$medium" -gt 0 ] && print_color "$YELLOW" "    Medium: $medium"
        [ "$low" -gt 0 ] && print_color "$GREEN" "    Low: $low"

        # Create summary JSON
        jq '{
            scan_type: "oauth",
            timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            summary: {
                total: (.vulnerabilities | length),
                critical: [.vulnerabilities[] | select(.severity == "critical")] | length,
                high: [.vulnerabilities[] | select(.severity == "high")] | length,
                medium: [.vulnerabilities[] | select(.severity == "medium")] | length,
                low: [.vulnerabilities[] | select(.severity == "low")] | length
            },
            top_vulnerabilities: [.vulnerabilities[:5] | .[] | {
                id: .id,
                severity: .severity,
                title: .title,
                package: .packageName,
                version: .version
            }]
        }' "$json_output" > "$RESULTS_DIR/scan-summary.json" 2>/dev/null || true

        print_color "$GREEN" "  Summary saved to: $RESULTS_DIR/scan-summary.json"
    else
        print_color "$YELLOW" "  No vulnerability results file found"
    fi
}

# Generate test report
generate_report() {
    echo ""
    print_color "$BLUE" "================================================================"
    print_color "$BLUE" "                      TEST SUMMARY"
    print_color "$BLUE" "================================================================"
    echo ""

    # List generated files
    print_color "$GREEN" "Generated files:"
    local files=(
        "snyk-oauth-results.json:Vulnerability scan results (JSON)"
        "snyk-oauth-results.sarif:Vulnerability scan results (SARIF)"
        "snyk-oauth-code-results.json:Code analysis results (JSON)"
        "snyk-oauth-code-results.sarif:Code analysis results (SARIF)"
        "scan-summary.json:Scan summary"
        "scan.log:Scan execution log"
        "code-scan.log:Code analysis log"
    )

    for file_info in "${files[@]}"; do
        local filename="${file_info%%:*}"
        local description="${file_info#*:}"
        if [ -f "$RESULTS_DIR/$filename" ]; then
            local size=$(du -h "$RESULTS_DIR/$filename" | cut -f1)
            print_color "$GREEN" "    $filename ($size) - $description"
        fi
    done

    echo ""
    print_color "$CYAN" "OAuth Configuration:"
    echo "    Region: ${SNYK_REGION:-us}"
    echo "    Token TTL: ${TOKEN_EXPIRES_IN:-unknown}s"

    echo ""
    print_color "$CYAN" "Exit Codes Reference:"
    echo "    0 = No vulnerabilities found"
    echo "    1 = Vulnerabilities found"
    echo "    2 = Execution error"
    echo "    3 = No supported projects"

    echo ""
    print_color "$GREEN" "OAuth 2.0 local test completed!"
    echo ""
    echo "Next steps:"
    echo "  1. Review results in: $RESULTS_DIR/"
    echo "  2. Fix any critical/high vulnerabilities"
    echo "  3. Upload SARIF to GitHub Code Scanning (optional)"
    echo "  4. Commit and push to trigger CI/CD pipeline"
    echo ""
    echo "For CI/CD integration, set these secrets:"
    echo "  - SNYK_CLIENT_ID"
    echo "  - SNYK_CLIENT_SECRET"
    echo ""
    echo "Documentation:"
    echo "  https://docs.snyk.io/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0"
}

# Main execution
main() {
    print_header

    # Change to project root
    cd "$PROJECT_ROOT"

    # Execute test steps
    load_environment

    # Skip full validation in quick mode
    if [ "$1" = "--quick" ] || [ "$1" = "-q" ]; then
        print_color "$YELLOW" "Quick mode: Skipping full validation"
        acquire_oauth_token
    else
        # Full validation calls validate-snyk-oauth.sh
        # which already acquires token, so we just need to re-acquire here
        print_color "$YELLOW" "Running full validation first..."
        acquire_oauth_token
    fi

    setup_snyk_cli
    build_project
    run_snyk_scan
    run_snyk_code_analysis
    analyze_results
    generate_report

    # Return scan exit code
    exit $SCAN_EXIT_CODE
}

# Handle interruption
trap 'echo ""; print_color "$YELLOW" "Test interrupted"; exit 1' INT

# Run main function
main "$@"
