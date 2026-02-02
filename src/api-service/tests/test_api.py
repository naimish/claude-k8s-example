"""
Unit tests for API service
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
    assert data['service'] == 'api-service'
    assert 'timestamp' in data


def test_readiness_endpoint(client):
    """Test readiness check endpoint"""
    response = client.get('/ready')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'ready'
    assert data['service'] == 'api-service'


def test_info_endpoint(client):
    """Test info endpoint"""
    response = client.get('/api/info')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['service'] == 'api-service'
    assert 'version' in data
    assert 'uptime_seconds' in data
    assert 'features' in data


def test_list_items_endpoint(client):
    """Test list items endpoint"""
    response = client.get('/api/items')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'items' in data
    assert 'count' in data
    assert data['count'] == 3


def test_create_item_endpoint(client):
    """Test create item endpoint"""
    item_data = {
        'name': 'Test Item',
        'description': 'Test description'
    }
    response = client.post('/api/items',
                          data=json.dumps(item_data),
                          content_type='application/json')
    assert response.status_code == 201
    data = json.loads(response.data)
    assert 'item' in data
    assert data['item']['name'] == 'Test Item'


def test_create_item_missing_name(client):
    """Test create item with missing name"""
    item_data = {'description': 'No name'}
    response = client.post('/api/items',
                          data=json.dumps(item_data),
                          content_type='application/json')
    assert response.status_code == 400
    data = json.loads(response.data)
    assert 'error' in data


def test_root_endpoint(client):
    """Test root endpoint"""
    response = client.get('/')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['service'] == 'api-service'
    assert 'endpoints' in data


def test_not_found(client):
    """Test 404 handler"""
    response = client.get('/nonexistent')
    assert response.status_code == 404
    data = json.loads(response.data)
    assert 'error' in data
