# Development Guide

This guide covers local development setup, testing, and best practices for contributing to the microservices platform.

## Table of Contents

- [Getting Started](#getting-started)
- [Local Development](#local-development)
- [Testing](#testing)
- [Adding New Services](#adding-new-services)
- [Best Practices](#best-practices)
- [Workflow](#workflow)

## Getting Started

### Prerequisites

- Python 3.11+
- Docker Desktop (with Kubernetes enabled) or Minikube
- Helm 3.x
- kubectl
- git

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_ORG/microservices-platform.git
   cd microservices-platform
   ```

2. **Install dependencies:**
   ```bash
   make install
   ```

3. **Verify setup:**
   ```bash
   make test
   make lint
   ```

## Local Development

### Running Services Locally

#### Individual Service (Python)

```bash
# API Service
cd src/api-service
pip install -r requirements.txt
python main.py

# Worker Service
cd src/worker-service
pip install -r requirements.txt
python main.py

# Web Frontend
cd src/web-frontend
pip install -r requirements.txt
python main.py
```

#### Using Docker

```bash
# Build all images
make build

# Or build individual services
docker build -f docker/api-service/Dockerfile -t api-service:local .

# Run individual service
docker run -p 8080:8080 -e ENVIRONMENT=local api-service:local
```

#### Using Docker Compose (Optional)

Create `docker-compose.yml` in project root:

```yaml
version: '3.8'
services:
  api-service:
    build:
      context: .
      dockerfile: docker/api-service/Dockerfile
    ports:
      - "8081:8080"
    environment:
      - ENVIRONMENT=local
      - FEATURE_NEW_UI=false
      - FEATURE_BETA=false

  worker-service:
    build:
      context: .
      dockerfile: docker/worker-service/Dockerfile
    ports:
      - "8082:8080"
    environment:
      - ENVIRONMENT=local
      - JOB_INTERVAL=60

  web-frontend:
    build:
      context: .
      dockerfile: docker/web-frontend/Dockerfile
    ports:
      - "8080:8080"
    environment:
      - ENVIRONMENT=local
      - API_SERVICE_URL=http://api-service:8080
```

Run: `docker-compose up`

### Local Kubernetes Deployment

```bash
# Enable Kubernetes in Docker Desktop
# Or start Minikube: minikube start

# Deploy to local cluster
make deploy-local

# Verify deployment
kubectl get pods -n dev
kubectl get svc -n dev

# Port forward to access services
kubectl port-forward svc/microservices-platform-web-frontend 8080:80 -n dev
kubectl port-forward svc/microservices-platform-api-service 8081:80 -n dev
```

Access services:
- Web Frontend: http://localhost:8080
- API Service: http://localhost:8081

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run tests for specific service
make test-api
make test-worker
make test-frontend

# Or manually
cd src/api-service
pytest tests/ -v --cov=. --cov-report=html
```

### Writing Tests

Example test structure:

```python
# src/api-service/tests/test_api.py
import pytest
from main import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_endpoint(client):
    response = client.get('/api/items')
    assert response.status_code == 200
    data = response.get_json()
    assert 'items' in data
```

### Test Coverage

```bash
# Generate coverage report
cd src/api-service
pytest tests/ --cov=. --cov-report=html

# Open coverage report
open htmlcov/index.html
```

## Adding New Services

### Step 1: Create Service Code

```bash
# Create directory structure
mkdir -p src/new-service/tests
mkdir -p docker

# Create main.py
cat > src/new-service/main.py << 'EOF'
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'service': 'new-service'}), 200

@app.route('/ready')
def ready():
    return jsonify({'status': 'ready', 'service': 'new-service'}), 200

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
EOF

# Create requirements.txt
cat > src/new-service/requirements.txt << 'EOF'
Flask==3.0.0
gunicorn==21.2.0
pytest==7.4.3
EOF
```

### Step 2: Create Dockerfile

```dockerfile
# docker/new-service/Dockerfile
FROM python:3.11-slim AS builder
WORKDIR /build
COPY src/new-service/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.11-slim
RUN groupadd -r appuser && useradd -r -g appuser appuser
WORKDIR /app
COPY --from=builder /root/.local /home/appuser/.local
COPY src/new-service/ .
RUN chown -R appuser:appuser /app
USER appuser
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1
ENV PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "60", "main:app"]
```

### Step 3: Create Helm Chart

```bash
# Copy existing chart as template
cp -r helm/services/api-service helm/services/new-service

# Update Chart.yaml
sed -i '' 's/api-service/new-service/g' helm/services/new-service/Chart.yaml
sed -i '' 's/API Service/New Service/g' helm/services/new-service/Chart.yaml

# Update all templates
find helm/services/new-service -type f -exec sed -i '' 's/api-service/new-service/g' {} +
```

### Step 4: Add to Umbrella Chart

Edit `helm/umbrella/Chart.yaml`:

```yaml
dependencies:
  # ... existing dependencies ...
  - name: new-service
    version: 1.0.0
    repository: "file://../services/new-service"
    condition: new-service.enabled
```

Edit `helm/umbrella/values.yaml`:

```yaml
# ... existing services ...

new-service:
  enabled: true
  replicaCount: 2
  image:
    repository: ghcr.io/YOUR_ORG/new-service
    tag: "latest"
    pullPolicy: IfNotPresent
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
```

### Step 5: Update CI/CD

Edit `.github/workflows/ci.yaml`:

```yaml
strategy:
  matrix:
    service: [api-service, worker-service, web-frontend, new-service]  # Add new-service
```

### Step 6: Test and Deploy

```bash
# Validate
make lint

# Build
docker build -f docker/new-service/Dockerfile -t new-service:local .

# Deploy locally
make deploy-local

# Verify
kubectl get pods -n dev -l app.kubernetes.io/name=new-service
```

## Best Practices

### Code Style

- Follow PEP 8 for Python code
- Use meaningful variable and function names
- Add docstrings for functions and classes
- Keep functions small and focused

### Feature Flags

- Always develop new features behind feature flags
- Feature flags should be disabled by default
- Test with flags both enabled and disabled

Example:

```python
import os
FEATURE_NEW_API = os.getenv('FEATURE_NEW_API', 'false').lower() == 'true'

@app.route('/api/v2/items')
def list_items_v2():
    if not FEATURE_NEW_API:
        return jsonify({'error': 'Feature not enabled'}), 404
    # New implementation
```

### Secrets Management

- NEVER commit secrets to git
- Use environment variables for configuration
- Use Kubernetes Secrets for sensitive data
- Add secrets to `.gitignore`

### Docker Images

- Use multi-stage builds
- Run as non-root user
- Include health checks
- Minimize image size
- Pin base image versions

### Helm Charts

- Use values files for configuration
- Parameterize all deployable values
- Include resource limits
- Add liveness and readiness probes
- Use labels consistently

## Workflow

### Trunk-Based Development

1. **Create feature branch:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/my-feature
   ```

2. **Develop with feature flag disabled:**
   ```python
   FEATURE_MY_FEATURE = os.getenv('FEATURE_MY_FEATURE', 'false').lower() == 'true'

   if FEATURE_MY_FEATURE:
       # New code
   ```

3. **Test locally:**
   ```bash
   make test
   make lint
   make build
   ```

4. **Commit changes:**
   ```bash
   git add .
   git commit -m "Add my feature behind feature flag"
   ```

5. **Push and create PR:**
   ```bash
   git push origin feature/my-feature
   # Create PR on GitHub
   ```

6. **Get reviews and merge:**
   - Get 2 approvals
   - All CI checks pass
   - Squash and merge to main

7. **Verify in dev:**
   - Automatically deploys to dev
   - Test with feature flag disabled (default)

8. **Enable feature flag in dev:**
   ```yaml
   # helm/umbrella/values-dev.yaml
   global:
     featureFlags:
       myFeatureEnabled: true
   ```

9. **Test and iterate in dev**

10. **Promote to staging and production:**
    - Deploy to staging with flag
    - Test thoroughly
    - Enable flag in production when ready
    - Remove flag after stable rollout

### Git Commit Messages

Good commit messages:

```
Add user authentication endpoint

- Implement JWT token generation
- Add login endpoint
- Include token refresh logic
- Add unit tests

Feature flag: FEATURE_AUTH (disabled by default)
```

### PR Guidelines

- Keep PRs small and focused
- Include tests for new code
- Update documentation
- Use PR template
- Link to related issues
- Explain "why" not just "what"

## Useful Commands

```bash
# Development
make install          # Install dependencies
make test            # Run tests
make lint            # Validate Helm charts
make build           # Build Docker images
make deploy-local    # Deploy to local k8s

# Individual services
make test-api        # Test API service
make build-api       # Build API service image

# Kubernetes
kubectl get pods -n dev
kubectl logs -f [pod-name] -n dev
kubectl port-forward svc/[service] 8080:80 -n dev
kubectl describe pod [pod-name] -n dev

# Helm
helm list -n dev
helm history microservices-platform -n dev
helm get values microservices-platform -n dev
```

## Troubleshooting

### Python Import Errors

```bash
# Make sure you're in the service directory
cd src/api-service
pip install -r requirements.txt
python main.py
```

### Docker Build Failures

```bash
# Clear Docker cache
docker system prune -a

# Rebuild without cache
docker build --no-cache -f docker/api-service/Dockerfile -t api-service:local .
```

### Helm Validation Errors

```bash
# Update dependencies
cd helm/umbrella
helm dependency update

# Validate templates
helm template test . -f values-dev.yaml --debug
```

## Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
