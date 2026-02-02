#!/bin/bash
# Manual deployment helper script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELM_DIR="${PROJECT_ROOT}/helm"

# Default values
ENVIRONMENT="${1:-dev}"
NAMESPACE="${NAMESPACE:-$ENVIRONMENT}"
RELEASE_NAME="${RELEASE_NAME:-microservices-platform}"
IMAGE_TAG="${IMAGE_TAG:-local}"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo "Error: Invalid environment. Must be dev, staging, or prod"
    echo "Usage: $0 <environment> [options]"
    exit 1
fi

echo "Deploying to ${ENVIRONMENT} environment..."
echo "Namespace: ${NAMESPACE}"
echo "Release: ${RELEASE_NAME}"
echo "Image tag: ${IMAGE_TAG}"
echo ""

# Update dependencies
echo "Updating Helm dependencies..."
cd "${HELM_DIR}/umbrella"
helm dependency update
echo ""

# Prepare deployment command
HELM_CMD="helm upgrade --install ${RELEASE_NAME} ${HELM_DIR}/umbrella"
HELM_CMD+=" --namespace ${NAMESPACE}"
HELM_CMD+=" --create-namespace"
HELM_CMD+=" --values ${HELM_DIR}/umbrella/values-${ENVIRONMENT}.yaml"

# Set image tags
HELM_CMD+=" --set api-service.image.tag=${IMAGE_TAG}"
HELM_CMD+=" --set worker-service.image.tag=${IMAGE_TAG}"
HELM_CMD+=" --set web-frontend.image.tag=${IMAGE_TAG}"

# Production-specific flags
if [ "$ENVIRONMENT" = "prod" ]; then
    HELM_CMD+=" --atomic"
    HELM_CMD+=" --timeout 15m"
else
    HELM_CMD+=" --timeout 10m"
fi

HELM_CMD+=" --wait"

# Show command
echo "Executing:"
echo "$HELM_CMD"
echo ""

# Confirm for production
if [ "$ENVIRONMENT" = "prod" ]; then
    read -p "Deploy to PRODUCTION? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled"
        exit 0
    fi
fi

# Execute deployment
eval "$HELM_CMD"

echo ""
echo "Deployment complete!"
echo ""

# Show deployment status
echo "=== Deployment Status ==="
kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/instance="${RELEASE_NAME}"
echo ""
kubectl get svc -n "${NAMESPACE}" -l app.kubernetes.io/instance="${RELEASE_NAME}"

# Show HPA if available
if kubectl get hpa -n "${NAMESPACE}" -l app.kubernetes.io/instance="${RELEASE_NAME}" 2>/dev/null | grep -q .; then
    echo ""
    kubectl get hpa -n "${NAMESPACE}" -l app.kubernetes.io/instance="${RELEASE_NAME}"
fi

echo ""
echo "Deployment to ${ENVIRONMENT} completed successfully!"
echo ""
echo "To rollback:"
echo "  helm rollback ${RELEASE_NAME} -n ${NAMESPACE}"
