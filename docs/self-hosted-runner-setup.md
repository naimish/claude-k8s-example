# Self-Hosted Runner Setup for Dev Environment

This guide explains how to set up a self-hosted GitHub Actions runner for the dev deployment workflow.

## Prerequisites

The self-hosted runner machine should have:

- Access to your Kubernetes cluster (dev environment)
- `kubectl` configured with appropriate credentials
- `helm` v3.13.0 or later installed
- Docker (for pulling images from ghcr.io)
- Network access to GitHub and your container registry

## Installation Steps

### 1. Set Up the Runner

Go to your GitHub repository:

```bash
Settings → Actions → Runners → New self-hosted runner
```

Follow the GitHub instructions to download and configure the runner.

### 2. Add the 'dev' Label

During runner setup or after installation, add the label `dev`:

```bash
# During initial configuration
./config.sh --url https://github.com/naimish/claude-k8s-example --token YOUR_TOKEN --labels dev

# Or add label to existing runner by reconfiguring
./config.sh remove
./config.sh --url https://github.com/naimish/claude-k8s-example --token YOUR_TOKEN --labels dev
```

### 3. Configure Kubernetes Access

Ensure the runner user has a valid kubeconfig:

```bash
# Test kubectl access
kubectl cluster-info
kubectl get nodes

# Verify namespace access
kubectl get namespaces
kubectl auth can-i create deployments -n dev
```

### 4. Install Required Tools

**Helm:**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

**kubectl:**
```bash
# If not already installed
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

### 5. Configure Container Registry Access

Ensure the runner can pull images from ghcr.io:

```bash
# Test image pull (replace with your actual image)
docker pull ghcr.io/naimish/api-service:main-latest
```

If authentication is needed:
```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u USERNAME --password-stdin
```

### 6. Start the Runner

```bash
# Start as a service (recommended)
sudo ./svc.sh install
sudo ./svc.sh start

# Or run interactively for testing
./run.sh
```

### 7. Verify Runner Status

Go to your repository on GitHub:
```
Settings → Actions → Runners
```

You should see your runner listed as "Idle" with the `dev` label.

## Runner Security Considerations

### Isolation
- Use a dedicated machine/VM for the runner
- Don't run other workloads on the same machine
- Consider using containers or VMs for additional isolation

### Network Security
- Restrict inbound traffic to only what's necessary
- Use firewall rules to limit access
- Consider VPN or private network for cluster access

### Credentials
- Use Kubernetes RBAC to limit runner permissions
- Create a dedicated service account for deployments
- Use namespace-scoped permissions

### Updates
- Keep the runner software updated
- Monitor GitHub for security advisories
- Regularly update kubectl, helm, and other tools

## Troubleshooting

### Runner Not Picking Up Jobs

Check runner status:
```bash
# If running as service
sudo ./svc.sh status

# Check logs
journalctl -u actions.runner.* -f
```

Verify labels:
```bash
# Runner config file should show labels
cat .runner
```

### Kubectl Connection Issues

Test cluster access:
```bash
kubectl cluster-info
kubectl get nodes -v=6  # Verbose output
```

Check kubeconfig:
```bash
echo $KUBECONFIG
cat ~/.kube/config
```

### Helm Deployment Failures

Verify Helm installation:
```bash
helm version
helm list -n dev
```

Check permissions:
```bash
kubectl auth can-i create deployments -n dev
kubectl auth can-i create services -n dev
```

### Image Pull Errors

Test registry access:
```bash
docker pull ghcr.io/naimish/api-service:main-latest
```

Check Docker credentials:
```bash
cat ~/.docker/config.json
```

## Monitoring

Monitor runner activity:

```bash
# Service logs
sudo journalctl -u actions.runner.* -f

# Runner logs directory
tail -f _diag/Runner_*.log
```

## Maintenance

### Updating the Runner

```bash
# Stop the service
sudo ./svc.sh stop

# Remove old version
sudo ./svc.sh uninstall

# Download new version from GitHub
# ... follow GitHub's update instructions ...

# Reinstall service
sudo ./svc.sh install
sudo ./svc.sh start
```

### Cleanup

```bash
# Stop and remove the service
sudo ./svc.sh stop
sudo ./svc.sh uninstall

# Remove the runner
./config.sh remove --token YOUR_TOKEN
```

## Alternative: Docker-based Runner

For better isolation, consider running the runner in Docker:

```bash
docker run -d --restart=always \
  --name github-runner-dev \
  -e GITHUB_TOKEN=YOUR_TOKEN \
  -e RUNNER_NAME=dev-runner \
  -e RUNNER_LABELS=dev \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /path/to/kubeconfig:/home/runner/.kube/config:ro \
  myoung34/github-runner:latest
```

## References

- [GitHub Actions Self-hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Helm Documentation](https://helm.sh/docs/)