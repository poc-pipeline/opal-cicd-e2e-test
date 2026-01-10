# Snyk OAuth 2.0 Authentication

OAuth 2.0 client credentials authentication for Snyk security scanning in the CI/CD pipeline.

## Overview

This module provides OAuth 2.0 authentication for Snyk, offering enhanced security over traditional API token authentication:

| Aspect | Token-Based | OAuth 2.0 |
|--------|-------------|-----------|
| **Security** | Static long-lived token | Short-lived (1 hour) rotating tokens |
| **Setup** | Single API token | Client ID + Client Secret pair |
| **CLI Support** | `SNYK_TOKEN` | `SNYK_OAUTH_TOKEN` or CLI flags |
| **Rotation** | Manual | Automatic refresh |
| **Best For** | Individual developers | CI/CD pipelines, Enterprise |

## Quick Start

### 1. Create OAuth Service Account in Snyk

1. Go to **Group Settings** → **Service Accounts** in Snyk
2. Click **Create service account**
3. Select **OAuth 2.0 client credentials**
4. Assign a role (e.g., CI-CD-Scanner)
5. Copy `client_id` and `client_secret` (shown only once!)

### 2. Configure Environment

```bash
# Copy example file
cp .env.oauth.example .env.oauth

# Edit with your credentials
SNYK_CLIENT_ID=your-client-id-here
SNYK_CLIENT_SECRET=your-client-secret-here
SNYK_REGION=us  # us, eu, or au
```

### 3. Validate Configuration

```bash
./scripts/validate-snyk-oauth.sh
```

### 4. Run Local Test

```bash
./scripts/test-snyk-oauth-local.sh
```

### 5. Configure CI/CD

Add these GitHub Secrets:
- `SNYK_CLIENT_ID`
- `SNYK_CLIENT_SECRET`

## Directory Structure

```
oauth-config/
├── README.md                      # This file
├── .env.oauth.example             # Example environment configuration
├── scripts/
│   ├── validate-snyk-oauth.sh     # OAuth configuration validation
│   └── test-snyk-oauth-local.sh   # Full local testing with OAuth
├── results/                       # Scan results (gitignored)
│   └── .gitkeep
└── docs/
    ├── SETUP.md                   # Detailed setup guide
    ├── oauth-step-by-step-guide.md # 30-step technical reference
    └── oauth-sequence-diagram.mermaid # Flow diagram
```

## Scripts

### validate-snyk-oauth.sh

Validates OAuth configuration and tests API connectivity:

```bash
./scripts/validate-snyk-oauth.sh
```

**What it does:**
- Validates `SNYK_CLIENT_ID` and `SNYK_CLIENT_SECRET`
- Acquires OAuth access token
- Tests API connection with bearer token
- Validates organization access (if `SNYK_ORG_ID` set)
- Checks Snyk CLI installation
- Runs test vulnerability scan

### test-snyk-oauth-local.sh

Runs complete local security scan with OAuth authentication:

```bash
./scripts/test-snyk-oauth-local.sh

# Quick mode (skip full validation)
./scripts/test-snyk-oauth-local.sh --quick
```

**What it does:**
- Validates configuration
- Builds project (Maven compile)
- Acquires OAuth token
- Runs Snyk vulnerability scan
- Runs Snyk code analysis (SAST)
- Generates JSON and SARIF output
- Handles token refresh for long scans

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `SNYK_CLIENT_ID` | OAuth client identifier | Yes | - |
| `SNYK_CLIENT_SECRET` | OAuth client secret | Yes | - |
| `SNYK_REGION` | Regional endpoint | No | `us` |
| `SNYK_ORG_ID` | Organization UUID | No | - |

### Regional Endpoints

| Region | OAuth Endpoint | API Endpoint |
|--------|----------------|--------------|
| `us` (default) | `api.snyk.io/oauth2/token` | `api.snyk.io` |
| `eu` | `api.eu.snyk.io/oauth2/token` | `api.eu.snyk.io` |
| `au` | `api.au.snyk.io/oauth2/token` | `api.au.snyk.io` |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No vulnerabilities found |
| 1 | Vulnerabilities found |
| 2 | Execution error |
| 3 | No supported projects |

## Output Files

After running `test-snyk-oauth-local.sh`, results are saved to `results/`:

| File | Description |
|------|-------------|
| `snyk-oauth-results.json` | Vulnerability scan (JSON) |
| `snyk-oauth-results.sarif` | Vulnerability scan (SARIF) |
| `snyk-oauth-code-results.json` | Code analysis (JSON) |
| `snyk-oauth-code-results.sarif` | Code analysis (SARIF) |
| `scan-summary.json` | Aggregated summary |

## Documentation

- **[SETUP.md](docs/SETUP.md)** - Detailed setup and integration guide
- **[oauth-step-by-step-guide.md](docs/oauth-step-by-step-guide.md)** - 30-step technical reference
- **[oauth-sequence-diagram.mermaid](docs/oauth-sequence-diagram.mermaid)** - OAuth flow diagram

## Official Snyk Documentation

- [Service accounts using OAuth 2.0](https://docs.snyk.io/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0)
- [OAuth2 API](https://docs.snyk.io/snyk-api/oauth2-api)
- [Authenticate to use the CLI](https://docs.snyk.io/snyk-cli/authenticate-to-use-the-cli)
- [snyk auth command](https://docs.snyk.io/developer-tools/snyk-cli/commands/auth)
- [CLI Environment Variables](https://docs.snyk.io/snyk-cli/configure-the-snyk-cli/environment-variables-for-snyk-cli)

## Related Modules

- [snyk-scanning](../) - Token-based Snyk scanning
- [sonarqube-cloud-scanning](../../sonarqube-cloud-scanning/) - Code quality analysis
- [codacy-scanning](../../codacy-scanning/) - Code review analysis
- [permit-gating](../../permit-gating/) - Policy-based deployment gates
