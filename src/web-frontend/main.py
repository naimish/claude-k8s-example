"""
Web Frontend Service - Simple web interface
"""
import os
import logging
from datetime import datetime
from flask import Flask, render_template_string, jsonify

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
API_SERVICE_URL = os.getenv('API_SERVICE_URL', 'http://api-service:8080')

# Application state
start_time = datetime.utcnow()
ready = True

# HTML Templates
LEGACY_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Microservices Platform - {{ environment }}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #333; }
        .info { margin: 20px 0; }
        .badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
        }
        .badge-dev { background-color: #ffc107; color: #000; }
        .badge-staging { background-color: #17a2b8; color: #fff; }
        .badge-prod { background-color: #28a745; color: #fff; }
        .feature { color: #666; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Microservices Platform</h1>
        <div class="info">
            <p><strong>Environment:</strong>
                <span class="badge badge-{{ environment }}">{{ environment }}</span>
            </p>
            <p><strong>Service:</strong> web-frontend v1.0.0</p>
            <p><strong>Uptime:</strong> {{ uptime }} seconds</p>
        </div>
        <div class="feature">
            <p><strong>Feature Flags:</strong></p>
            <ul>
                <li>New UI: {{ 'Enabled' if new_ui else 'Disabled' }}</li>
                <li>Beta Features: {{ 'Enabled' if beta else 'Disabled' }}</li>
            </ul>
        </div>
        <p style="color: #999; font-size: 12px;">Legacy UI</p>
    </div>
</body>
</html>
"""

NEW_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Microservices Platform - {{ environment }}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 900px;
            margin: 50px auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        }
        h1 {
            color: #667eea;
            font-size: 32px;
            margin-bottom: 30px;
        }
        .card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin: 15px 0;
            border-left: 4px solid #667eea;
        }
        .badge {
            display: inline-block;
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 600;
            text-transform: uppercase;
        }
        .badge-dev { background-color: #fff3cd; color: #856404; }
        .badge-staging { background-color: #d1ecf1; color: #0c5460; }
        .badge-prod { background-color: #d4edda; color: #155724; }
        .feature-list {
            list-style: none;
            padding: 0;
        }
        .feature-list li {
            padding: 8px 0;
            border-bottom: 1px solid #dee2e6;
        }
        .feature-list li:last-child { border-bottom: none; }
        .enabled { color: #28a745; font-weight: 600; }
        .disabled { color: #dc3545; font-weight: 600; }
        .new-badge {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 4px 12px;
            border-radius: 4px;
            font-size: 11px;
            margin-left: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Microservices Platform <span class="new-badge">NEW UI</span></h1>
        <div class="card">
            <h3>Environment Information</h3>
            <p><strong>Environment:</strong>
                <span class="badge badge-{{ environment }}">{{ environment }}</span>
            </p>
            <p><strong>Service:</strong> web-frontend v2.0.0</p>
            <p><strong>Uptime:</strong> {{ uptime }} seconds</p>
        </div>
        <div class="card">
            <h3>Feature Flags</h3>
            <ul class="feature-list">
                <li>New UI: <span class="{{ 'enabled' if new_ui else 'disabled' }}">
                    {{ 'Enabled' if new_ui else 'Disabled' }}
                </span></li>
                <li>Beta Features: <span class="{{ 'enabled' if beta else 'disabled' }}">
                    {{ 'Enabled' if beta else 'Disabled' }}
                </span></li>
            </ul>
        </div>
    </div>
</body>
</html>
"""


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'web-frontend',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/ready', methods=['GET'])
def readiness():
    """Readiness check endpoint"""
    if ready:
        return jsonify({
            'status': 'ready',
            'service': 'web-frontend',
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    else:
        return jsonify({
            'status': 'not ready',
            'service': 'web-frontend',
            'timestamp': datetime.utcnow().isoformat()
        }), 503


@app.route('/', methods=['GET'])
def index():
    """Main web interface"""
    uptime = int((datetime.utcnow() - start_time).total_seconds())

    template = NEW_TEMPLATE if FEATURE_NEW_UI else LEGACY_TEMPLATE

    return render_template_string(
        template,
        environment=ENVIRONMENT,
        uptime=uptime,
        new_ui=FEATURE_NEW_UI,
        beta=FEATURE_BETA
    )


@app.route('/api/status', methods=['GET'])
def status():
    """Status API endpoint"""
    uptime = (datetime.utcnow() - start_time).total_seconds()
    return jsonify({
        'service': 'web-frontend',
        'version': '2.0.0' if FEATURE_NEW_UI else '1.0.0',
        'environment': ENVIRONMENT,
        'uptime_seconds': uptime,
        'features': {
            'new_ui_enabled': FEATURE_NEW_UI,
            'beta_features_enabled': FEATURE_BETA
        },
        'api_service_url': API_SERVICE_URL
    }), 200


if __name__ == '__main__':
    logger.info(f"Starting web-frontend service in {ENVIRONMENT} environment")
    logger.info(f"Feature flags - New UI: {FEATURE_NEW_UI}, Beta: {FEATURE_BETA}")

    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
