"""
Unit tests for Worker service
"""
import pytest
import json
import sys
import os

# Add parent directory to path to import main
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from main import app, process_job


@pytest.fixture
def client():
    """Create test client"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_health_endpoint(client):
    """Test health check endpoint"""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'
    assert data['service'] == 'worker-service'
    assert 'timestamp' in data


def test_readiness_endpoint(client):
    """Test readiness check endpoint"""
    response = client.get('/ready')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'ready'
    assert data['service'] == 'worker-service'


def test_metrics_endpoint(client):
    """Test metrics endpoint"""
    response = client.get('/metrics')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['service'] == 'worker-service'
    assert 'uptime_seconds' in data
    assert 'jobs_processed' in data
    assert 'job_interval' in data


def test_process_job():
    """Test job processing function"""
    result = process_job('test-job-1')
    assert result is True
