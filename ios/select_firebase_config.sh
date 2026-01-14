#!/bin/bash
# This script selects the correct GoogleService-Info.plist based on the environment
# Run this before building: ./ios/select_firebase_config.sh dev

ENV=${1:-dev}
RUNNER_DIR="ios/Runner"

if [ "$ENV" = "prod" ]; then
    cp "$RUNNER_DIR/GoogleService-Info-prod.plist" "$RUNNER_DIR/GoogleService-Info.plist"
    echo "✅ Selected PRODUCTION Firebase config"
else
    cp "$RUNNER_DIR/GoogleService-Info-dev.plist" "$RUNNER_DIR/GoogleService-Info.plist"
    echo "✅ Selected DEVELOPMENT Firebase config"
fi
