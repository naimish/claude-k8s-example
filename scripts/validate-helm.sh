#!/bin/bash
# Validate Helm charts locally

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELM_DIR="${PROJECT_ROOT}/helm"

echo "Validating Helm charts..."
echo ""

# Lint individual service charts
echo "=== Linting individual service charts ==="
for chart in "${HELM_DIR}/services"/*; do
    if [ -d "$chart" ]; then
        chart_name=$(basename "$chart")
        echo "Linting ${chart_name}..."
        helm lint "$chart"
        echo "✓ ${chart_name} passed"
        echo ""
    fi
done

# Update umbrella chart dependencies
echo "=== Updating umbrella chart dependencies ==="
cd "${HELM_DIR}/umbrella"
helm dependency update
echo "✓ Dependencies updated"
echo ""

# Lint umbrella chart
echo "=== Linting umbrella chart ==="
helm lint "${HELM_DIR}/umbrella"
echo "✓ Umbrella chart passed"
echo ""

# Validate templates for each environment
ENVIRONMENTS=("dev" "staging" "prod")

for env in "${ENVIRONMENTS[@]}"; do
    echo "=== Validating ${env} environment templates ==="

    if [ "$env" = "dev" ]; then
        helm template test "${HELM_DIR}/umbrella" \
            -f "${HELM_DIR}/umbrella/values-${env}.yaml" \
            > /dev/null
    else
        helm template test "${HELM_DIR}/umbrella" \
            -f "${HELM_DIR}/umbrella/values-${env}.yaml" \
            --set api-service.image.tag=test \
            --set worker-service.image.tag=test \
            --set web-frontend.image.tag=test \
            > /dev/null
    fi

    echo "✓ ${env} templates valid"
    echo ""
done

echo "All Helm charts validated successfully!"
