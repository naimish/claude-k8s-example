# kind Kubernetes Setup for macOS

Since macOS doesn't support k3s (which requires Linux systemd), we use **kind** (Kubernetes in Docker) instead. kind is perfect for local development and CI/CD on macOS.

## Prerequisites

- **Docker Desktop** installed and running
- macOS (Intel or Apple Silicon)
- Homebrew (optional, for easier installation)

## Quick Start

### Option 1: Automated Script (Easiest)

```bash
# Install and create cluster
./scripts/kind-manage.sh install

# Check status
./scripts/kind-manage.sh status
```

### Option 2: GitHub Actions Workflow

1. Go to **Actions** → **Provision kind Cluster**
2. Click **Run workflow**
3. Select action: **install**
4. Wait ~2-3 minutes

## What Gets Installed

✅ **kind** - Kubernetes in Docker
✅ **kubectl** - Kubernetes CLI
✅ **Kubernetes cluster** - Single-node development cluster
✅ **NGINX Ingress** - For HTTP/HTTPS routing
✅ **Namespaces** - dev and monitoring

## Port Mappings

- `localhost:6443` → Kubernetes API
- `localhost:8080` → HTTP (port 80 in cluster)
- `localhost:8443` → HTTPS (port 443 in cluster)
- `localhost:30000-30002` → NodePort services

## Daily Usage

### Check Cluster Status
```bash
./scripts/kind-manage.sh status
```

### View Logs
```bash
./scripts/kind-manage.sh logs
```

### Load Local Docker Image
```bash
# Build your image
docker build -t myapp:latest .

# Load into cluster
./scripts/kind-manage.sh load-image myapp:latest
```

### Reset Dev Namespace
```bash
./scripts/kind-manage.sh reset
```

### Delete Cluster
```bash
./scripts/kind-manage.sh delete
```

### Recreate Cluster
```bash
./scripts/kind-manage.sh recreate
```

## Accessing Services

### Via NodePort

```bash
# Deploy with NodePort service
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: my-service
  namespace: dev
spec:
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30000
  selector:
    app: my-app
EOF

# Access service
curl http://localhost:30000
```

### Via Ingress

```bash
# Create ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  namespace: dev
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 8080
EOF

# Access via localhost
curl http://localhost:8080
```

## Troubleshooting

### Docker Not Running

```bash
# Check Docker
docker info

# If not running, start Docker Desktop
open -a Docker
```

### Cluster Won't Start

```bash
# Check Docker resources
# Docker Desktop → Settings → Resources
# Ensure: CPU: 2+, Memory: 4GB+

# Delete and recreate
./scripts/kind-manage.sh recreate
```

### kubectl Connection Issues

```bash
# Check context
kubectl config current-context

# Should show: kind-dev-cluster

# Switch context if needed
./scripts/kind-manage.sh context
```

### Image Pull Errors

kind doesn't automatically pull images from registries. Either:

1. **Pre-load images:**
   ```bash
   docker pull ghcr.io/user/image:tag
   kind load docker-image ghcr.io/user/image:tag --name dev-cluster
   ```

2. **Configure imagePullSecrets:**
   ```bash
   kubectl create secret docker-registry ghcr-secret \
     --docker-server=ghcr.io \
     --docker-username=USERNAME \
     --docker-password=TOKEN \
     -n dev
   ```

### Out of Disk Space

```bash
# Clean up Docker
docker system prune -a

# Remove old kind clusters
kind get clusters
kind delete cluster --name old-cluster
```

## kind vs k3s

| Feature | kind | k3s |
|---------|------|-----|
| Platform | macOS, Linux, Windows | Linux only |
| Installation | Docker required | Native binary |
| Resource Usage | Higher (Docker overhead) | Lower |
| Use Case | Development, CI/CD | Edge, IoT, production |
| Multi-node | Easy | Requires multiple machines |
| Speed | Fast startup | Very fast |

## CI/CD Integration

The dev deployment workflow automatically detects and uses the kind cluster:

```bash
# After cluster creation
git push origin main
# → CI runs → Builds → Deploys to kind cluster
```

## Advanced Configuration

### Create Multi-Node Cluster

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
```

```bash
kind create cluster --config kind-config.yaml
```

### Mount Local Directory

```yaml
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /Users/you/data
    containerPath: /data
```

### Custom Kubernetes Version

```bash
kind create cluster --image kindest/node:v1.27.3
```

## Resources

- [kind Documentation](https://kind.sigs.k8s.io/)
- [kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [Ingress on kind](https://kind.sigs.k8s.io/docs/user/ingress/)
- [Local Registry with kind](https://kind.sigs.k8s.io/docs/user/local-registry/)

## Next Steps

1. ✅ Install kind cluster
2. 📦 Deploy your applications
3. 🔍 Test locally before pushing
4. 🚀 Push to trigger CI/CD
5. 🎉 Auto-deploy to kind cluster

```bash
# Quick deploy test
kubectl create deployment nginx --image=nginx -n dev
kubectl expose deployment nginx --port=80 --type=NodePort -n dev
kubectl get svc -n dev
```