.PHONY: help install test lint build deploy-local clean validate-helm

help:
	@echo "Microservices Platform - Available Commands"
	@echo ""
	@echo "  make install         - Install Python dependencies for all services"
	@echo "  make test            - Run tests for all services"
	@echo "  make lint            - Lint and validate Helm charts"
	@echo "  make build           - Build all Docker images locally"
	@echo "  make deploy-local    - Deploy to local Kubernetes cluster"
	@echo "  make validate-helm   - Validate Helm charts for all environments"
	@echo "  make clean           - Clean up generated files"
	@echo ""

install:
	@echo "Installing dependencies for all services..."
	@for service in api-service worker-service web-frontend; do \
		echo "Installing dependencies for $$service..."; \
		pip install -r src/$$service/requirements.txt; \
	done
	@echo "Dependencies installed!"

test:
	@echo "Running tests for all services..."
	@for service in api-service worker-service web-frontend; do \
		echo "Testing $$service..."; \
		cd src/$$service && pytest tests/ -v --cov=. --cov-report=term || exit 1; \
		cd ../..; \
	done
	@echo "All tests passed!"

lint:
	@echo "Linting Helm charts..."
	@./scripts/validate-helm.sh

validate-helm:
	@echo "Validating Helm charts..."
	@./scripts/validate-helm.sh

build:
	@echo "Building Docker images..."
	@./scripts/build-images.sh

deploy-local:
	@echo "Deploying to local Kubernetes..."
	@ENVIRONMENT=dev IMAGE_TAG=local ./scripts/deploy.sh dev

clean:
	@echo "Cleaning up..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "coverage.xml" -delete 2>/dev/null || true
	@find . -type f -name ".coverage" -delete 2>/dev/null || true
	@rm -rf helm/umbrella/charts 2>/dev/null || true
	@rm -f helm/umbrella/Chart.lock 2>/dev/null || true
	@echo "Cleanup complete!"

# Individual service commands
test-api:
	@cd src/api-service && pytest tests/ -v

test-worker:
	@cd src/worker-service && pytest tests/ -v

test-frontend:
	@cd src/web-frontend && pytest tests/ -v

build-api:
	@docker build -f docker/api-service/Dockerfile -t ghcr.io/YOUR_ORG/api-service:local .

build-worker:
	@docker build -f docker/worker-service/Dockerfile -t ghcr.io/YOUR_ORG/worker-service:local .

build-frontend:
	@docker build -f docker/web-frontend/Dockerfile -t ghcr.io/YOUR_ORG/web-frontend:local .
