"""
Worker Service - Background job processor
"""
import os
import time
import logging
import signal
import sys
from datetime import datetime
from flask import Flask, jsonify

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Feature flags from environment
FEATURE_BETA = os.getenv('FEATURE_BETA', 'false').lower() == 'true'
ENVIRONMENT = os.getenv('ENVIRONMENT', 'unknown')
JOB_INTERVAL = int(os.getenv('JOB_INTERVAL', '30'))  # seconds

# Application state
start_time = datetime.utcnow()
ready = True
running = True
jobs_processed = 0

# Flask app for health endpoints
app = Flask(__name__)


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'worker-service',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/ready', methods=['GET'])
def readiness():
    """Readiness check endpoint"""
    if ready:
        return jsonify({
            'status': 'ready',
            'service': 'worker-service',
            'timestamp': datetime.utcnow().isoformat()
        }), 200
    else:
        return jsonify({
            'status': 'not ready',
            'service': 'worker-service',
            'timestamp': datetime.utcnow().isoformat()
        }), 503


@app.route('/metrics', methods=['GET'])
def metrics():
    """Worker metrics endpoint"""
    uptime = (datetime.utcnow() - start_time).total_seconds()
    return jsonify({
        'service': 'worker-service',
        'environment': ENVIRONMENT,
        'uptime_seconds': uptime,
        'jobs_processed': jobs_processed,
        'job_interval': JOB_INTERVAL,
        'beta_enabled': FEATURE_BETA
    }), 200


def process_job(job_id):
    """Simulate processing a background job"""
    logger.info(f"Processing job {job_id}")

    # Simulate work
    time.sleep(2)

    if FEATURE_BETA:
        # Beta feature: enhanced job processing
        logger.info(f"Job {job_id} - Beta processing enabled")
        time.sleep(1)

    logger.info(f"Completed job {job_id}")
    return True


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    global running
    logger.info(f"Received signal {signum}, shutting down gracefully...")
    running = False


def run_worker():
    """Main worker loop"""
    global jobs_processed, running

    logger.info(f"Starting worker service in {ENVIRONMENT} environment")
    logger.info(f"Job interval: {JOB_INTERVAL} seconds")
    logger.info(f"Beta features: {FEATURE_BETA}")

    # Register signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    while running:
        try:
            # Simulate fetching and processing a job
            job_id = f"job-{jobs_processed + 1}"
            process_job(job_id)
            jobs_processed += 1

            # Wait before next job
            for _ in range(JOB_INTERVAL):
                if not running:
                    break
                time.sleep(1)

        except Exception as e:
            logger.error(f"Error processing job: {e}")
            time.sleep(5)  # Wait before retry

    logger.info(f"Worker stopped. Total jobs processed: {jobs_processed}")


if __name__ == '__main__':
    import threading

    # Start Flask server in separate thread for health checks
    port = int(os.getenv('PORT', 8080))

    def run_flask():
        app.run(host='0.0.0.0', port=port, debug=False, use_reloader=False)

    flask_thread = threading.Thread(target=run_flask, daemon=True)
    flask_thread.start()

    logger.info(f"Health endpoints available on port {port}")

    # Run worker in main thread
    run_worker()
