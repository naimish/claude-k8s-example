# K3s Cluster Setup Guide

This guide explains how to provision and manage a production-grade k3s Kubernetes cluster on your self-hosted runner for the dev environment.

## What is K3s?

K3s is a lightweight, CNCF-certified Kubernetes distribution designed for production workloads in resource-constrained environments. It's perfect for:
- Development environments
- Edge computing
- IoT deployments
- CI/CD pipelines
- Single-node clusters

## Prerequisites

- Self-hosted GitHub Actions runner configured (see `self-hosted-runner-setup.md`)
- Linux system with systemd
- At least 1GB RAM (2GB+ recommended)
- Sudo/root access
- curl and basic utilities installed

## Installation Methods

### Method 1: Using GitHub Actions Workflow (Recommended)

1. **Navigate to Actions tab** in your GitHub repository

2. **Select "Provision K3s Cluster"** workflow

3. **Run workflow** with action: `install`

4. **Wait for completion** (typically 2-3 minutes)

The workflow will:
- Install k3s with optimized settings
- Configure kubectl for the runner user
- Create dev and monitoring namespaces
- Install NGINX Ingress Controller
- Set up GHCR registry credentials

### Method 2: Using the Management Script

On your self-hosted runner machine:

```bash
# Clone the repository if not already done
cd /path/to/claude-k8s-example

# Run the install command
./scripts/k3s-manage.sh install
```

### Method 3: Manual Installation

```bash
# Install k3s
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb

# Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Verify installation
kubectl get nodes
```

## Configuration Details

### K3s Installation Options

The cluster is installed with these flags:

- `--write-kubeconfig-mode 644`: Makes kubeconfig readable by non-root users
- `--disable traefik`: Disables built-in Traefik (we use NGINX Ingress)
- `--disable servicelb`: Disables built-in LoadBalancer (NodePort used instead)

### Components Installed

**Core:**
- K3s v1.28+ (latest stable)
- containerd runtime
- CoreDNS for service discovery
- Local-path storage provisioner

**Add-ons:**
- NGINX Ingress Controller
- Metrics server (optional)

### Namespaces Created

- `dev`: Main development namespace for applications
- `monitoring`: For monitoring tools (Prometheus, Grafana, etc.)
- `default`: Kubernetes default namespace
- `kube-system`: Kubernetes system components
- `ingress-nginx`: Ingress controller namespace

## Verification

After installation, verify the cluster:

```bash
# Check cluster status
./scripts/k3s-manage.sh status

# Or use kubectl directly
kubectl get nodes
kubectl get namespaces
kubectl get pods -A
```

Expected output:
```
NAME       STATUS   ROLES                  AGE   VERSION
runner-1   Ready    control-plane,master   10m   v1.28.x+k3s1
```

## Daily Operations

### Check Cluster Status

```bash
./scripts/k3s-manage.sh status
```

### View Logs

```bash
./scripts/k3s-manage.sh logs

# Or use journalctl directly
sudo journalctl -u k3s -f
```

### Restart K3s

```bash
./scripts/k3s-manage.sh restart
```

### Reset Dev Namespace

Deletes all resources in dev namespace:

```bash
./scripts/k3s-manage.sh reset
```

## Upgrading K3s

### Via GitHub Actions

Run the "Provision K3s Cluster" workflow with action: `upgrade`

### Via Management Script

```bash
./scripts/k3s-manage.sh upgrade
```

### Manual Upgrade

```bash
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb
```

K3s upgrades are generally safe and don't require cluster downtime for single-node setups.

## Accessing Services

### NodePort Services

Services are exposed on the node's IP address with high-numbered ports:

```bash
# Get service port
kubectl get service <service-name> -n dev

# Access service
curl http://<node-ip>:<node-port>
```

### Using Ingress

1. **Create an Ingress resource:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: dev
spec:
  ingressClassName: nginx
  rules:
  - host: app.local.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

2. **Add to /etc/hosts:**

```bash
echo "127.0.0.1 app.local.dev" | sudo tee -a /etc/hosts
```

3. **Access via Ingress:**

```bash
curl http://app.local.dev
```

## Troubleshooting

### K3s Service Won't Start

```bash
# Check service status
sudo systemctl status k3s

# View detailed logs
sudo journalctl -u k3s -n 100 --no-pager

# Check for port conflicts
sudo netstat -tulpn | grep :6443
```

### Kubectl Connection Refused

```bash
# Verify k3s is running
sudo systemctl status k3s

# Check kubeconfig permissions
ls -la ~/.kube/config

# Recreate kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

### Pods Stuck in Pending

```bash
# Check pod details
kubectl describe pod <pod-name> -n dev

# Check node resources
kubectl top node

# Check events
kubectl get events -n dev --sort-by='.lastTimestamp'
```

### Image Pull Errors

```bash
# Check registry secret
kubectl get secret ghcr-secret -n dev

# Recreate registry secret
kubectl delete secret ghcr-secret -n dev
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<token> \
  --namespace=dev
```

### Disk Space Issues

K3s stores data in `/var/lib/rancher/k3s/`:

```bash
# Check disk usage
df -h /var/lib/rancher/k3s/

# Clean up unused images
sudo k3s crictl rmi --prune

# Remove old pods
kubectl delete pods --field-selector=status.phase=Failed -n dev
```

## Resource Management

### Setting Resource Limits

Always set resource requests and limits:

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### Monitoring Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n dev

# Detailed node info
kubectl describe node
```

## Backup and Restore

### Backup

K3s stores data in `/var/lib/rancher/k3s/`:

```bash
# Backup etcd data (if using etcd)
sudo cp -r /var/lib/rancher/k3s/server/db /backup/k3s-db-$(date +%Y%m%d)

# Backup manifests
kubectl get all -n dev -o yaml > dev-namespace-backup.yaml
```

### Restore

```bash
# Stop k3s
sudo systemctl stop k3s

# Restore data
sudo cp -r /backup/k3s-db-20260202 /var/lib/rancher/k3s/server/db

# Start k3s
sudo systemctl start k3s

# Restore resources
kubectl apply -f dev-namespace-backup.yaml
```

## Uninstalling K3s

### Via GitHub Actions

Run the "Provision K3s Cluster" workflow with action: `uninstall`

### Via Management Script

```bash
./scripts/k3s-manage.sh uninstall
```

### Manual Uninstall

```bash
# Run the uninstall script
sudo /usr/local/bin/k3s-uninstall.sh

# Verify removal
which k3s  # Should return nothing
```

This removes:
- K3s binary and systemd service
- All cluster data
- Container images
- Network configuration

## Security Considerations

### Network Security

- K3s API server listens on `0.0.0.0:6443` by default
- Consider firewall rules to restrict access
- Use Network Policies for pod-to-pod communication

### RBAC

Create service accounts with limited permissions:

```bash
# Create service account
kubectl create serviceaccount deploy-bot -n dev

# Create role
kubectl create role deployer --verb=get,list,create,update,patch,delete --resource=deployments,services -n dev

# Bind role
kubectl create rolebinding deployer-binding --role=deployer --serviceaccount=dev:deploy-bot -n dev
```

### Secrets Management

Never commit secrets to Git. Use Kubernetes secrets:

```bash
# Create secret
kubectl create secret generic app-secrets \
  --from-literal=api-key=your-api-key \
  -n dev

# Use in pod
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: api-key
```

## Performance Tuning

### For Resource-Constrained Environments

```bash
# Install with reduced footprint
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb \
  --disable metrics-server \
  --kube-apiserver-arg default-not-ready-toleration-seconds=30 \
  --kube-apiserver-arg default-unreachable-toleration-seconds=30
```

### Adjust Pod Eviction Thresholds

Edit `/etc/systemd/system/k3s.service`:

```ini
--kubelet-arg=eviction-hard=memory.available<5%,nodefs.available<10%
--kubelet-arg=eviction-soft=memory.available<10%,nodefs.available<15%
```

## Integration with CI/CD

The dev deployment workflow automatically uses this k3s cluster. After installation:

1. Push code to main branch
2. CI pipeline builds and tests
3. If successful, deploys to k3s dev namespace
4. Accessible via NodePort or Ingress

## Additional Resources

- [K3s Documentation](https://docs.k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [K3s GitHub Repository](https://github.com/k3s-io/k3s)

## Support

For issues:
1. Check logs: `./scripts/k3s-manage.sh logs`
2. Review GitHub Actions workflow runs
3. Check K3s GitHub issues
4. Verify system requirements are met