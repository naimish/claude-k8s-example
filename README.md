# Kubernetes Multi-Environment CD Platform

A production-ready Kubernetes continuous deployment repository supporting multiple microservices across dev/staging/prod environments using Helm charts, GitHub Actions, and trunk-based development.

## Architecture Overview

### Core Components
- **Microservices**: API service, Worker service, Web frontend
- **Orchestration**: Kubernetes with Helm umbrella charts
- **CI/CD**: GitHub Actions with environment-specific workflows
- **Image Registry**: GitHub Container Registry (ghcr.io)
- **Git Strategy**: Trunk-based development with feature flags

### Environments

| Environment | Deployment | Approvals | Scaling |
|-------------|-----------|-----------|---------|
| **Dev** | Auto on merge to main | None | Minimal (1 replica) |
| **Staging** | Manual promotion | 1 reviewer | Medium (2 replicas, HPA) |
| **Production** | Manual promotion | 2 reviewers + 5min wait | High (5+ replicas, HPA) |

## Quick Start

### Prerequisites
- Docker
- Helm 3.x
- kubectl configured for your clusters
- GitHub CLI (optional)

### Local Development

```bash
# Install dependencies
make install

# Run tests
make test

# Build Docker images locally
make build

# Validate Helm charts
make lint

# Deploy to local Kubernetes
make deploy-local
```

## Repository Structure

```
.
├── .github/
│   ├── workflows/          # CI/CD pipelines
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── CODEOWNERS
├── helm/
│   ├── umbrella/          # Main umbrella chart
│   │   ├── Chart.yaml     # Dependencies on service charts
│   │   ├── values.yaml    # Default configuration
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   └── values-prod.yaml
│   └── services/          # Individual service charts
│       ├── api-service/
│       ├── worker-service/
│       └── web-frontend/
├── docker/                # Dockerfiles for each service
├── src/                   # Application source code
│   ├── api-service/
│   ├── worker-service/
│   └── web-frontend/
├── scripts/               # Helper scripts
└── docs/                  # Documentation
```

## Deployment Workflow

### Feature Development
1. Create feature branch from `main`
2. Develop with feature flag disabled
3. Open PR (triggers CI: lint, test, build, scan)
4. Get 2 approvals + pass all checks
5. Squash merge to `main`
6. Automatically deploys to **dev**

### Promotion to Staging
```bash
# Via GitHub UI: Actions → CD Staging → Run workflow
# Or via CLI:
gh workflow run cd-staging.yaml -f image_tag=main-abc123
```

### Promotion to Production
```bash
# Via GitHub UI: Actions → CD Production → Run workflow
# Requires 2 approvals
gh workflow run cd-prod.yaml -f image_tag=main-abc123
```

## Feature Flags

Feature flags enable safe trunk-based development:

```yaml
# helm/umbrella/values-dev.yaml
global:
  featureFlags:
    newUIEnabled: true    # Enable in dev first
    betaFeaturesEnabled: false
```

See [docs/FEATURE_FLAGS.md](docs/FEATURE_FLAGS.md) for detailed usage.

## Adding New Services

1. Create service chart in `helm/services/new-service/`
2. Add dependency to `helm/umbrella/Chart.yaml`
3. Configure in `helm/umbrella/values.yaml`
4. Add to CI matrix in `.github/workflows/ci.yaml`

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for details.

## Scaling Configuration

Service scaling is managed via environment-specific values files:

```yaml
# values-prod.yaml
api-service:
  replicaCount: 5
  autoscaling:
    enabled: true
    minReplicas: 5
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70
```

## Rollback

### Automatic Rollback
Failed deployments automatically rollback via Helm's `--atomic` flag.

### Manual Rollback
```bash
helm rollback microservices-platform -n production
# Or redeploy previous image tag via GitHub Actions
```

## Security

- Multi-stage Docker builds with non-root users
- Security scanning via Trivy in CI
- Pod security contexts enforced
- Resource limits on all workloads
- Network policies for traffic restriction
- Secrets managed via Kubernetes Secrets (not in repo)

## Documentation

- [Deployment Guide](docs/DEPLOYMENT.md) - Deployment procedures and troubleshooting
- [Development Guide](docs/DEVELOPMENT.md) - Local setup and testing
- [Feature Flags](docs/FEATURE_FLAGS.md) - Feature flag usage patterns

## Branch Protection

The `main` branch is protected with:
- Require 2 PR approvals
- Require all status checks to pass
- Dismiss stale reviews on new commits
- Require code owner review
- Enforce linear history (squash merges)
- No force pushes
- Require conversation resolution

## GitHub Secrets Configuration

Required secrets per environment:

```bash
# Repository secrets
SLACK_WEBHOOK  # Optional: for notifications

# Environment secrets
KUBECONFIG_DEV        # Dev cluster kubeconfig (base64)
KUBECONFIG_STAGING    # Staging cluster kubeconfig (base64)
KUBECONFIG_PROD       # Production cluster kubeconfig (base64)
```

## Support

For issues or questions, please open a GitHub issue.

## License

MIT
