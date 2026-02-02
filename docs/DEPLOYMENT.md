# Deployment Guide

This guide covers deployment procedures, troubleshooting, and operational tasks for the microservices platform.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Deployment Procedures](#deployment-procedures)
- [Rollback Procedures](#rollback-procedures)
- [Troubleshooting](#troubleshooting)
- [Monitoring](#monitoring)

## Prerequisites

### Required Tools

- Helm 3.x
- kubectl 1.28+
- Access to Kubernetes clusters (dev, staging, production)
- GitHub CLI (optional, for workflow management)

### Required Secrets

Configure these secrets in GitHub repository settings:

#### Repository Secrets
- `SLACK_WEBHOOK` (optional) - For deployment notifications

#### Environment Secrets

**Dev Environment:**
- `KUBECONFIG_DEV` - Base64-encoded kubeconfig for dev cluster

**Staging Environment:**
- `KUBECONFIG_STAGING` - Base64-encoded kubeconfig for staging cluster

**Production Environment:**
- `KUBECONFIG_PROD` - Base64-encoded kubeconfig for production cluster

### Creating Kubeconfig Secrets

```bash
# Encode your kubeconfig
cat ~/.kube/config | base64 | pbcopy

# Add to GitHub:
# Settings → Environments → [environment] → Add secret
# Name: KUBECONFIG_[ENV]
# Value: [paste the base64 string]
```

## Environment Setup

### GitHub Environment Configuration

Configure protection rules for each environment:

**Dev:**
- No approval required
- Auto-deploys on merge to main

**Staging:**
- Require 1 reviewer approval
- Manual promotion via workflow_dispatch

**Production:**
- Require 2 reviewer approvals
- 5 minute wait time before deployment
- Manual promotion via workflow_dispatch

### Branch Protection Rules

Configure for `main` branch:
- Require 2 PR approvals
- Require status checks to pass
- Dismiss stale reviews on new commits
- Require code owner review
- Enforce linear history
- No force pushes
- Require conversation resolution

## Deployment Procedures

### Automatic Deployment to Dev

Dev deployments happen automatically when code is merged to `main`:

1. Create feature branch
2. Make changes
3. Open PR
4. Get 2 approvals
5. Merge to main → automatic deploy to dev

Monitor deployment:
```bash
# Via GitHub Actions UI
# Or watch pods directly:
kubectl get pods -n dev -l app.kubernetes.io/instance=microservices-platform -w
```

### Manual Deployment to Staging

1. **Identify image tag to deploy:**
   ```bash
   # Find SHA from recent commit
   git log --oneline -n 10
   # Or view in GitHub Actions → CI Pipeline
   ```

2. **Trigger deployment:**
   - Go to GitHub Actions → CD - Deploy to Staging
   - Click "Run workflow"
   - Enter image tag (e.g., `main-abc123`)
   - Click "Run workflow"

3. **Approve deployment:**
   - Reviewer approves the deployment request
   - Deployment proceeds automatically

4. **Verify deployment:**
   ```bash
   kubectl get pods -n staging -l app.kubernetes.io/instance=microservices-platform
   kubectl get hpa -n staging
   ```

### Manual Deployment to Production

1. **Pre-deployment checklist:**
   - [ ] Changes tested in staging
   - [ ] QA sign-off received
   - [ ] Change request approved (if required)
   - [ ] Rollback plan prepared
   - [ ] Team notified

2. **Trigger deployment:**
   - Go to GitHub Actions → CD - Deploy to Production
   - Click "Run workflow"
   - Enter image tag (SAME tag deployed to staging)
   - Click "Run workflow"

3. **Approve deployment:**
   - 2 reviewers approve the deployment request
   - Wait 5 minutes (automatic)
   - Deployment proceeds

4. **Monitor deployment:**
   - Watch GitHub Actions logs
   - Monitor pods: `kubectl get pods -n production -w`
   - Check metrics/dashboards

5. **Post-deployment verification:**
   - 5-minute soak period (automatic)
   - Smoke tests run (automatic)
   - Verify all pods healthy
   - Check HPA status
   - Monitor error rates

### Local/Manual Deployment

Using the deployment script:

```bash
# Deploy to dev
./scripts/deploy.sh dev

# Deploy to staging with specific tag
IMAGE_TAG=main-abc123 ./scripts/deploy.sh staging

# Deploy to production (requires confirmation)
IMAGE_TAG=main-abc123 ./scripts/deploy.sh prod
```

Using Helm directly:

```bash
# Update dependencies
cd helm/umbrella
helm dependency update

# Deploy to dev
helm upgrade --install microservices-platform helm/umbrella \
  --namespace dev \
  --create-namespace \
  --values helm/umbrella/values-dev.yaml \
  --wait

# Deploy to staging
helm upgrade --install microservices-platform helm/umbrella \
  --namespace staging \
  --create-namespace \
  --values helm/umbrella/values-staging.yaml \
  --set api-service.image.tag=main-abc123 \
  --set worker-service.image.tag=main-abc123 \
  --set web-frontend.image.tag=main-abc123 \
  --wait

# Deploy to production
helm upgrade --install microservices-platform helm/umbrella \
  --namespace production \
  --create-namespace \
  --values helm/umbrella/values-prod.yaml \
  --set api-service.image.tag=main-abc123 \
  --set worker-service.image.tag=main-abc123 \
  --set web-frontend.image.tag=main-abc123 \
  --atomic \
  --wait \
  --timeout 15m
```

## Rollback Procedures

### Automatic Rollback

Production deployments use Helm's `--atomic` flag, which automatically rolls back on failure.

### Manual Rollback

**Using Helm:**

```bash
# List deployment history
helm history microservices-platform -n production

# Rollback to previous version
helm rollback microservices-platform -n production

# Rollback to specific revision
helm rollback microservices-platform 5 -n production
```

**Using GitHub Actions:**

Re-run the deployment workflow with the previous known-good image tag.

### Emergency Rollback

If immediate rollback is needed:

```bash
# Get previous image tags
kubectl describe deployment microservices-platform-api-service -n production | grep Image

# Rollback via Helm
helm rollback microservices-platform -n production

# Or manually set previous image
kubectl set image deployment/microservices-platform-api-service \
  api-service=ghcr.io/YOUR_ORG/api-service:main-previous-sha \
  -n production
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n [namespace]

# Describe pod
kubectl describe pod [pod-name] -n [namespace]

# Check logs
kubectl logs [pod-name] -n [namespace]

# Check events
kubectl get events -n [namespace] --sort-by='.lastTimestamp' | tail -20
```

Common issues:
- **ImagePullBackOff**: Image tag doesn't exist or registry access issue
- **CrashLoopBackOff**: Application crashing on startup
- **Pending**: Insufficient resources or scheduling issues

### Deployment Stuck

```bash
# Check deployment status
kubectl rollout status deployment/microservices-platform-api-service -n [namespace]

# View deployment events
kubectl describe deployment microservices-platform-api-service -n [namespace]

# Force restart if needed
kubectl rollout restart deployment/microservices-platform-api-service -n [namespace]
```

### Health Check Failures

```bash
# Test health endpoints manually
POD_NAME=$(kubectl get pod -n [namespace] -l app.kubernetes.io/name=api-service -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n [namespace] $POD_NAME -- curl http://localhost:8080/health
kubectl exec -n [namespace] $POD_NAME -- curl http://localhost:8080/ready
```

### HPA Not Scaling

```bash
# Check HPA status
kubectl get hpa -n [namespace]

# Describe HPA
kubectl describe hpa microservices-platform-api-service -n [namespace]

# Check metrics server
kubectl top pods -n [namespace]
```

### Resource Issues

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n [namespace]

# Check resource limits
kubectl describe pod [pod-name] -n [namespace] | grep -A 10 Resources
```

## Monitoring

### Key Metrics to Monitor

- Pod health and readiness
- Deployment status
- HPA metrics (CPU/Memory utilization)
- Error rates
- Request latency
- Resource utilization

### Useful Commands

```bash
# Watch pods
kubectl get pods -n production -l app.kubernetes.io/instance=microservices-platform -w

# View logs
kubectl logs -f deployment/microservices-platform-api-service -n production

# Check HPA
kubectl get hpa -n production -w

# View events
kubectl get events -n production --sort-by='.lastTimestamp' -w

# Resource usage
kubectl top pods -n production -l app.kubernetes.io/instance=microservices-platform
```

### Health Check URLs

When port-forwarded or via ingress:

- API Service: `http://[host]/health`, `http://[host]/ready`, `http://[host]/api/info`
- Worker Service: `http://[host]/health`, `http://[host]/metrics`
- Web Frontend: `http://[host]/health`, `http://[host]/api/status`

## Maintenance

### Updating Helm Charts

1. Make changes to Helm charts
2. Validate: `make lint`
3. Test locally
4. Open PR
5. Deploy to dev (automatic)
6. Test in dev
7. Promote to staging
8. Promote to production

### Scaling Services

Update replica counts in environment-specific values files:

```yaml
# helm/umbrella/values-prod.yaml
api-service:
  replicaCount: 10  # Increase from 5 to 10
  autoscaling:
    minReplicas: 10
    maxReplicas: 30
```

Apply via normal deployment process.

### Updating Feature Flags

Update in values files:

```yaml
# helm/umbrella/values-dev.yaml
global:
  featureFlags:
    newUIEnabled: true  # Enable feature
```

Deploy to apply changes.

## Support

For issues or questions:
- Check existing GitHub issues
- Create new issue with deployment logs
- Contact platform team
