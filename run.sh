#!/bin/bash
# Convenience script to run Flutter in dev mode
# Usage: ./run.sh [device]
# Production deploys happen automatically via GitHub Actions on merge to main

PLATFORM=${1:-chrome}
BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "🌿 Branch: $BRANCH"
echo "🔨 Running in dev mode..."

# Select dev Firebase config for iOS
./ios/select_firebase_config.sh dev

flutter run -d "$PLATFORM" --dart-define=ENV=dev
