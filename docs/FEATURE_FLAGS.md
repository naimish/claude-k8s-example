# Feature Flags Guide

This guide explains how to use feature flags in the microservices platform to enable safe trunk-based development and gradual feature rollouts.

## Table of Contents

- [Overview](#overview)
- [How Feature Flags Work](#how-feature-flags-work)
- [Using Feature Flags](#using-feature-flags)
- [Best Practices](#best-practices)
- [Examples](#examples)
- [Lifecycle](#lifecycle)

## Overview

Feature flags (also called feature toggles) allow you to:

- Merge code to main with features disabled
- Deploy incomplete features safely
- Test features in specific environments
- Gradually roll out features to production
- Quickly disable problematic features
- A/B test new functionality

## How Feature Flags Work

### Infrastructure Level

Feature flags are configured in Helm values files and passed to applications as environment variables.

**Configuration in Helm:**

```yaml
# helm/umbrella/values-dev.yaml
global:
  featureFlags:
    newUIEnabled: false
    betaFeaturesEnabled: false
    experimentalAPIEnabled: false
```

**Injected as environment variables:**

The Helm deployment templates automatically convert feature flags to environment variables:

```yaml
# helm/services/api-service/templates/deployment.yaml
env:
  - name: FEATURE_NEW_UI
    value: {{ .Values.global.featureFlags.newUIEnabled | quote }}
  - name: FEATURE_BETA
    value: {{ .Values.global.featureFlags.betaFeaturesEnabled | quote }}
```

### Application Level

Applications read environment variables and toggle behavior:

```python
import os

# Read feature flags from environment
FEATURE_NEW_UI = os.getenv('FEATURE_NEW_UI', 'false').lower() == 'true'
FEATURE_BETA = os.getenv('FEATURE_BETA', 'false').lower() == 'true'

# Use in code
if FEATURE_NEW_UI:
    return render_new_ui()
else:
    return render_legacy_ui()
```

## Using Feature Flags

### Step 1: Define the Feature Flag

Add to global feature flags in all environment values files:

```yaml
# helm/umbrella/values.yaml (default)
global:
  featureFlags:
    myNewFeatureEnabled: false  # Disabled by default

# helm/umbrella/values-dev.yaml
global:
  featureFlags:
    myNewFeatureEnabled: false  # Start disabled even in dev

# helm/umbrella/values-staging.yaml
global:
  featureFlags:
    myNewFeatureEnabled: false

# helm/umbrella/values-prod.yaml
global:
  featureFlags:
    myNewFeatureEnabled: false
```

### Step 2: Update Deployment Template

The feature flags are automatically injected via the deployment template. If you need a new pattern, update:

```yaml
# helm/services/api-service/templates/deployment.yaml
env:
  {{- if .Values.global }}
  {{- if .Values.global.featureFlags }}
  - name: FEATURE_MY_NEW_FEATURE
    value: {{ .Values.global.featureFlags.myNewFeatureEnabled | quote }}
  {{- end }}
  {{- end }}
```

### Step 3: Implement Feature in Code

```python
# src/api-service/main.py
import os

FEATURE_MY_NEW_FEATURE = os.getenv('FEATURE_MY_NEW_FEATURE', 'false').lower() == 'true'

@app.route('/api/items')
def list_items():
    if FEATURE_MY_NEW_FEATURE:
        # New implementation
        return new_list_items_implementation()
    else:
        # Existing implementation
        return legacy_list_items_implementation()
```

### Step 4: Test Locally

```bash
# Test with feature disabled (default)
python src/api-service/main.py

# Test with feature enabled
FEATURE_MY_NEW_FEATURE=true python src/api-service/main.py
```

### Step 5: Deploy with Feature Disabled

```bash
# Create PR and merge to main
# Feature is disabled by default, so it's safe

# Automatically deploys to dev (feature still disabled)
```

### Step 6: Enable in Dev Environment

```yaml
# helm/umbrella/values-dev.yaml
global:
  featureFlags:
    myNewFeatureEnabled: true  # Enable in dev
```

Commit and merge this change. The dev environment will redeploy with the feature enabled.

### Step 7: Test and Iterate

- Test thoroughly in dev with feature enabled
- Fix any issues
- Repeat until stable

### Step 8: Promote to Staging

```yaml
# helm/umbrella/values-staging.yaml
global:
  featureFlags:
    myNewFeatureEnabled: true  # Enable in staging
```

Deploy to staging and conduct broader testing.

### Step 9: Enable in Production

When ready for production:

```yaml
# helm/umbrella/values-prod.yaml
global:
  featureFlags:
    myNewFeatureEnabled: true  # Enable in production
```

Deploy to production. The feature is now live.

### Step 10: Remove Feature Flag

After the feature is stable in production (typically 1-2 weeks):

1. Remove the conditional code:
   ```python
   # Before
   if FEATURE_MY_NEW_FEATURE:
       return new_implementation()
   else:
       return legacy_implementation()

   # After
   return new_implementation()
   ```

2. Remove from Helm values files

3. Deploy the cleanup

## Best Practices

### Naming Conventions

Use clear, descriptive names:

```yaml
# Good
newUIEnabled: true
betaFeaturesEnabled: false
experimentalSearchEnabled: true

# Bad
feature1: true
new_stuff: false
test: true
```

### Default to Disabled

Always default feature flags to `false`:

```yaml
global:
  featureFlags:
    newFeature: false  # Always start disabled
```

### Document Feature Flags

Add comments explaining the feature:

```yaml
global:
  featureFlags:
    # New UI redesign - Jira ticket: PLAT-123
    newUIEnabled: false

    # Beta features - experimental functionality
    betaFeaturesEnabled: false
```

### Keep Flags Short-Lived

Feature flags should be temporary:

- Add flag when developing feature
- Enable in dev → staging → production
- Remove flag 1-2 weeks after production rollout
- Don't accumulate old flags

### Test Both States

Always test code with feature flags both enabled and disabled:

```python
def test_with_feature_enabled():
    os.environ['FEATURE_NEW_API'] = 'true'
    # Test new behavior

def test_with_feature_disabled():
    os.environ['FEATURE_NEW_API'] = 'false'
    # Test legacy behavior
```

### Use for Gradual Rollouts

Enable features progressively:

1. Enable in dev
2. Enable in staging
3. Enable in production
4. Monitor for issues
5. If issues, disable in production immediately

### Kill Switch Pattern

Feature flags act as kill switches. If a feature causes issues:

```yaml
# helm/umbrella/values-prod.yaml
global:
  featureFlags:
    problematicFeature: false  # Disable immediately
```

Deploy and the feature is instantly disabled without code rollback.

## Examples

### Example 1: New UI Component

```python
# src/web-frontend/main.py
import os
from flask import render_template_string

FEATURE_NEW_UI = os.getenv('FEATURE_NEW_UI', 'false').lower() == 'true'

@app.route('/')
def index():
    if FEATURE_NEW_UI:
        return render_template_string(NEW_TEMPLATE)
    else:
        return render_template_string(LEGACY_TEMPLATE)
```

```yaml
# helm/umbrella/values-dev.yaml
global:
  featureFlags:
    newUIEnabled: true  # Test new UI in dev
```

### Example 2: New API Endpoint

```python
# src/api-service/main.py
import os

FEATURE_NEW_API_V2 = os.getenv('FEATURE_NEW_API_V2', 'false').lower() == 'true'

@app.route('/api/v2/items')
def list_items_v2():
    if not FEATURE_NEW_API_V2:
        return jsonify({'error': 'Feature not enabled'}), 404

    # New API implementation
    return jsonify({'items': get_items_v2()})
```

### Example 3: Algorithm Change

```python
# src/worker-service/main.py
import os

FEATURE_IMPROVED_ALGORITHM = os.getenv('FEATURE_IMPROVED_ALGORITHM', 'false').lower() == 'true'

def process_job(job):
    if FEATURE_IMPROVED_ALGORITHM:
        return process_with_new_algorithm(job)
    else:
        return process_with_legacy_algorithm(job)
```

### Example 4: Beta Features

```python
# src/api-service/main.py
FEATURE_BETA = os.getenv('FEATURE_BETA', 'false').lower() == 'true'

@app.route('/api/items')
def list_items():
    items = get_items()

    if FEATURE_BETA:
        # Add beta metadata
        for item in items:
            item['beta_features'] = get_beta_features(item)

    return jsonify({'items': items})
```

## Lifecycle

### Phase 1: Development
- Feature flag defined (disabled everywhere)
- Code merged to main behind flag
- Deployed to dev (flag disabled)

### Phase 2: Dev Testing
- Flag enabled in dev
- Team tests feature
- Bugs fixed and iterations made

### Phase 3: Staging Testing
- Flag enabled in staging
- QA testing
- Integration testing
- Performance testing

### Phase 4: Production Rollout
- Flag enabled in production
- Monitor metrics
- Watch for errors
- Gradual rollout if needed

### Phase 5: Stabilization
- Feature stable in production for 1-2 weeks
- No issues reported
- Metrics look good

### Phase 6: Cleanup
- Remove conditional code
- Remove flag from values files
- Clean implementation in codebase

## Monitoring Feature Flags

### Track Active Flags

Keep a list of active feature flags:

```bash
# List all feature flags across environments
grep -r "featureFlags:" helm/umbrella/values*.yaml
```

### Document in Code

Add comments when using flags:

```python
# FEATURE FLAG: newUIEnabled
# Jira: PLAT-123
# Created: 2024-01-15
# TODO: Remove after stable in prod
if FEATURE_NEW_UI:
    ...
```

### Regular Cleanup

Schedule regular reviews to remove old flags:

- Weekly: Check if flags can be removed
- Monthly: Audit all active flags
- Quarterly: Review flag lifecycle

## Troubleshooting

### Feature Flag Not Working

1. **Check environment variable:**
   ```bash
   kubectl exec -n dev [pod-name] -- env | grep FEATURE
   ```

2. **Verify Helm values:**
   ```bash
   helm get values microservices-platform -n dev
   ```

3. **Check template rendering:**
   ```bash
   helm template test helm/umbrella -f helm/umbrella/values-dev.yaml | grep -A 5 "FEATURE"
   ```

### Feature Enabled But Not Working

1. Check application code reads the variable correctly
2. Verify string comparison logic (`'true'` vs `True`)
3. Check for typos in variable names
4. Restart pods to pick up new values

## Summary

Feature flags enable:

- Safe trunk-based development
- Gradual feature rollouts
- Easy rollback of problematic features
- Testing in production
- A/B testing capabilities

Key principles:

- Default to disabled
- Test both states
- Enable progressively (dev → staging → prod)
- Remove after stabilization
- Document clearly
