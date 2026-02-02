#!/bin/bash
# Build all Docker images locally

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Building Docker images..."
echo "Project root: $PROJECT_ROOT"
echo ""

SERVICES=("api-service" "worker-service" "web-frontend")
REGISTRY="${REGISTRY:-ghcr.io/YOUR_ORG}"
TAG="${TAG:-local}"

for service in "${SERVICES[@]}"; do
    echo "Building ${service}..."
    docker build \
        -f "${PROJECT_ROOT}/docker/${service}/Dockerfile" \
        -t "${REGISTRY}/${service}:${TAG}" \
        "${PROJECT_ROOT}"
    echo "✓ Built ${REGISTRY}/${service}:${TAG}"
    echo ""
done

echo "All images built successfully!"
echo ""
echo "Images:"
docker images | grep -E "(REPOSITORY|${REGISTRY})" || true
