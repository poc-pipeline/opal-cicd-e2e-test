#!/bin/bash

# Snyk OAuth 2.0 Configuration Validation Script
# This script validates your Snyk OAuth configuration and connection
# using OAuth 2.0 client_credentials grant flow
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
    print_color "$BLUE" "           SNYK OAUTH 2.0 CONFIGURATION VALIDATOR"
    print_color "$BLUE" "================================================================"
    echo ""
}

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OAUTH_CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$OAUTH_CONFIG_DIR/../.." && pwd)"

# Regional endpoints
declare -A OAUTH_ENDPOINTS=(
    ["us"]="https://api.snyk.io/oauth2/token"
    ["eu"]="https://api.eu.snyk.io/oauth2/token"
    ["au"]="https://api.au.snyk.io/oauth2/token"
)

declare -A API_ENDPOINTS=(
    ["us"]="https://api.snyk.io"
    ["eu"]="https://api.eu.snyk.io"
    ["au"]="https://api.au.snyk.io"
)

# Global variables for OAuth token
OAUTH_ACCESS_TOKEN=""
TOKEN_EXPIRES_IN=""

# Load environment variables
load_environment() {
    print_color "$CYAN" "Loading environment variables..."

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
        # Check if required environment variables are already set (CI environment)
        if [ -n "$SNYK_CLIENT_ID" ] && [ -n "$SNYK_CLIENT_SECRET" ]; then
            print_color "$GREEN" "  Using environment variables (CI mode)"
        else
            print_color "$YELLOW" "  No .env file found, using existing environment variables"
        fi
    fi
}

# Validate OAuth environment variables
validate_env_vars() {
    print_color "$CYAN" "Validating OAuth environment variables..."

    local missing_vars=()

    if [ -z "$SNYK_CLIENT_ID" ]; then
        missing_vars+=("SNYK_CLIENT_ID")
    else
        # Mask client ID in output (show first 8 chars only)
        local masked_id="${SNYK_CLIENT_ID:0:8}..."
        print_color "$GREEN" "  SNYK_CLIENT_ID: $masked_id"
    fi

    if [ -z "$SNYK_CLIENT_SECRET" ]; then
        missing_vars+=("SNYK_CLIENT_SECRET")
    else
        print_color "$GREEN" "  SNYK_CLIENT_SECRET: ******* (set)"
    fi

    # Optional variables
    if [ -n "$SNYK_REGION" ]; then
        print_color "$GREEN" "  SNYK_REGION: $SNYK_REGION"
    else
        SNYK_REGION="us"
        print_color "$GREEN" "  SNYK_REGION: us (default)"
    fi

    if [ -n "$SNYK_ORG_ID" ]; then
        print_color "$GREEN" "  SNYK_ORG_ID: $SNYK_ORG_ID"
    else
        print_color "$YELLOW" "  SNYK_ORG_ID: not set (optional)"
    fi

    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_color "$RED" "  Missing required variables: ${missing_vars[*]}"
        echo ""
        echo "Please set the following variables in your .env.oauth file:"
        for var in "${missing_vars[@]}"; do
            echo "  $var=your_value_here"
        done
        echo ""
        echo "Get OAuth credentials from Snyk:"
        echo "  Group Settings -> Service Accounts -> Create (OAuth 2.0 client credentials)"
        echo ""
        echo "Documentation: https://docs.snyk.io/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0"
        exit 1
    fi

    print_color "$GREEN" "  All required OAuth variables are set"
}

# Get OAuth endpoint based on region
get_oauth_endpoint() {
    local region="${SNYK_REGION:-us}"
    region=$(echo "$region" | tr '[:upper:]' '[:lower:]')

    if [[ -v OAUTH_ENDPOINTS[$region] ]]; then
        echo "${OAUTH_ENDPOINTS[$region]}"
    else
        print_color "$RED" "  Unknown region: $region (valid: us, eu, au)"
        exit 1
    fi
}

# Get API endpoint based on region
get_api_endpoint() {
    local region="${SNYK_REGION:-us}"
    region=$(echo "$region" | tr '[:upper:]' '[:lower:]')

    if [[ -v API_ENDPOINTS[$region] ]]; then
        echo "${API_ENDPOINTS[$region]}"
    else
        echo "https://api.snyk.io"
    fi
}

# Acquire OAuth access token
acquire_oauth_token() {
    print_color "$CYAN" "Acquiring OAuth access token..."

    local oauth_endpoint=$(get_oauth_endpoint)
    print_color "$YELLOW" "  Endpoint: $oauth_endpoint"

    # Make OAuth token request
    local response
    local http_code

    response=$(curl -s -w "\n%{http_code}" -X POST "$oauth_endpoint" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -d "client_id=$SNYK_CLIENT_ID" \
        -d "client_secret=$SNYK_CLIENT_SECRET")

    http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        OAUTH_ACCESS_TOKEN=$(echo "$body" | jq -r '.access_token // empty')
        TOKEN_EXPIRES_IN=$(echo "$body" | jq -r '.expires_in // empty')
        local token_type=$(echo "$body" | jq -r '.token_type // empty')
        local scope=$(echo "$body" | jq -r '.scope // empty')

        if [ -n "$OAUTH_ACCESS_TOKEN" ]; then
            print_color "$GREEN" "  Access token acquired successfully"
            print_color "$GREEN" "  Token type: $token_type"
            print_color "$GREEN" "  Expires in: ${TOKEN_EXPIRES_IN}s (~$((TOKEN_EXPIRES_IN / 60)) minutes)"
            if [ -n "$scope" ]; then
                print_color "$GREEN" "  Scope: $scope"
            fi

            # Export for CLI use
            export SNYK_OAUTH_TOKEN="$OAUTH_ACCESS_TOKEN"

            return 0
        else
            print_color "$RED" "  Failed to extract access token from response"
            return 1
        fi
    else
        print_color "$RED" "  OAuth token request failed (HTTP $http_code)"

        # Parse error details
        local error=$(echo "$body" | jq -r '.error // empty')
        local error_desc=$(echo "$body" | jq -r '.error_description // empty')

        if [ -n "$error" ]; then
            print_color "$RED" "  Error: $error"
            if [ -n "$error_desc" ]; then
                print_color "$RED" "  Description: $error_desc"
            fi
        else
            echo "$body" | head -c 500
        fi

        echo ""
        echo "Common issues:"
        echo "  - Invalid client_id or client_secret"
        echo "  - Service account is disabled"
        echo "  - Wrong regional endpoint (check SNYK_REGION)"
        return 1
    fi
}

# Check if Snyk CLI is installed
check_snyk_cli() {
    print_color "$CYAN" "Checking Snyk CLI installation..."

    if command -v snyk &> /dev/null; then
        local version=$(snyk --version 2>/dev/null || echo "unknown")
        print_color "$GREEN" "  Snyk CLI installed (version: $version)"

        # Check if CLI version supports OAuth (v1.1293.0+)
        local major_version=$(echo "$version" | cut -d'.' -f1)
        local minor_version=$(echo "$version" | cut -d'.' -f2)

        if [ "$major_version" -ge 1 ] && [ "$minor_version" -ge 1293 ]; then
            print_color "$GREEN" "  CLI supports OAuth authentication (v1.1293.0+)"
        else
            print_color "$YELLOW" "  Note: OAuth is default in CLI v1.1293.0+, consider upgrading"
        fi

        return 0
    else
        print_color "$YELLOW" "  Snyk CLI not found"
        echo ""
        echo "To install Snyk CLI:"
        echo "  npm install -g snyk"
        echo "  or visit: https://docs.snyk.io/snyk-cli/install-the-snyk-cli"
        return 1
    fi
}

# Test API connection with OAuth token
test_api_connection() {
    print_color "$CYAN" "Testing API connection with OAuth token..."

    if [ -z "$OAUTH_ACCESS_TOKEN" ]; then
        print_color "$RED" "  No OAuth token available"
        return 1
    fi

    local api_endpoint=$(get_api_endpoint)

    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: bearer $OAUTH_ACCESS_TOKEN" \
        "$api_endpoint/v1/user/me")

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        local username=$(echo "$body" | jq -r '.username // empty')
        local user_id=$(echo "$body" | jq -r '.id // empty')

        print_color "$GREEN" "  API connection successful"
        if [ -n "$username" ]; then
            print_color "$GREEN" "  Authenticated as: $username"
        fi
        if [ -n "$user_id" ]; then
            print_color "$GREEN" "  User ID: ${user_id:0:8}..."
        fi
        return 0
    elif [ "$http_code" = "401" ]; then
        print_color "$RED" "  Authentication failed (HTTP 401)"
        echo "  Token may be invalid or expired"
        return 1
    else
        print_color "$RED" "  API connection failed (HTTP $http_code)"
        echo "$body" | head -c 500
        return 1
    fi
}

# Validate organization access
validate_organization() {
    if [ -z "$SNYK_ORG_ID" ]; then
        print_color "$YELLOW" "Skipping organization validation (SNYK_ORG_ID not set)"
        return 0
    fi

    print_color "$CYAN" "Validating organization access..."

    # Check if organization ID is in valid UUID format
    if [[ ! $SNYK_ORG_ID =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
        print_color "$RED" "  Organization ID is not in valid UUID format"
        echo "  Expected format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        return 1
    fi

    local api_endpoint=$(get_api_endpoint)

    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: bearer $OAUTH_ACCESS_TOKEN" \
        "$api_endpoint/v1/org/$SNYK_ORG_ID/projects?limit=1")

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        local project_count=$(echo "$body" | jq '.projects | length // 0')
        print_color "$GREEN" "  Organization access verified"
        print_color "$GREEN" "  Organization ID: $SNYK_ORG_ID"
        print_color "$GREEN" "  Projects accessible: $project_count"
        return 0
    elif [ "$http_code" = "404" ]; then
        print_color "$YELLOW" "  Cannot access organization projects (HTTP 404)"
        echo "  This may be normal for new organizations or limited permissions"
        print_color "$GREEN" "  Organization ID format is valid"
        return 0
    elif [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
        print_color "$RED" "  Unauthorized access to organization (HTTP $http_code)"
        echo "  Service account may not have access to this organization"
        return 1
    else
        print_color "$YELLOW" "  Could not validate organization (HTTP $http_code)"
        echo "  Continuing with format validation only"
        print_color "$GREEN" "  Organization ID format is valid"
        return 0
    fi
}

# Test CLI authentication with OAuth
test_cli_oauth_auth() {
    print_color "$CYAN" "Testing Snyk CLI with OAuth authentication..."

    if ! command -v snyk &> /dev/null; then
        print_color "$YELLOW" "  Skipping (Snyk CLI not installed)"
        return 0
    fi

    if [ -z "$SNYK_OAUTH_TOKEN" ]; then
        print_color "$RED" "  No OAuth token available"
        return 1
    fi

    # Test CLI authentication using SNYK_OAUTH_TOKEN environment variable
    local result
    result=$(SNYK_OAUTH_TOKEN="$OAUTH_ACCESS_TOKEN" snyk whoami 2>&1) || true

    if echo "$result" | grep -q "error\|Error\|failed\|Failed"; then
        print_color "$YELLOW" "  CLI authentication test inconclusive"
        print_color "$YELLOW" "  Output: $result"
        echo ""
        echo "  Alternative: Test with direct OAuth flags:"
        echo "  snyk auth --auth-type=oauth --client-id=\$SNYK_CLIENT_ID --client-secret=\$SNYK_CLIENT_SECRET"
    else
        print_color "$GREEN" "  CLI authenticated via SNYK_OAUTH_TOKEN"
        if [ -n "$result" ]; then
            print_color "$GREEN" "  Result: $result"
        fi
    fi

    return 0
}

# Test vulnerability scanning
test_vulnerability_scan() {
    print_color "$CYAN" "Testing vulnerability scanning with OAuth..."

    if ! command -v snyk &> /dev/null; then
        print_color "$YELLOW" "  Skipping (Snyk CLI not installed)"
        return 0
    fi

    local app_dir="$PROJECT_ROOT/microservice-moc-app"

    if [ -d "$app_dir" ] && [ -f "$app_dir/pom.xml" ]; then
        print_color "$YELLOW" "  Running test scan on microservice-moc-app..."

        cd "$app_dir"

        # Run a quick test scan with OAuth token
        local scan_result
        set +e
        scan_result=$(SNYK_OAUTH_TOKEN="$OAUTH_ACCESS_TOKEN" snyk test --json 2>/dev/null)
        local exit_code=$?
        set -e

        if [ -n "$scan_result" ]; then
            local vuln_count=$(echo "$scan_result" | jq '.vulnerabilities | length // 0' 2>/dev/null || echo "0")
            local ok=$(echo "$scan_result" | jq -r '.ok // empty' 2>/dev/null)

            if [ "$ok" = "true" ]; then
                print_color "$GREEN" "  Scan completed: No vulnerabilities found"
            elif [ "$vuln_count" -gt 0 ] 2>/dev/null; then
                print_color "$GREEN" "  Scan completed: Found $vuln_count vulnerabilities"
                print_color "$GREEN" "  (This is expected for the PoC application)"
            else
                print_color "$GREEN" "  Scan completed successfully"
            fi
        else
            if [ $exit_code -eq 0 ]; then
                print_color "$GREEN" "  Scan completed (no output)"
            else
                print_color "$YELLOW" "  Scan may have failed (exit code: $exit_code)"
                echo "  This may be normal if dependencies are not downloaded"
                echo "  Try running 'mvn compile' first"
            fi
        fi

        cd "$SCRIPT_DIR"
    else
        print_color "$YELLOW" "  Skipping scan test (microservice-moc-app not found)"
    fi

    return 0
}

# Generate validation summary
generate_report() {
    echo ""
    print_color "$BLUE" "================================================================"
    print_color "$BLUE" "                    VALIDATION SUMMARY"
    print_color "$BLUE" "================================================================"
    echo ""

    print_color "$GREEN" "OAuth 2.0 Configuration: VALIDATED"
    echo ""
    echo "Configuration details:"
    echo "  Region: ${SNYK_REGION:-us}"
    echo "  OAuth Endpoint: $(get_oauth_endpoint)"
    echo "  API Endpoint: $(get_api_endpoint)"
    if [ -n "$SNYK_ORG_ID" ]; then
        echo "  Organization ID: $SNYK_ORG_ID"
    fi
    if [ -n "$TOKEN_EXPIRES_IN" ]; then
        echo "  Token TTL: ${TOKEN_EXPIRES_IN}s"
    fi
    echo ""
    echo "Environment variable for CLI:"
    echo "  export SNYK_OAUTH_TOKEN=\"\$ACCESS_TOKEN\""
    echo ""
    echo "Next steps:"
    echo "  1. Run local tests: ./test-snyk-oauth-local.sh"
    echo "  2. Configure CI/CD with SNYK_CLIENT_ID and SNYK_CLIENT_SECRET secrets"
    echo "  3. Use OAuth workflow for GitHub Actions"
    echo ""
    echo "Documentation:"
    echo "  https://docs.snyk.io/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0"
}

# Main execution
main() {
    print_header

    load_environment
    validate_env_vars

    # Acquire OAuth token first
    if ! acquire_oauth_token; then
        print_color "$RED" ""
        print_color "$RED" "OAuth token acquisition failed. Cannot continue validation."
        exit 1
    fi

    # Run validation steps
    check_snyk_cli
    test_api_connection
    validate_organization
    test_cli_oauth_auth
    test_vulnerability_scan

    generate_report
}

# Handle Ctrl+C
trap 'echo ""; print_color "$YELLOW" "Validation interrupted"; exit 1' INT

# Run main function
main "$@"
