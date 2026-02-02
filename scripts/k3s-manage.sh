#!/bin/bash
set -e

# K3s Cluster Management Script
# Provides easy commands for managing the local k3s cluster

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

check_k3s_installed() {
    if command -v k3s &> /dev/null; then
        return 0
    else
        return 1
    fi
}

cmd_install() {
    log_info "Installing k3s..."

    if check_k3s_installed; then
        log_warning "k3s is already installed"
        k3s --version | head -n1
        exit 0
    fi

    # Install k3s
    log_info "Downloading and installing k3s..."
    curl -sfL https://get.k3s.io | sh -s - \
        --write-kubeconfig-mode 644 \
        --disable traefik \
        --disable servicelb

    log_info "Waiting for k3s to be ready..."
    sleep 10

    # Configure kubectl
    log_info "Configuring kubectl..."
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    chmod 600 ~/.kube/config

    # Create namespaces
    log_info "Creating namespaces..."
    kubectl create namespace dev
    kubectl create namespace monitoring

    log_success "k3s installed successfully!"
    kubectl get nodes
}

cmd_uninstall() {
    log_warning "This will completely remove k3s and all data!"
    read -p "Are you sure? (yes/no): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
        log_info "Uninstalling k3s..."
        sudo /usr/local/bin/k3s-uninstall.sh
        log_success "k3s uninstalled successfully!"
    else
        log_error "k3s uninstall script not found"
        exit 1
    fi
}

cmd_status() {
    if ! check_k3s_installed; then
        log_error "k3s is not installed"
        exit 1
    fi

    echo ""
    echo "=== K3s Cluster Status ==="
    echo ""

    log_info "Version:"
    k3s --version | head -n1
    echo ""

    log_info "Nodes:"
    kubectl get nodes -o wide
    echo ""

    log_info "Namespaces:"
    kubectl get namespaces
    echo ""

    log_info "All pods:"
    kubectl get pods -A
    echo ""

    log_info "Services in dev namespace:"
    kubectl get services -n dev 2>/dev/null || echo "No services in dev namespace"
    echo ""

    log_info "Cluster resource usage:"
    kubectl top nodes 2>/dev/null || log_warning "Metrics server not available"
    echo ""
}

cmd_restart() {
    if ! check_k3s_installed; then
        log_error "k3s is not installed"
        exit 1
    fi

    log_info "Restarting k3s..."
    sudo systemctl restart k3s

    log_info "Waiting for k3s to be ready..."
    sleep 5

    kubectl get nodes
    log_success "k3s restarted successfully!"
}

cmd_logs() {
    if ! check_k3s_installed; then
        log_error "k3s is not installed"
        exit 1
    fi

    log_info "K3s service logs (last 50 lines):"
    sudo journalctl -u k3s -n 50 --no-pager
}

cmd_kubeconfig() {
    if ! check_k3s_installed; then
        log_error "k3s is not installed"
        exit 1
    fi

    log_info "Kubeconfig location: ~/.kube/config"
    echo ""
    log_info "To use kubectl from another machine, copy this config:"
    echo ""
    cat ~/.kube/config
}

cmd_upgrade() {
    if ! check_k3s_installed; then
        log_error "k3s is not installed"
        exit 1
    fi

    log_info "Current version:"
    k3s --version | head -n1
    echo ""

    log_info "Upgrading k3s..."
    curl -sfL https://get.k3s.io | sh -s - \
        --write-kubeconfig-mode 644 \
        --disable traefik \
        --disable servicelb

    log_info "Waiting for upgrade to complete..."
    sleep 15

    log_success "k3s upgraded successfully!"
    k3s --version | head -n1
    kubectl get nodes
}

cmd_reset() {
    log_warning "This will delete all resources in the dev namespace!"
    read -p "Are you sure? (yes/no): " -r
    echo

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Reset cancelled"
        exit 0
    fi

    log_info "Deleting all resources in dev namespace..."
    kubectl delete all --all -n dev

    log_success "Dev namespace reset complete!"
}

cmd_help() {
    cat << EOF
K3s Cluster Management Script

Usage: $0 <command>

Commands:
    install     Install k3s cluster
    uninstall   Completely remove k3s cluster
    status      Show cluster status and information
    restart     Restart k3s service
    logs        Show k3s service logs
    kubeconfig  Display kubeconfig
    upgrade     Upgrade k3s to latest version
    reset       Delete all resources in dev namespace
    help        Show this help message

Examples:
    $0 install          # Install k3s
    $0 status           # Check cluster status
    $0 logs             # View logs
    $0 upgrade          # Upgrade to latest version

EOF
}

# Main command dispatcher
case "${1:-}" in
    install)
        cmd_install
        ;;
    uninstall)
        cmd_uninstall
        ;;
    status)
        cmd_status
        ;;
    restart)
        cmd_restart
        ;;
    logs)
        cmd_logs
        ;;
    kubeconfig)
        cmd_kubeconfig
        ;;
    upgrade)
        cmd_upgrade
        ;;
    reset)
        cmd_reset
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