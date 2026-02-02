"""
Unit tests for Web Frontend service
"""
import pytest
import json
import sys
import os

# Add parent directory to path to import main
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from main import app


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
    assert data['service'] == 'web-frontend'
    assert 'timestamp' in data


def test_readiness_endpoint(client):
    """Test readiness check endpoint"""
    response = client.get('/ready')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'ready'
    assert data['service'] == 'web-frontend'


def test_index_endpoint(client):
    """Test index page"""
    response = client.get('/')
    assert response.status_code == 200
    assert b'Microservices Platform' in response.data


def test_status_endpoint(client):
    """Test status API endpoint"""
    response = client.get('/api/status')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['service'] == 'web-frontend'
    assert 'version' in data
    assert 'uptime_seconds' in data
    assert 'features' in data
    assert 'new_ui_enabled' in data['features']
    assert 'beta_features_enabled' in data['features']
