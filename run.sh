#!/bin/bash
# Convenience script to run Flutter in dev or prod mode
# Usage: ./run.sh [env] [device]
#   env: dev (default) | prod
#   device: chrome (default) | ios | android | macos
# Examples:
#   ./run.sh              → dev on chrome
#   ./run.sh dev ios      → dev on iOS
#   ./run.sh prod         → prod on chrome (reads PROD_API_KEY from .env.local)

ENV=${1:-dev}
PLATFORM=${2:-chrome}
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Load secrets from .env.local if it exists (gitignored — never committed)
if [ -f ".env.local" ]; then
  export $(grep -v '^#' .env.local | xargs)
fi

echo "🌿 Branch: $BRANCH"

if [ "$ENV" = "prod" ]; then
  if [ -z "$PROD_API_KEY" ]; then
    echo "❌ PROD_API_KEY is not set. Add it to .env.local"
    exit 1
  fi
  echo "🚀 Running in PROD mode..."
  ./ios/select_firebase_config.sh prod
  flutter run -d "$PLATFORM" \
    --dart-define=ENV=prod \
    --dart-define="PROD_API_KEY=$PROD_API_KEY"
else
  echo "🔨 Running in DEV mode..."
  ./ios/select_firebase_config.sh dev
  flutter run -d "$PLATFORM" --dart-define=ENV=dev
fi
