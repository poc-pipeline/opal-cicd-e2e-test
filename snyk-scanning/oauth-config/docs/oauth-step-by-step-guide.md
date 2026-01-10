# GitHub Enterprise Actions - Snyk OAuth 2.0 Integration
## Step-by-Step Reference Guide (Option A: `oauth_client_secret`)

---

## Phase 1: One-Time Setup (Organization Level)

### Step 1: Navigate to Snyk Service Accounts

**Action:** Platform Admin navigates to Group Settings → Service Accounts in Snyk Web UI

**Official Documentation:**
- **Snyk Docs:** [Service accounts using OAuth 2.0](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0)
- **Snyk Docs:** [Service accounts](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts)

**Details:**
- Service accounts can be created at **Group level** (recommended for enterprise) or **Organization level**
- Group-level tokens can call both Group API endpoints and Organization API endpoints
- Requires **Group Admin** permissions to create Group service accounts

---

### Step 2: Create OAuth Service Account

**Action:** Admin creates a new service account with OAuth 2.0 client credentials authentication type

**Official Documentation:**
- **Snyk Docs:** [Service accounts using OAuth 2.0](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0)
- **Snyk Docs:** [Manage service accounts using the Snyk API](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/manage-service-accounts-using-the-snyk-api)

**Configuration Parameters:**

| Parameter | Value | Description |
|-----------|-------|-------------|
| `name` | `banamex-ghe-scanner` | Unique identifier for the service account |
| `auth_type` | `oauth_client_secret` | OAuth 2.0 with client secret authentication |
| `role_id` | CI-CD-Scanner role | Defines permissions (use Group Viewer for read-only) |
| `access_token_ttl_seconds` | `3600` | Token lifetime (default: 1 hour, max: 24 hours) |

**API Alternative:**
```bash
POST https://api.snyk.io/rest/groups/{groupId}/service_accounts?version=2024-10-15
```

---

### Step 3: Receive and Secure Credentials

**Action:** Snyk generates and displays the `client_id` and `client_secret` (shown only once)

**Official Documentation:**
- **Snyk Docs:** [Service accounts using OAuth 2.0](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0)

**Response Format:**
```json
{
  "client_id": "64ae3415-5ccd-49e5-91f0-9101a6793ec2",
  "client_secret": "sk_live_xxxxxxxxxxxxxxxxxxxx"
}
```

**Critical Security Notes:**
- The `client_secret` is displayed **only once** at creation time
- Cannot be retrieved later; if lost, must rotate using the Secrets Management API
- Never share the `client_secret` publicly
- Store immediately in a secure vault before closing the dialog

**Secret Rotation (if compromised):**
```bash
POST https://api.snyk.io/rest/groups/{groupId}/service_accounts/{serviceAccountId}/secrets
# Operations: create, delete, replace
```

---

### Step 4: Store CLIENT_ID in GitHub Organization Secrets

**Action:** Admin stores `SNYK_CLIENT_ID` as an organization-level secret in GitHub Enterprise

**Official Documentation:**
- **GitHub Docs:** [Using secrets in GitHub Actions](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
- **GitHub Docs:** [REST API - Organization Secrets](https://docs.github.com/en/rest/actions/secrets#create-or-update-an-organization-secret)

**Steps:**
1. Navigate to **Organization → Settings → Secrets and variables → Actions**
2. Click **Secrets** tab → **New organization secret**
3. Name: `SNYK_CLIENT_ID`
4. Value: `64ae3415-5ccd-49e5-91f0-9101a6793ec2`
5. Repository access: **All repositories** (or select specific repositories)

**API Method:**
```bash
PUT /orgs/{org}/actions/secrets/SNYK_CLIENT_ID
Authorization: Bearer <GITHUB_TOKEN>
Content-Type: application/json

{
  "encrypted_value": "<base64_libsodium_sealed_box>",
  "key_id": "<org_public_key_id>",
  "visibility": "all"
}
```

---

### Step 5: Store CLIENT_SECRET in GitHub Organization Secrets

**Action:** Admin stores `SNYK_CLIENT_SECRET` as an organization-level secret (encrypted)

**Official Documentation:**
- **GitHub Docs:** [Encrypted secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
- **GitHub Docs:** [Secrets - GitHub Actions Concepts](https://docs.github.com/en/actions/concepts/security/secrets)

**Encryption Details:**
- Secrets are encrypted using **LibSodium sealed boxes** before reaching GitHub
- Algorithm: **X25519 + XSalsa20-Poly1305** (authenticated encryption)
- Client-side encryption minimizes risks of accidental logging in GitHub's infrastructure

**Storage Limits:**
| Scope | Maximum Secrets | Size Limit |
|-------|-----------------|------------|
| Organization | 1,000 | 48 KB per secret |
| Repository | 100 | 48 KB per secret |
| Environment | 100 | 48 KB per secret |

**Secret Naming Rules:**
- Alphanumeric characters (`[a-z]`, `[A-Z]`, `[0-9]`) and underscores (`_`) only
- Must not start with `GITHUB_` prefix
- Must not start with a number

---

## Phase 2: Centralized Reusable Workflow

### Step 6: Define Reusable Workflow Structure

**Action:** Create centralized reusable workflow with `workflow_call` trigger

**Official Documentation:**
- **GitHub Docs:** [Reusing workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
- **GitHub Changelog:** [Simplify using secrets with reusable workflows](https://github.blog/changelog/2022-05-03-github-actions-simplify-using-secrets-with-reusable-workflows/)

**File Location:** `banamex/security-workflows/.github/workflows/snyk-oauth-scan.yml`

**Workflow Structure:**
```yaml
name: Snyk OAuth Security Scan

on:
  workflow_call:
    secrets:
      SNYK_CLIENT_ID:
        description: 'Snyk OAuth Client ID'
        required: true
      SNYK_CLIENT_SECRET:
        description: 'Snyk OAuth Client Secret'
        required: true

permissions:
  contents: read
  security-events: write
```

**Key Considerations:**
- Secrets are **not automatically passed** to reusable workflows
- Use `secrets: inherit` in caller or explicitly pass each secret
- Maximum **10 levels** of nested reusable workflows
- Permissions can only be **maintained or reduced**, not elevated

---

## Phase 3: Application Workflow Trigger

### Step 7: Developer Pushes Code

**Action:** Developer executes `git push origin main`

**Official Documentation:**
- **GitHub Docs:** [Events that trigger workflows - push](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#push)

**Webhook Payload:**
```json
{
  "ref": "refs/heads/main",
  "commits": [...],
  "pusher": {"name": "developer", "email": "..."},
  "repository": {...}
}
```

---

### Step 8: Parse Caller Workflow

**Action:** GitHub Enterprise parses `.github/workflows/security.yml` in application repository

**Official Documentation:**
- **GitHub Docs:** [Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

**Caller Workflow Example:**
```yaml
name: Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  security:
    uses: banamex/security-workflows/.github/workflows/snyk-oauth-scan.yml@main
    secrets: inherit
```

---

### Step 9: Call Reusable Workflow with Secret Inheritance

**Action:** Caller workflow invokes reusable workflow using `secrets: inherit`

**Official Documentation:**
- **GitHub Docs:** [Reusing workflows - Passing secrets](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows#passing-inputs-and-secrets-to-a-reusable-workflow)
- **GitHub Docs:** [Sharing workflows with your organization](https://docs.github.com/en/actions/administering-github-actions/sharing-workflows-secrets-and-runners-with-your-organization)

**Secret Inheritance Behavior:**
- `secrets: inherit` passes **all** organization/repository secrets to the reusable workflow
- Works for workflows in the **same organization or enterprise**
- Secrets must be defined in the `workflow_call` trigger of the reusable workflow

---

### Step 10: Provision Ephemeral Runner

**Action:** GitHub Enterprise provisions an ephemeral Ubuntu VM runner

**Official Documentation:**
- **GitHub Docs:** [About GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners)
- **GitHub Changelog:** [Ephemeral self-hosted runners](https://github.blog/changelog/2021-09-20-github-actions-ephemeral-self-hosted-runners-new-webhooks-for-auto-scaling/)

**Runner Characteristics:**
| Feature | Description |
|---------|-------------|
| Environment | Fresh VM for each job |
| Isolation | Network isolation enabled |
| Security | Crypto-mining pools blocked via `/etc/hosts` |
| Lifecycle | Destroyed after job completion |
| Software | Pre-installed tools (Node.js, Python, etc.) |

---

## Phase 4: Secret Retrieval

### Step 11: Request Organization Secrets

**Action:** Runner requests `SNYK_CLIENT_ID` and `SNYK_CLIENT_SECRET` from GitHub Secrets storage

**Official Documentation:**
- **GitHub Docs:** [Using secrets in GitHub Actions](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
- **GitHub Docs:** [Security hardening - Using secrets](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)

**Fork Isolation Check:**
- Secrets are **NOT passed** to workflows triggered by pull requests from forks
- Exception: Admin explicitly enables "Send write tokens to workflows from pull requests"
- `GITHUB_TOKEN` from forks has **read-only** permissions by default

---

### Step 12: Decrypt and Inject Secrets

**Action:** GitHub decrypts secrets using organization private key and injects as environment variables

**Official Documentation:**
- **GitHub Docs:** [Secrets - GitHub Actions Concepts](https://docs.github.com/en/actions/concepts/security/secrets)

**Security Features:**
- Secrets are decrypted at runtime, never stored in plain text
- Automatic **pattern-based masking** in logs (shows as `***`)
- Secrets cannot be read from workflow logs even with debug logging enabled

**Environment Variable Injection:**
```bash
SNYK_CLIENT_ID=***
SNYK_CLIENT_SECRET=***
```

---

## Phase 5: OAuth Token Acquisition

### Step 13: Execute Token Wrapper Step

**Action:** Runner executes the "Acquire Snyk OAuth Token" step

**Official Documentation:**
- **Snyk Docs:** [Service accounts using OAuth 2.0](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0)

**Wrapper Script Purpose:**
- Fetches short-lived OAuth access token
- Handles error responses gracefully
- Masks token in logs using `::add-mask::`
- Exports token as `SNYK_OAUTH_TOKEN` environment variable

---

### Step 14: Send OAuth Token Request

**Action:** Runner sends `client_credentials` grant request to Snyk OAuth endpoint

**Official Documentation:**
- **Snyk Docs:** [OAuth2 API](https://docs.snyk.io/snyk-api/oauth2-api)
- **RFC 6749:** [OAuth 2.0 Authorization Framework - Client Credentials Grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4)

**Request Format:**
```http
POST /oauth2/token HTTP/1.1
Host: api.snyk.io
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id=64ae3415-5ccd-49e5-91f0-9101a6793ec2
&client_secret=sk_live_xxxxxxxxxxxxxxxxxxxx
```

**Regional Endpoints:**
| Region | OAuth Endpoint |
|--------|----------------|
| US (default) | `https://api.snyk.io/oauth2/token` |
| EU | `https://api.eu.snyk.io/oauth2/token` |
| AU | `https://api.au.snyk.io/oauth2/token` |

---

### Step 15: Snyk Validates Credentials

**Action:** Snyk OAuth server validates the client credentials

**Official Documentation:**
- **Snyk Docs:** [Authentication for API](https://docs.snyk.io/snyk-api/rest-api/authentication-for-api)
- **Snyk Docs:** [Service accounts using OAuth 2.0](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0)

**Validation Steps:**

| Step | Check | Failure Response |
|------|-------|------------------|
| 1 | Client ID exists in system | `401 invalid_client` |
| 2 | Client secret matches | `401 invalid_client` |
| 3 | Service account is active | `403 account_disabled` |
| 4 | Organization scope valid | `403 insufficient_scope` |
| 5 | Rate limit not exceeded | `429 rate_limit_exceeded` |

**Rate Limits:**
| API Version | Limit |
|-------------|-------|
| V1 API | 2,000 requests/minute |
| REST API | 1,620 requests/minute |
| Reporting API | 70 requests/minute |

---

### Step 16: Receive Access Token

**Action:** Snyk returns OAuth access token with metadata

**Official Documentation:**
- **Snyk Docs:** [OAuth2 API - Request an access token](https://docs.snyk.io/snyk-api/oauth2-api)

**Response Format:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 3599,
  "token_type": "bearer",
  "scope": "org.read org.project.read org.project.snapshot.read"
}
```

**Token Characteristics:**
| Property | Value | Description |
|----------|-------|-------------|
| `expires_in` | 3599 | Seconds until expiration (~1 hour) |
| `token_type` | bearer | Must use `Authorization: bearer` header |
| `scope` | org.read, etc. | Permissions granted to the token |

---

### Step 17: Mask and Export Token

**Action:** Runner masks the token and exports as environment variable

**Official Documentation:**
- **GitHub Docs:** [Workflow commands - Masking a value](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#masking-a-value-in-a-log)

**Implementation:**
```bash
# Mask token in all subsequent log output
echo "::add-mask::$ACCESS_TOKEN"

# Export for use by Snyk CLI
echo "SNYK_OAUTH_TOKEN=$ACCESS_TOKEN" >> $GITHUB_ENV
```

**Security Notes:**
- Token stored in runner memory only
- Never written to disk or persisted
- Masked as `***` in all workflow logs
- Cleared when ephemeral VM is destroyed

---

## Phase 6: Snyk CLI Execution

### Step 18: Setup Snyk CLI

**Action:** Install Snyk CLI using the official GitHub Action

**Official Documentation:**
- **Snyk Docs:** [GitHub Actions for Snyk setup](https://docs.snyk.io/developer-tools/snyk-ci-cd-integrations/github-actions-for-snyk-setup-and-checking-for-vulnerabilities)
- **GitHub Repository:** [snyk/actions](https://github.com/snyk/actions)

**Usage:**
```yaml
- name: Setup Snyk CLI
  uses: snyk/actions/setup@master
```

**Alternative (SHA pinning for security):**
```yaml
- uses: snyk/actions/setup@8349f904b9754728b4e06b7c67ee08e8c24bf59c
```

---

### Step 19: CLI Detects OAuth Token

**Action:** Snyk CLI automatically recognizes the `SNYK_OAUTH_TOKEN` environment variable

**Official Documentation:**
- **Snyk Docs:** [Authenticate to use the CLI](https://docs.snyk.io/snyk-cli/authenticate-to-use-the-cli)
- **Snyk Docs:** [Environment variables for Snyk CLI](https://docs.snyk.io/snyk-cli/configure-the-snyk-cli/environment-variables-for-snyk-cli)

**Token Precedence:**
1. `SNYK_OAUTH_TOKEN` (OAuth 2.0 bearer token) - **highest priority**
2. `SNYK_TOKEN` (API token)
3. Local configuration (`~/.config/configstore/snyk.json`)

**CLI Authentication with OAuth:**
```bash
# Environment variable (recommended for CI/CD)
export SNYK_OAUTH_TOKEN="eyJhbGciOiJSUzI1NiI..."
snyk test

# Or using CLI flags
snyk auth --auth-type=oauth \
  --client-id=${SNYK_CLIENT_ID} \
  --client-secret=${SNYK_CLIENT_SECRET}
```

---

### Step 20: Execute Snyk Test Command

**Action:** Run vulnerability scan with SARIF output

**Official Documentation:**
- **Snyk Docs:** [Test command](https://docs.snyk.io/developer-tools/snyk-cli/commands/test)
- **Snyk Docs:** [CLI commands and options summary](https://docs.snyk.io/developer-tools/snyk-cli/cli-commands-and-options-summary)

**Command:**
```bash
snyk test --all-projects \
  --severity-threshold=high \
  --sarif-file-output=snyk.sarif
```

**Common Options:**
| Option | Description |
|--------|-------------|
| `--all-projects` | Auto-detect all projects in working directory |
| `--severity-threshold` | Only report issues at this level or higher |
| `--sarif-file-output` | Output results in SARIF 2.1.0 format |
| `--json-file-output` | Output results in JSON format |
| `--org` | Specify Snyk organization ID |

---

### Step 21: API Request with Bearer Token

**Action:** Snyk CLI sends authenticated API request

**Official Documentation:**
- **Snyk Docs:** [Authentication for API](https://docs.snyk.io/snyk-api/rest-api/authentication-for-api)
- **Snyk Docs:** [V1 API](https://docs.snyk.io/snyk-api/v1-api)

**Request Format:**
```http
POST /v1/test HTTP/1.1
Host: api.snyk.io
Authorization: bearer eyJhbGciOiJSUzI1NiI...
Content-Type: application/json

{
  "encoding": "plain",
  "files": {
    "package.json": {"contents": "base64_encoded"},
    "package-lock.json": {"contents": "base64_encoded"}
  },
  "packageManager": "npm"
}
```

**Supported Package Managers:**
- npm, yarn, pnpm (Node.js)
- pip, pipenv, poetry (Python)
- maven, gradle (Java)
- go modules (Go)
- nuget (.NET)
- composer (PHP)
- rubygems (Ruby)

---

### Step 22: Snyk Validates Bearer Token

**Action:** Snyk API validates the OAuth bearer token

**Official Documentation:**
- **Snyk Docs:** [Authentication for API](https://docs.snyk.io/snyk-api/rest-api/authentication-for-api)

**Validation Checks:**
| Check | Description |
|-------|-------------|
| Signature | Verify JWT signature using Snyk's public key |
| Expiration | Check `exp` claim hasn't passed |
| Scope | Verify token has required permissions |
| Organization | Confirm access to target organization |

**Error Responses:**
| Status | Error | Description |
|--------|-------|-------------|
| 401 | `invalid_token` | Token expired or malformed |
| 403 | `insufficient_scope` | Token lacks required permissions |
| 429 | `rate_limit_exceeded` | Too many requests |

---

### Step 23: Receive Vulnerability Results

**Action:** Snyk returns vulnerability analysis results

**Official Documentation:**
- **Snyk Docs:** [Review the Snyk Open Source CLI results](https://docs.snyk.io/developer-tools/snyk-cli/scan-and-maintain-projects-using-the-cli/snyk-cli-for-open-source/review-the-snyk-open-source-cli-results)

**Response Structure:**
```json
{
  "vulnerabilities": [
    {
      "id": "SNYK-JS-LODASH-1018905",
      "severity": "high",
      "cvssScore": 7.5,
      "packageName": "lodash",
      "version": "4.17.20",
      "upgradePath": ["lodash@4.17.21"],
      "isUpgradable": true
    }
  ],
  "summary": {
    "total": 5,
    "critical": 0,
    "high": 2,
    "medium": 3,
    "low": 0
  }
}
```

---

## Phase 7: Token Refresh (If Required)

### Step 24: Detect Token Expiration

**Action:** API returns 401 Unauthorized due to expired token

**Official Documentation:**
- **Snyk Docs:** [Service accounts using OAuth 2.0](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0)

**When Refresh is Needed:**
- Scans running longer than 1 hour
- Token TTL configured shorter than scan duration
- Network delays causing token to expire mid-request

**Error Response:**
```json
{
  "error": "invalid_token",
  "error_description": "The access token expired"
}
```

---

### Step 25: Re-acquire Token Using Client Credentials

**Action:** Request new access token using same client credentials

**Official Documentation:**
- **Snyk Docs:** [OAuth2 API](https://docs.snyk.io/snyk-api/oauth2-api)

**Key Difference from Authorization Code Flow:**
- `client_credentials` grant does **not** use refresh tokens
- Simply re-authenticate with `client_id` and `client_secret`
- Each new token has fresh TTL

**Request:**
```http
POST /oauth2/token HTTP/1.1
Host: api.snyk.io
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id=${SNYK_CLIENT_ID}
&client_secret=${SNYK_CLIENT_SECRET}
```

---

### Step 26: Retry Failed Request

**Action:** Retry the API call with the new access token

**Implementation Pattern:**
```bash
retry_with_refresh() {
  RESPONSE=$(curl -s -w "%{http_code}" ...)
  HTTP_CODE="${RESPONSE: -3}"
  
  if [ "$HTTP_CODE" == "401" ]; then
    # Fetch new token
    NEW_TOKEN=$(fetch_oauth_token)
    export SNYK_OAUTH_TOKEN="$NEW_TOKEN"
    # Retry request
    curl -H "Authorization: bearer $NEW_TOKEN" ...
  fi
}
```

---

## Phase 8: Results & Cleanup

### Step 27: Generate SARIF Report

**Action:** Snyk CLI generates SARIF 2.1.0 format report

**Official Documentation:**
- **GitHub Docs:** [SARIF support for code scanning](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning)
- **Snyk Docs:** [CLI commands - SARIF output](https://docs.snyk.io/developer-tools/snyk-cli/commands/test)

**SARIF Structure:**
```json
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [{
    "tool": {
      "driver": {
        "name": "Snyk Open Source",
        "version": "1.x.x"
      }
    },
    "results": [...],
    "taxonomies": [{"name": "CVSS"}]
  }]
}
```

**File Size Limits:**
- Maximum: **10 MB** (gzip-compressed)
- Results limit: ~5,000 per file

---

### Step 28: Determine Exit Code

**Action:** Snyk CLI returns exit code based on scan results

**Official Documentation:**
- **Snyk Docs:** [Test command - Exit codes](https://docs.snyk.io/developer-tools/snyk-cli/commands/test)

**Exit Codes:**

| Code | Status | Meaning |
|------|--------|---------|
| `0` | Success | Scan completed, **no vulnerabilities** found |
| `1` | Action Needed | Scan completed, **vulnerabilities found** |
| `2` | Failure | Execution error, re-run with `-d` for debug |
| `3` | Failure | No supported projects detected |

**Handling in Workflow:**
```yaml
- name: Run Snyk
  run: snyk test
  continue-on-error: true  # Don't fail workflow on exit code 1
```

---

### Step 29: Upload SARIF to GitHub Code Scanning

**Action:** Upload SARIF results to GitHub Security tab

**Official Documentation:**
- **GitHub Docs:** [Uploading a SARIF file to GitHub](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github)

**Workflow Step:**
```yaml
- name: Upload SARIF to GitHub Code Scanning
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: snyk.sarif
```

**Requirements:**
- Permission: `security-events: write`
- For private repositories: **GitHub Advanced Security** must be enabled
- SARIF version: 2.1.0

---

### Step 30: Ephemeral VM Destroyed

**Action:** GitHub destroys the ephemeral runner VM

**Official Documentation:**
- **GitHub Docs:** [About GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners)

**Cleanup Performed:**
| Item | Action |
|------|--------|
| OAuth Token | Cleared from memory |
| Client Credentials | Never persisted, cleared |
| Workspace | Completely deleted |
| Network Connections | All connections closed |
| VM | Destroyed and deprovisioned |

**Security Benefit:**
- No credential persistence between jobs
- Each workflow run gets a fresh, clean environment
- Eliminates risk of credential leakage between runs

---

## Security Controls Summary

### GitHub Enterprise Controls

| Control | Documentation |
|---------|---------------|
| LibSodium Encryption | [Secrets - GitHub Actions](https://docs.github.com/en/actions/concepts/security/secrets) |
| Organization Secrets | [Using secrets in GitHub Actions](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions) |
| Workflow Permissions | [Controlling permissions for GITHUB_TOKEN](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token) |
| Fork Isolation | [Security hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions) |
| Reusable Workflows | [Reusing workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) |

### Snyk Controls

| Control | Documentation |
|---------|---------------|
| OAuth 2.0 Service Accounts | [Service accounts using OAuth 2.0](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0) |
| Token TTL | [Manage service accounts API](https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/manage-service-accounts-using-the-snyk-api) |
| Rate Limiting | [V1 API](https://docs.snyk.io/snyk-api/v1-api) |
| Regional Endpoints | [Regional hosting and data residency](https://docs.snyk.io/snyk-data-and-governance/regional-hosting-and-data-residency) |
| CLI Authentication | [Authenticate to use the CLI](https://docs.snyk.io/snyk-cli/authenticate-to-use-the-cli) |

---

## Quick Reference: Documentation Links

### Snyk Official Documentation

| Topic | URL |
|-------|-----|
| Service Accounts OAuth 2.0 | https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/service-accounts-using-oauth-2.0 |
| OAuth2 API Reference | https://docs.snyk.io/snyk-api/oauth2-api |
| CLI Authentication | https://docs.snyk.io/snyk-cli/authenticate-to-use-the-cli |
| Environment Variables | https://docs.snyk.io/snyk-cli/configure-the-snyk-cli/environment-variables-for-snyk-cli |
| GitHub Actions Integration | https://docs.snyk.io/developer-tools/snyk-ci-cd-integrations/github-actions-for-snyk-setup-and-checking-for-vulnerabilities |
| API Authentication | https://docs.snyk.io/snyk-api/rest-api/authentication-for-api |
| Manage Service Accounts API | https://docs.snyk.io/implementation-and-setup/enterprise-setup/service-accounts/manage-service-accounts-using-the-snyk-api |
| Test Command Reference | https://docs.snyk.io/developer-tools/snyk-cli/commands/test |

### GitHub Official Documentation

| Topic | URL |
|-------|-----|
| Using Secrets | https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions |
| Reusing Workflows | https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows |
| Workflow Permissions | https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token |
| SARIF Support | https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning |
| Uploading SARIF | https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github |
| GitHub-hosted Runners | https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners |
| Security Hardening | https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions |
| Workflow Syntax | https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions |
