# Setup Guide - Kubernetes Multi-Environment CD Platform

This guide will help you set up and verify the complete microservices platform implementation.

## Quick Start Checklist

### 1. Prerequisites Installed
- [ ] Python 3.11+
- [ ] Docker Desktop (with Kubernetes enabled) or Minikube
- [ ] Helm 3.x
- [ ] kubectl
- [ ] git

### 2. Initial Setup

```bash
# Clone the repository (or navigate to existing directory)
cd /Users/naimish/dev/personal/claude-k8s-example

# Install Python dependencies
make install

# Run tests to verify everything works
make test

# Validate Helm charts
make lint
```

### 3. Local Testing

```bash
# Build Docker images locally
make build

# This will build:
# - ghcr.io/YOUR_ORG/api-service:local
# - ghcr.io/YOUR_ORG/worker-service:local
# - ghcr.io/YOUR_ORG/web-frontend:local
```

### 4. Local Kubernetes Deployment

```bash
# Enable Kubernetes in Docker Desktop
# Or start Minikube: minikube start

# Deploy to local cluster
make deploy-local

# Verify deployment
kubectl get pods -n dev
kubectl get svc -n dev

# Port forward to access services
kubectl port-forward svc/microservices-platform-web-frontend 8080:80 -n dev &
kubectl port-forward svc/microservices-platform-api-service 8081:80 -n dev &

# Access services:
# Web Frontend: http://localhost:8080
# API Service: http://localhost:8081
```

## GitHub Setup

### 1. Update Repository References

Replace `YOUR_ORG` with your GitHub organization/username in:

- `helm/umbrella/values.yaml`
- `helm/umbrella/values-dev.yaml`
- `helm/umbrella/values-staging.yaml`
- `helm/umbrella/values-prod.yaml`
- `helm/services/*/values.yaml`
- `.github/CODEOWNERS`

```bash
# Quick find/replace
find . -type f \( -name "*.yaml" -o -name "CODEOWNERS" \) -exec sed -i '' 's/YOUR_ORG/your-github-org/g' {} +
```

### 2. Create GitHub Repository

```bash
# Initialize git (if not already done)
git init
git add .
git commit -m "Initial commit: Kubernetes multi-environment CD platform"

# Create repository on GitHub, then:
git remote add origin https://github.com/YOUR_ORG/microservices-platform.git
git branch -M main
git push -u origin main
```

### 3. Configure Branch Protection

Go to Settings → Branches → Add rule for `main`:

- [x] Require pull request reviews before merging (2 approvals)
- [x] Require status checks to pass before merging
- [x] Require conversation resolution before merging
- [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require review from Code Owners
- [x] Do not allow bypassing the above settings

### 4. Configure GitHub Environments

#### Create Environments
Settings → Environments → New environment

Create three environments: `dev`, `staging`, `production`

#### Dev Environment
- No protection rules (auto-deploy)
- Add secret: `KUBECONFIG_DEV`

#### Staging Environment
- Required reviewers: 1
- Add secret: `KUBECONFIG_STAGING`

#### Production Environment
- Required reviewers: 2
- Wait timer: 5 minutes
- Add secret: `KUBECONFIG_PROD`

### 5. Add Kubeconfig Secrets

```bash
# For each environment, encode your kubeconfig:
cat ~/.kube/config | base64 | pbcopy

# Then add to GitHub:
# Settings → Environments → [environment] → Add secret
# Name: KUBECONFIG_[ENV]
# Value: [paste base64 string]
```

## Kubernetes Cluster Setup

### Requirements

You need three Kubernetes clusters:
- Development
- Staging
- Production

Options:
- Local: Docker Desktop Kubernetes, Minikube
- Cloud: GKE, EKS, AKS
- Managed: DigitalOcean Kubernetes, Linode LKE

### Minimum Cluster Specs

**Dev:**
- 2 nodes
- 2 vCPU, 4GB RAM per node

**Staging:**
- 3 nodes
- 2 vCPU, 4GB RAM per node

**Production:**
- 5+ nodes
- 4 vCPU, 8GB RAM per node
- Autoscaling enabled

## Verification Steps

### 1. Verify Repository Structure

```bash
# Check all files are present
ls -la
ls -la .github/workflows/
ls -la helm/umbrella/
ls -la helm/services/
ls -la src/
ls -la scripts/
ls -la docs/
```

Expected structure:
```
.
├── .github/
│   ├── workflows/
│   │   ├── ci.yaml
│   │   ├── cd-dev.yaml
│   │   ├── cd-staging.yaml
│   │   └── cd-prod.yaml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── CODEOWNERS
├── helm/
│   ├── umbrella/
│   └── services/
│       ├── api-service/
│       ├── worker-service/
│       └── web-frontend/
├── docker/
├── src/
├── scripts/
├── docs/
├── Makefile
└── README.md
```

### 2. Verify Python Tests

```bash
# Test each service
cd src/api-service && pytest tests/ -v && cd ../..
cd src/worker-service && pytest tests/ -v && cd ../..
cd src/web-frontend && pytest tests/ -v && cd ../..

# Or use make
make test
```

### 3. Verify Helm Charts

```bash
# Run validation script
./scripts/validate-helm.sh

# Expected output:
# ✓ All service charts lint successfully
# ✓ Umbrella chart lints successfully
# ✓ Templates render for all environments
```

### 4. Verify Docker Builds

```bash
# Build all images
./scripts/build-images.sh

# Verify images exist
docker images | grep -E "(api-service|worker-service|web-frontend)"
```

### 5. Test Local Deployment

```bash
# Deploy to local Kubernetes
make deploy-local

# Verify pods are running
kubectl get pods -n dev

# Expected output: 3 pods running
# - microservices-platform-api-service
# - microservices-platform-worker-service
# - microservices-platform-web-frontend

# Test health endpoints
kubectl exec -n dev $(kubectl get pod -n dev -l app.kubernetes.io/name=api-service -o jsonpath='{.items[0].metadata.name}') -- curl -f http://localhost:8080/health
```

## First Deployment Workflow

### 1. Make a Test Change

```bash
git checkout -b test/first-deployment

# Make a small change (e.g., update README)
echo "# Test deployment" >> README.md

git add README.md
git commit -m "Test: First deployment workflow"
git push origin test/first-deployment
```

### 2. Create Pull Request

- Open PR on GitHub
- Watch CI pipeline run
- Get 2 approvals
- Merge to main

### 3. Verify Auto-Deploy to Dev

- Watch GitHub Actions → CD - Deploy to Dev
- Verify deployment in dev cluster:
  ```bash
  kubectl get pods -n dev
  ```

### 4. Promote to Staging

- GitHub Actions → CD - Deploy to Staging
- Click "Run workflow"
- Enter image tag (e.g., `main-abc123` from dev deployment)
- Get 1 approval
- Verify deployment in staging cluster

### 5. Promote to Production

- GitHub Actions → CD - Deploy to Production
- Click "Run workflow"
- Enter SAME image tag used in staging
- Get 2 approvals
- Wait 5 minutes
- Verify deployment in production cluster

## Feature Flag Testing

### 1. Enable Feature in Dev

```bash
git checkout -b feature/test-new-ui

# Edit helm/umbrella/values-dev.yaml
# Change: newUIEnabled: true

git add helm/umbrella/values-dev.yaml
git commit -m "Enable new UI in dev"
git push origin feature/test-new-ui
```

### 2. Merge and Test

- Create PR
- Merge to main
- Auto-deploys to dev with feature enabled
- Test the new UI

### 3. Promote Feature to Other Environments

Follow the same process for staging and production.

## Troubleshooting

### CI Pipeline Fails

Check:
1. Python dependencies installed correctly
2. Tests pass locally with `make test`
3. Helm charts valid with `make lint`

### Deployment Fails

Check:
1. Kubeconfig secrets are correct
2. Cluster has sufficient resources
3. Image tags exist in registry
4. Helm chart values are correct

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n [namespace]

# Check pod logs
kubectl logs [pod-name] -n [namespace]

# Describe pod
kubectl describe pod [pod-name] -n [namespace]
```

## Next Steps

1. **Customize for Your Org:**
   - Update `YOUR_ORG` references
   - Modify service code as needed
   - Adjust resource limits
   - Configure ingress

2. **Add Real Services:**
   - Replace sample services with actual microservices
   - Follow patterns in `docs/DEVELOPMENT.md`

3. **Configure Monitoring:**
   - Add Prometheus/Grafana
   - Configure alerting
   - Set up log aggregation

4. **Security Hardening:**
   - Configure network policies
   - Set up pod security policies
   - Enable secrets encryption
   - Configure RBAC

5. **CI/CD Enhancements:**
   - Add performance tests
   - Configure code coverage thresholds
   - Add deployment notifications
   - Set up canary deployments

## Documentation

- [README.md](README.md) - Overview and quick start
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deployment procedures
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) - Development guide
- [docs/FEATURE_FLAGS.md](docs/FEATURE_FLAGS.md) - Feature flag usage

## Support

For issues or questions:
- Review documentation in `docs/`
- Check GitHub issues
- Contact platform team

## Success Criteria

The implementation is complete when:

- [x] All three sample microservices created
- [x] Dockerfiles for all services
- [x] Helm charts for individual services
- [x] Umbrella Helm chart with environment configs
- [x] CI pipeline (lint, test, build, scan)
- [x] CD pipelines (dev, staging, production)
- [x] Feature flags implemented
- [x] Helper scripts created
- [x] Documentation complete
- [x] GitHub templates created

Now ready for:

- [ ] Push to GitHub repository
- [ ] Configure branch protection
- [ ] Set up GitHub environments
- [ ] Add kubeconfig secrets
- [ ] Test first deployment
- [ ] Customize for your needs

---

**Implementation Complete!** 🎉

This platform provides a production-ready foundation for deploying microservices across multiple environments with trunk-based development, feature flags, and automated CI/CD.
