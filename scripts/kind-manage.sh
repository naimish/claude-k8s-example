#!/bin/bash
set -e

# kind Cluster Management Script for macOS
# Provides easy commands for managing local kind Kubernetes clusters

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLUSTER_NAME="${KIND_CLUSTER_NAME:-dev-cluster}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running"
        echo "Please start Docker Desktop and try again"
        exit 1
    fi
}

check_kind_installed() {
    if command -v kind &> /dev/null; then
        return 0
    else
        return 1
    fi
}

check_kubectl_installed() {
    if command -v kubectl &> /dev/null; then
        return 0
    else
        return 1
    fi
}

check_cluster_exists() {
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        return 0
    else
        return 1
    fi
}

install_kind() {
    log_info "Installing kind..."

    # Detect architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    fi

    # Download kind
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-${ARCH}
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind

    log_success "kind installed successfully!"
    kind version
}

install_kubectl() {
    log_info "Installing kubectl..."

    # Detect architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
        ARCH="arm64"
    fi

    # Download kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/${ARCH}/kubectl"
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl

    log_success "kubectl installed successfully!"
    kubectl version --client
}

cmd_install() {
    log_info "Setting up kind cluster: ${CLUSTER_NAME}"

    # Check Docker
    check_docker
    log_success "Docker is running"

    # Install kind if needed
    if ! check_kind_installed; then
        install_kind
    else
        log_info "kind is already installed: $(kind version)"
    fi

    # Install kubectl if needed
    if ! check_kubectl_installed; then
        install_kubectl
    else
        log_info "kubectl is already installed: $(kubectl version --client --short 2>/dev/null || echo 'installed')"
    fi

    # Check if cluster exists
    if check_cluster_exists; then
        log_warning "Cluster '${CLUSTER_NAME}' already exists"
        echo "Use 'recreate' to delete and recreate it"
        exit 0
    fi

    # Create cluster config
    log_info "Creating cluster configuration..."
    cat > /tmp/kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  # API server
  - containerPort: 6443
    hostPort: 6443
    protocol: TCP
  # HTTP
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  # HTTPS
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
  # NodePort range
  - containerPort: 30000
    hostPort: 30000
    protocol: TCP
  - containerPort: 30001
    hostPort: 30001
    protocol: TCP
  - containerPort: 30002
    hostPort: 30002
    protocol: TCP
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
EOF

    # Create cluster
    log_info "Creating kind cluster..."
    kind create cluster --name ${CLUSTER_NAME} --config /tmp/kind-config.yaml --wait 60s

    log_success "Cluster created!"

    # Install NGINX Ingress
    log_info "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    log_info "Waiting for ingress controller..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s

    log_success "NGINX Ingress installed!"

    # Create namespaces
    log_info "Creating namespaces..."
    kubectl create namespace dev
    kubectl create namespace monitoring

    log_success "Setup complete!"
    echo ""
    log_info "Cluster: ${CLUSTER_NAME}"
    log_info "Context: kind-${CLUSTER_NAME}"
    log_info "API: https://127.0.0.1:6443"
    echo ""
    kubectl get nodes
}

cmd_delete() {
    if ! check_cluster_exists; then
        log_error "Cluster '${CLUSTER_NAME}' does not exist"
        exit 1
    fi

    log_warning "This will delete the cluster and all data!"
    read -p "Are you sure? (yes/no): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Delete cancelled"
        exit 0
    fi

    log_info "Deleting cluster..."
    kind delete cluster --name ${CLUSTER_NAME}
    log_success "Cluster deleted!"
}

cmd_recreate() {
    if check_cluster_exists; then
        log_info "Deleting existing cluster..."
        kind delete cluster --name ${CLUSTER_NAME}
    fi

    cmd_install
}

cmd_status() {
    echo ""
    echo "=== kind Cluster Status ==="
    echo ""

    # Check kind
    if ! check_kind_installed; then
        log_error "kind is not installed"
        echo "Run: $0 install"
        exit 1
    fi

    log_info "kind version: $(kind version)"
    echo ""

    # List clusters
    log_info "Clusters:"
    kind get clusters || echo "No clusters found"
    echo ""

    # Check if our cluster exists
    if ! check_cluster_exists; then
        log_warning "Cluster '${CLUSTER_NAME}' does not exist"
        echo "Run: $0 install"
        exit 0
    fi

    # Cluster info
    log_info "Cluster Info:"
    kubectl cluster-info --context kind-${CLUSTER_NAME}
    echo ""

    log_info "Nodes:"
    kubectl get nodes -o wide
    echo ""

    log_info "Namespaces:"
    kubectl get namespaces
    echo ""

    log_info "Pods (all namespaces):"
    kubectl get pods -A
    echo ""

    log_info "Services in dev:"
    kubectl get services -n dev 2>/dev/null || echo "No services"
    echo ""

    log_info "Docker containers:"
    docker ps --filter "name=${CLUSTER_NAME}"
    echo ""
}

cmd_logs() {
    if ! check_cluster_exists; then
        log_error "Cluster '${CLUSTER_NAME}' does not exist"
        exit 1
    fi

    log_info "Control plane logs:"
    docker logs ${CLUSTER_NAME}-control-plane --tail 50
}

cmd_load_image() {
    if [ -z "$2" ]; then
        log_error "Usage: $0 load-image <image:tag>"
        exit 1
    fi

    if ! check_cluster_exists; then
        log_error "Cluster '${CLUSTER_NAME}' does not exist"
        exit 1
    fi

    IMAGE=$2
    log_info "Loading image: ${IMAGE}"
    kind load docker-image ${IMAGE} --name ${CLUSTER_NAME}
    log_success "Image loaded!"
}

cmd_reset() {
    if ! check_cluster_exists; then
        log_error "Cluster '${CLUSTER_NAME}' does not exist"
        exit 1
    fi

    log_warning "This will delete all resources in the dev namespace!"
    read -p "Are you sure? (yes/no): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Reset cancelled"
        exit 0
    fi

    log_info "Deleting resources in dev namespace..."
    kubectl delete all --all -n dev
    log_success "Dev namespace reset!"
}

cmd_context() {
    if ! check_cluster_exists; then
        log_error "Cluster '${CLUSTER_NAME}' does not exist"
        exit 1
    fi

    kubectl config use-context kind-${CLUSTER_NAME}
    log_success "Switched to context: kind-${CLUSTER_NAME}"
}

cmd_help() {
    cat << EOF
kind Cluster Management Script for macOS

Usage: $0 <command> [options]

Commands:
    install       Install kind, kubectl, and create cluster
    delete        Delete the cluster
    recreate      Delete and recreate the cluster
    status        Show cluster status and information
    logs          Show control plane logs
    load-image    Load Docker image into cluster
    reset         Delete all resources in dev namespace
    context       Switch kubectl context to this cluster
    help          Show this help message

Environment Variables:
    KIND_CLUSTER_NAME    Cluster name (default: dev-cluster)

Examples:
    $0 install                              # Create cluster
    $0 status                               # Check status
    $0 load-image myapp:latest              # Load image
    KIND_CLUSTER_NAME=test $0 install       # Create cluster named 'test'

Port Mappings:
    localhost:8080  → cluster HTTP (port 80)
    localhost:8443  → cluster HTTPS (port 443)
    localhost:30000-30002 → NodePorts

EOF
}

# Main command dispatcher
case "${1:-}" in
    install)
        cmd_install
        ;;
    delete)
        cmd_delete
        ;;
    recreate)
        cmd_recreate
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    load-image)
        cmd_load_image "$@"
        ;;
    reset)
        cmd_reset
        ;;
    context)
        cmd_context
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        log_error "Unknown command: ${1:-}"
        echo ""
        cmd_help
        exit 1
        ;;
esac