# Snyk OAuth 2.0 Integration Setup Guide

## Overview

This guide explains how to set up OAuth 2.0 authentication for Snyk security scanning in the CI/CD Security Gating Pipeline. OAuth 2.0 provides enhanced security over traditional API tokens through short-lived, automatically refreshing credentials.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Snyk Service Account Setup](#snyk-service-account-setup)
3. [GitHub Secrets Configuration](#github-secrets-configuration)
4. [Local Testing](#local-testing)
5. [Pipeline Integration](#pipeline-integration)
6. [Regional Configuration](#regional-configuration)
7. [Token Management](#token-management)
8. [Security Best Practices](#security-best-practices)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

- **Snyk Enterprise account** with Group Admin access
- GitHub repository with Actions enabled
- Snyk CLI installed (v1.1293.0+ for OAuth support)
- `jq` installed for JSON processing
- `curl` installed for API requests

### Verify Prerequisites

```bash
# Check Snyk CLI version
snyk --version

# Check jq
jq --version

# Check curl
curl --version
```

## Snyk Service Account Setup

### Step 1: Navigate to Service Accounts

1. Log in to [app.snyk.io](https://app.snyk.io)
2. Click your organization name in the top menu
3. Go to **Group Settings** (gear icon)
4. Select **Service Accounts** from the left menu

### Step 2: Create OAuth Service Account

1. Click **Create service account**
2. Enter a **Name** (e.g., `ci-cd-oauth-scanner`)
3. Select a **Role**:
   - **Group Viewer**: Read-only access (recommended for scanning)
   - **Group Admin**: Full administrative access
4. Under **Authentication**, select **OAuth 2.0 client credentials**
5. Click **Create service account**

### Step 3: Capture Credentials

After creation, a dialog displays your credentials:

```
Client ID: 64ae3415-5ccd-49e5-91f0-9101a6793ec2
Client Secret: sk_live_xxxxxxxxxxxxxxxxxxxx
```

**CRITICAL:** Copy both values immediately! The client secret is shown only once and cannot be retrieved later.

### Step 4: Store Credentials Securely

Store credentials in a secure location:
- Password manager
- Secrets vault (HashiCorp Vault, AWS Secrets Manager, etc.)
- Encrypted file

**Never** commit credentials to version control.

## GitHub Secrets Configuration

### Required Secrets

Add these secrets to your GitHub repository or organization:

| Secret Name | Description | Required |
|------------|-------------|----------|
| `SNYK_CLIENT_ID` | OAuth client identifier | Yes |
| `SNYK_CLIENT_SECRET` | OAuth client secret | Yes |
| `SNYK_REGION` | Regional endpoint (us/eu/au) | No |
| `SNYK_ORG_ID` | Snyk organization UUID | No |

### Adding Secrets via GitHub UI

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with its name and value

### Adding Secrets via GitHub CLI

```bash
# Set required secrets
gh secret set SNYK_CLIENT_ID --body "your-client-id-here"
gh secret set SNYK_CLIENT_SECRET --body "your-client-secret-here"

# Set optional secrets
gh secret set SNYK_REGION --body "us"
gh secret set SNYK_ORG_ID --body "your-org-uuid-here"
```

### Organization-Level Secrets (Recommended)

For multiple repositories, set secrets at organization level:

```bash
# Organization-level secrets
gh secret set SNYK_CLIENT_ID --org your-org --body "your-client-id-here"
gh secret set SNYK_CLIENT_SECRET --org your-org --body "your-client-secret-here"
```

## Local Testing

### Step 1: Environment Setup

Create environment file from example:

```bash
cd snyk-scanning/oauth-config

# Copy example file
cp .env.oauth.example .env.oauth

# Edit with your credentials
nano .env.oauth
```

Configure `.env.oauth`:

```bash
# Required
SNYK_CLIENT_ID=your-client-id-here
SNYK_CLIENT_SECRET=your-client-secret-here

# Optional
SNYK_REGION=us
SNYK_ORG_ID=your-org-uuid-here
```

### Step 2: Validate Configuration

```bash
# Make script executable
chmod +x scripts/validate-snyk-oauth.sh

# Run validation
./scripts/validate-snyk-oauth.sh
```

Expected output:

```
================================================================
           SNYK OAUTH 2.0 CONFIGURATION VALIDATOR
================================================================

Loading environment variables...
  Found: .env.oauth
Validating OAuth environment variables...
  SNYK_CLIENT_ID: 64ae3415...
  SNYK_CLIENT_SECRET: ******* (set)
  SNYK_REGION: us (default)
  All required OAuth variables are set
Acquiring OAuth access token...
  Endpoint: https://api.snyk.io/oauth2/token
  Access token acquired successfully
  Token type: bearer
  Expires in: 3599s (~59 minutes)
Testing API connection with OAuth token...
  API connection successful
  Authenticated as: ci-cd-oauth-scanner
```

### Step 3: Run Full Local Test

```bash
# Make script executable
chmod +x scripts/test-snyk-oauth-local.sh

# Run full test
./scripts/test-snyk-oauth-local.sh

# Or quick mode (skip validation)
./scripts/test-snyk-oauth-local.sh --quick
```

### Step 4: Check Results

After testing, results are in `results/`:

```bash
ls -la results/
# snyk-oauth-results.json
# snyk-oauth-results.sarif
# snyk-oauth-code-results.json
# snyk-oauth-code-results.sarif
# scan-summary.json

# View summary
cat results/scan-summary.json | jq .
```

## Pipeline Integration

### OAuth Token Wrapper Step

Add this step before Snyk scanning in your workflow:

```yaml
- name: Acquire Snyk OAuth Token
  id: snyk-oauth
  run: |
    # Request OAuth token
    RESPONSE=$(curl -s -X POST https://api.snyk.io/oauth2/token \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "grant_type=client_credentials" \
      -d "client_id=${{ secrets.SNYK_CLIENT_ID }}" \
      -d "client_secret=${{ secrets.SNYK_CLIENT_SECRET }}")

    # Extract access token
    ACCESS_TOKEN=$(echo $RESPONSE | jq -r '.access_token')

    # Mask token in logs
    echo "::add-mask::$ACCESS_TOKEN"

    # Export for subsequent steps
    echo "SNYK_OAUTH_TOKEN=$ACCESS_TOKEN" >> $GITHUB_ENV

    # Verify token was acquired
    if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
      echo "Failed to acquire OAuth token"
      echo $RESPONSE | jq .
      exit 1
    fi

    echo "OAuth token acquired successfully"
```

### Complete Workflow Example

```yaml
name: Snyk OAuth Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  security-events: write

jobs:
  snyk-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Snyk CLI
        uses: snyk/actions/setup@master

      - name: Acquire Snyk OAuth Token
        run: |
          RESPONSE=$(curl -s -X POST https://api.snyk.io/oauth2/token \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "grant_type=client_credentials" \
            -d "client_id=${{ secrets.SNYK_CLIENT_ID }}" \
            -d "client_secret=${{ secrets.SNYK_CLIENT_SECRET }}")

          ACCESS_TOKEN=$(echo $RESPONSE | jq -r '.access_token')
          echo "::add-mask::$ACCESS_TOKEN"
          echo "SNYK_OAUTH_TOKEN=$ACCESS_TOKEN" >> $GITHUB_ENV

      - name: Run Snyk Scan
        run: |
          snyk test --json-file-output=snyk-results.json || true
          snyk test --sarif-file-output=snyk-results.sarif || true

      - name: Upload SARIF to GitHub
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: snyk-results.sarif
```

### Alternative: CLI Authentication Flags

For CLI v1.1293.0+, you can authenticate directly:

```yaml
- name: Authenticate Snyk CLI with OAuth
  run: |
    snyk auth --auth-type=oauth \
      --client-id=${{ secrets.SNYK_CLIENT_ID }} \
      --client-secret=${{ secrets.SNYK_CLIENT_SECRET }}
```

## Regional Configuration

### Available Regions

| Region | OAuth Endpoint | API Endpoint | Use Case |
|--------|----------------|--------------|----------|
| US (default) | `api.snyk.io/oauth2/token` | `api.snyk.io` | North America |
| EU | `api.eu.snyk.io/oauth2/token` | `api.eu.snyk.io` | Europe (GDPR) |
| AU | `api.au.snyk.io/oauth2/token` | `api.au.snyk.io` | Asia-Pacific |

### Configuring Region

**Local testing:**

```bash
export SNYK_REGION=eu
./scripts/validate-snyk-oauth.sh
```

**GitHub Actions:**

```yaml
env:
  SNYK_REGION: eu

- name: Acquire OAuth Token (EU)
  run: |
    ENDPOINT="https://api.eu.snyk.io/oauth2/token"
    # ... rest of token acquisition
```

## Token Management

### Token Characteristics

- **Lifetime**: 3599 seconds (~1 hour) by default
- **Type**: Bearer token
- **Format**: JWT (JSON Web Token)
- **Refresh**: Re-acquire using client credentials (no refresh token)

### Token Refresh for Long Scans

For scans exceeding 1 hour, implement token refresh:

```bash
# Function to refresh token if needed
refresh_token_if_needed() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - TOKEN_ACQUIRED_AT))
    local remaining=$((TOKEN_EXPIRES_IN - elapsed))

    # Refresh if less than 5 minutes remaining
    if [ $remaining -lt 300 ]; then
        echo "Token expiring soon, refreshing..."
        acquire_oauth_token
    fi
}
```

The provided scripts handle this automatically.

### Rotating Credentials

If credentials are compromised:

1. Go to Snyk **Group Settings** → **Service Accounts**
2. Find your service account
3. Click **Rotate secret**
4. Copy new `client_secret`
5. Update GitHub Secrets immediately

## Security Best Practices

### Do's

- Store credentials in secure secrets management
- Use organization-level secrets for multiple repos
- Rotate credentials regularly (quarterly recommended)
- Use minimal required role (Group Viewer for scanning)
- Mask tokens in CI/CD logs using `::add-mask::`
- Implement token refresh for long-running scans

### Don'ts

- Never commit credentials to version control
- Don't log client_secret or access_token values
- Don't share credentials across environments
- Don't use personal API tokens in CI/CD
- Don't ignore token expiration

### Audit Trail

OAuth service accounts provide better audit logging:

1. Go to Snyk **Group Settings** → **Audit logs**
2. Filter by service account name
3. Review API calls and scan activities

## Troubleshooting

### Common Issues

#### 1. "Invalid client credentials" (HTTP 401)

**Problem**: OAuth token request returns 401 error

**Solutions**:
- Verify `SNYK_CLIENT_ID` is correct
- Verify `SNYK_CLIENT_SECRET` is correct (check for trailing spaces)
- Ensure service account is not disabled
- Check regional endpoint matches your account

```bash
# Debug token request
curl -v -X POST https://api.snyk.io/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$SNYK_CLIENT_ID" \
  -d "client_secret=$SNYK_CLIENT_SECRET"
```

#### 2. "Token expired" during scan

**Problem**: Scan fails mid-way with authentication error

**Solutions**:
- Use `test-snyk-oauth-local.sh` which handles refresh
- Implement token refresh in custom scripts
- Reduce scan scope for faster completion

#### 3. "Organization not found"

**Problem**: Cannot access Snyk organization

**Solutions**:
- Verify `SNYK_ORG_ID` is correct UUID format
- Ensure service account has access to the organization
- Check service account role permissions

#### 4. "No supported projects detected"

**Problem**: Snyk exits with code 3

**Solutions**:
- Ensure project has supported manifest files (pom.xml, package.json, etc.)
- Run `mvn compile` or `npm install` before scanning
- Check Snyk CLI is detecting the correct project type

### Debug Mode

Enable verbose output:

```bash
# Local scripts
DEBUG=true ./scripts/validate-snyk-oauth.sh

# Snyk CLI
snyk test -d

# GitHub Actions
env:
  ACTIONS_STEP_DEBUG: true
```

### Getting Help

- **Snyk Documentation**: [docs.snyk.io](https://docs.snyk.io)
- **OAuth 2.0 Guide**: [Service accounts using OAuth 2.0](https://docs.snyk.io/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0)
- **API Reference**: [Snyk API](https://docs.snyk.io/snyk-api)
- **CLI Help**: `snyk --help` or `snyk auth --help`
- **Support**: [support.snyk.io](https://support.snyk.io)

## Related Documentation

- [Main README](../README.md) - Quick start guide
- [OAuth Step-by-Step Guide](oauth-step-by-step-guide.md) - 30-step technical reference
- [OAuth Sequence Diagram](oauth-sequence-diagram.mermaid) - Visual flow diagram
- [Token-based Snyk Scanning](../../) - Alternative authentication method
- [Pipeline Architecture](../../../CLAUDE.md) - Overall pipeline documentation

---

*For questions or issues, please refer to the [main project README](../../../README.md) or create an issue in the repository.*
