#
# Dockerfile for GitHub Actions Self-Hosted Runner
#
# This image includes tools commonly needed for CI/CD pipelines:
# - curl, jq, git
# - Docker CLI (for building images)
# - Node.js (for GitHub Actions)
#
# Build:
#   docker build -t custom-actions-runner:latest .
#
# Run:
#   docker run -d \
#     -e RUNNER_NAME=my-runner \
#     -e RUNNER_TOKEN=<token> \
#     -e GITHUB_REPOSITORY=poc-pipeline/opal-cicd-e2e-test \
#     custom-actions-runner:latest
#

FROM ghcr.io/actions/actions-runner:latest

# Switch to root for package installation
USER root

# Install additional tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    jq \
    git \
    zip \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for Docker-outside-of-Docker)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Switch back to runner user
USER runner

# Entrypoint script for auto-registration
COPY --chown=runner:runner entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
