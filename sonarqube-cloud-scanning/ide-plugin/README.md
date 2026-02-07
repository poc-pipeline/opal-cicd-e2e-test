# SonarLint IDE Plugin Setup

This guide covers the SonarLint VS Code extension configuration for this repository, including Connected Mode with SonarQube Cloud.

## Prerequisites

- VS Code with the [SonarLint](https://marketplace.visualstudio.com/items?itemName=SonarSource.sonarlint-vscode) extension installed
- SonarQube Cloud account with access to the `poc-pipeline` organization
- SonarQube Cloud user token (generated at [sonarcloud.io/account/security](https://sonarcloud.io/account/security))

## Project Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| `.vscode/settings.json` | Project root | SonarLint extension settings (Connected Mode, rules, focus) |
| `.vscode/extensions.json` | Project root | Recommends the SonarLint extension to team members |
| `sonarqube-cloud-scanning/config/sonar-project.properties` | Scanning config | SonarQube Cloud project config (used by CI/CD and Maven) |
| `microservice-moc-app/pom.xml` | App root | SonarQube Maven plugin and JaCoCo coverage settings |

## Connected Mode

SonarLint Connected Mode syncs the IDE with SonarQube Cloud so that:
- The same quality rules used in CI/CD are applied locally
- Issues marked as "Won't Fix" or "False Positive" on the server are suppressed locally
- Custom quality profiles are applied automatically
- New rules from server updates are picked up

### VS Code Settings for Connected Mode

The `.vscode/settings.json` includes the following SonarLint configuration:

```json
{
    "sonarlint.connectedMode.connections.sonarcloud": [
        {
            "organizationKey": "poc-pipeline",
            "connectionId": "poc-pipeline"
        }
    ],
    "sonarlint.connectedMode.project": {
        "connectionId": "poc-pipeline",
        "projectKey": "poc-pipeline_opal-cicd-e2e-test"
    }
}
```

> **Note**: On first use, SonarLint will prompt you to provide a user token for the connection. Generate one at SonarQube Cloud > My Account > Security.

## Enabled Features

| Feature | Description | Status |
|---------|-------------|--------|
| Connected Mode | Syncs rules and suppressions with SonarQube Cloud | Enabled |
| Java analysis | Bugs, code smells, vulnerabilities in Java source | Enabled (default) |
| New Code focus | Highlights issues only in new/changed code | Enabled |
| IaC analysis | Dockerfile, Kubernetes YAML analysis | Disabled (not relevant) |

### Analysis Scope

SonarLint analyzes files as you open and edit them. The analysis scope matches what SonarQube Cloud scans in CI/CD:

- **Sources**: `src/main/java`
- **Tests**: `src/test/java` (issues reported but not counted toward quality gate)
- **Exclusions**: Test classes (`*Test.java`, `*Tests.java`), generated code (`target/`)

These exclusions are inherited from `sonar-project.properties` when Connected Mode is active.

## Rule Configuration

With Connected Mode, rules are managed centrally on SonarQube Cloud. Local rule overrides in `settings.json` are ignored when connected. This ensures consistency between what developers see locally and what the CI/CD pipeline enforces.

To customize rules:
1. Go to SonarQube Cloud > Your Project > Quality Profiles
2. Adjust rules there — changes sync to all team members via Connected Mode

### Focus on New Code

The `sonarlint.focusOnNewCode` setting is enabled so that SonarLint highlights issues only on new or changed lines. This matches the SonarQube Cloud "New Code" period and helps developers focus on fixing their own changes rather than legacy issues.

## CI/CD vs IDE Analysis

| Aspect | CI/CD Pipeline | IDE Plugin (SonarLint) |
|--------|---------------|------------------------|
| Trigger | Push / PR | File open / edit |
| Tool | `mvn sonar:sonar` | SonarLint extension |
| Auth | `SONAR_TOKEN` secret | User token (prompted) |
| Config | `sonar-project.properties` + Maven args | Connected Mode (synced) |
| Rules | SonarQube Cloud quality profile | Same (via Connected Mode) |
| Coverage | JaCoCo report uploaded | Not available locally |
| Quality Gate | Server-side evaluation | Not evaluated locally |
| Results | SonarQube Cloud dashboard + GitHub summary | VS Code Problems panel |

## First-Time Setup

1. **Install the extension**: Open VS Code and accept the SonarLint recommendation prompt, or install `SonarSource.sonarlint-vscode` manually
2. **Token prompt**: When you open the project, SonarLint detects the Connected Mode settings and prompts for a user token
3. **Generate token**: Go to [sonarcloud.io/account/security](https://sonarcloud.io/account/security) and create a token
4. **Paste token**: Enter it in the VS Code prompt — SonarLint stores it securely
5. **Sync**: SonarLint downloads the quality profile and issue suppressions from SonarQube Cloud
6. **Verify**: Open a Java file in `microservice-moc-app/src/main/java/` and check that issues appear in the Problems panel

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Connection failed" | Verify your user token is valid and has access to the `poc-pipeline` organization |
| No issues shown | Ensure Connected Mode is configured (check `sonarlint.connectedMode.project` in settings) |
| Rules don't match CI/CD | Click "Update binding" in the SonarLint output panel to re-sync |
| Java files not analyzed | Ensure Java 17+ is installed and `JAVA_HOME` is set — SonarLint needs a JRE for Java analysis |
| Too many legacy issues | Enable `sonarlint.focusOnNewCode` to see only new/changed code issues |
| IaC false positives | Confirm `sonarlint.disableRulesByScope.iac` is `true` in settings |

## SonarQube Cloud Project Details

| Setting | Value |
|---------|-------|
| Organization | `poc-pipeline` |
| Project Key | `poc-pipeline_opal-cicd-e2e-test` |
| Project Name | `poc-pipeline` |
| Host | `https://sonarcloud.io` |
| Language | Java 17 |
| Coverage | JaCoCo |
| Quality Gate | Default (Sonar way) |

## Related Files

- `sonarqube-cloud-scanning/config/sonar-project.properties` — Full project configuration
- `sonarqube-cloud-scanning/docs/SETUP_GUIDE.md` — SonarQube Cloud account setup
- `sonarqube-cloud-scanning/docs/TROUBLESHOOTING.md` — CI/CD troubleshooting
- `sonarqube-cloud-scanning/scripts/validate-sonarqube.sh` — Configuration validation
- `microservice-moc-app/pom.xml` — Maven plugin and JaCoCo configuration
