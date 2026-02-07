# Snyk IDE Plugin Setup

This guide covers the Snyk VS Code extension configuration for this repository.

## Prerequisites

- VS Code with the [Snyk Security](https://marketplace.visualstudio.com/items?itemName=snyk-security.snyk-vulnerability-scanner) extension installed
- Snyk account authenticated (the extension will prompt you on first launch)

## Project Configuration Files

The following files configure the Snyk IDE plugin at the project level:

| File | Location | Purpose |
|------|----------|---------|
| `.vscode/settings.json` | Project root | VS Code Snyk extension settings (org ID, feature toggles, severity filters) |
| `.vscode/extensions.json` | Project root | Recommends the Snyk extension to team members |
| `.dcignore` | Project root | Controls which files Snyk Code (SAST) scans — excludes build artifacts, tests, CI scripts |
| `.snyk` | Project root | Snyk policy file — vulnerability ignores, patches, custom severity rules |
| `snyk-scanning/config/.snyk` | Original location | Source of truth for the `.snyk` policy (copied to root for IDE detection) |

## Enabled Features

The VS Code settings enable the following Snyk capabilities:

| Feature | Setting | Status |
|---------|---------|--------|
| Open Source Security | `snyk.features.openSourceSecurity` | Enabled — scans `pom.xml` for dependency vulnerabilities |
| Code Security (SAST) | `snyk.features.codeSecurity` | Enabled — static analysis of Java source code |
| Code Quality | `snyk.features.codeQuality` | Enabled — code quality issues and suggestions |
| IaC Security | `snyk.features.iacSecurity` | Disabled — not relevant for this project |

### Severity Filter

Only **critical**, **high**, and **medium** severity issues are shown. Low severity is filtered out to reduce noise.

### Scanning Mode

Set to `automatic` — the extension scans on file save and project open.

## `.dcignore` Exclusions

The `.dcignore` file prevents Snyk Code from analyzing non-source files:

- **Build artifacts**: `target/`, `*.jar`, `*.war`, `*.class`
- **Dependencies**: `node_modules/`, `.mvn/`
- **Test fixtures**: `**/test/`, `**/tests/`
- **CI/CD**: `.github/`, `docker-image.tar`
- **Scan results**: `snyk-scanning/results/`, `sonarqube-cloud-scanning/results/`
- **Documentation**: `*.md`
- **IDE config**: `.vscode/`, `.idea/`
- **Logs**: `*.log`, `logs/`

## `.snyk` Policy File

The `.snyk` file at project root is recognized by both the CLI and the IDE plugin. It defines:

- **Language settings**: Java linter enabled
- **Patches**: None currently
- **Ignore rules**: None (PoC mode — all vulnerabilities detected)
- **Custom rules**: Severity-based checks for critical, high, and medium

> **Note**: The canonical `.snyk` file lives at `snyk-scanning/config/.snyk`. The root copy must be kept in sync manually. If you update ignore rules or patches, update both locations.

## First-Time Setup

1. Open the project in VS Code
2. Accept the extension recommendation prompt (or install `snyk-security.snyk-vulnerability-scanner` manually)
3. Authenticate when prompted — the extension opens a browser for Snyk login
4. The org ID is pre-configured in `.vscode/settings.json`, so scans will use the correct organization automatically
5. Wait for the initial scan to complete (check the Snyk sidebar panel)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Extension not activating | Check that the Snyk extension is installed and enabled |
| Wrong organization | Verify `snyk.advanced.organization` in `.vscode/settings.json` matches your Snyk org |
| Too many results | Check that `.dcignore` exists at project root |
| Missing dependency scan results | Ensure `pom.xml` is present and `snyk.features.openSourceSecurity` is `true` |
| `.snyk` ignores not applied | Confirm `.snyk` is at the project root (not only in `snyk-scanning/config/`) |

## CI/CD vs IDE Scanning

| Aspect | CI/CD Pipeline | IDE Plugin |
|--------|---------------|------------|
| Trigger | Push / PR | File save / project open |
| Auth | `SNYK_TOKEN` secret | Browser-based OAuth |
| Config | `snyk-scanning/scripts/` | `.vscode/settings.json` |
| Policy | `snyk-scanning/config/.snyk` | `.snyk` (project root) |
| Exclusions | CLI flags | `.dcignore` |
| Results | GitHub Actions summary | VS Code sidebar panel |
