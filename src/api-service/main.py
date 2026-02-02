"""
API Service - REST API with health and readiness endpoints
"""
import os
import logging
from datetime import datetime
from flask import Flask, jsonify, request

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Feature flags from environment
FEATURE_NEW_UI = os.getenv('FEATURE_NEW_UI', 'false').lower() == 'true'
FEATURE_BETA = os.getenv('FEATURE_BETA', 'false').lower() == 'true'
ENVIRONMENT = os.getenv('ENVIRONMENT', 'unknown')

# Application state
start_time = datetime.utcnow()
ready = True


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint - indicates if service is alive"""
    return jsonify({
        'status': 'healthy',
        'service': 'api-service',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/ready', methods=['GET'])
def readiness():
    """Readiness check endpoint - indicates if service can accept traffic"""
    if ready:
        return jsonify({
            'status': 'ready',
            'service': 'api-service',
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    else:
        return jsonify({
            'status': 'not ready',
            'service': 'api-service',
            'timestamp': datetime.utcnow().isoformat()
        }), 503


@app.route('/api/info', methods=['GET'])
def info():
    """Service information endpoint"""
    uptime = (datetime.utcnow() - start_time).total_seconds()
    return jsonify({
        'service': 'api-service',
        'version': '1.0.0',
        'environment': ENVIRONMENT,
        'uptime_seconds': uptime,
        'features': {
            'new_ui_enabled': FEATURE_NEW_UI,
            'beta_features_enabled': FEATURE_BETA
        }
    }), 200


@app.route('/api/items', methods=['GET'])
def list_items():
    """Sample endpoint - list items"""
    items = [
        {'id': 1, 'name': 'Item 1', 'description': 'First item'},
        {'id': 2, 'name': 'Item 2', 'description': 'Second item'},
        {'id': 3, 'name': 'Item 3', 'description': 'Third item'}
    ]

    if FEATURE_BETA:
        # Beta feature: add extra metadata
        for item in items:
            item['metadata'] = {'beta': True, 'timestamp': datetime.utcnow().isoformat()}

    return jsonify({'items': items, 'count': len(items)}), 200


@app.route('/api/items', methods=['POST'])
def create_item():
    """Sample endpoint - create item"""
    data = request.get_json()

    if not data or 'name' not in data:
        return jsonify({'error': 'Name is required'}), 400

    item = {
        'id': 999,
        'name': data['name'],
        'description': data.get('description', ''),
        'created_at': datetime.utcnow().isoformat()
    }

    logger.info(f"Created item: {item['name']}")
    return jsonify({'item': item}), 201


@app.route('/', methods=['GET'])
def root():
    """Root endpoint"""
    return jsonify({
        'service': 'api-service',
        'message': 'Welcome to the API service',
        'endpoints': [
            '/health',
            '/ready',
            '/api/info',
            '/api/items'
        ]
    }), 200


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({'error': 'Not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal error: {error}")
    return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    logger.info(f"Starting API service in {ENVIRONMENT} environment")
    logger.info(f"Feature flags - New UI: {FEATURE_NEW_UI}, Beta: {FEATURE_BETA}")

    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
