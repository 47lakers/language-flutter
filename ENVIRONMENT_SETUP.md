# Environment Configuration Guide

## Development vs Production

This app uses separate configurations for dev and prod environments across **all platforms** (Web, iOS, Android, macOS, Windows).

### Running the App

**Easiest way - Use the convenience script:**

```bash
# Development (default)
./run.sh dev

# Development on iOS device
./run.sh dev ios

# Production
./run.sh prod

# Production on Android
./run.sh prod android
```

**Or run directly with Flutter:**

**Development (default):**
```bash
flutter run -d chrome
# or explicitly
flutter run -d chrome --dart-define=ENV=dev
```

**Production:**
```bash
flutter run -d chrome --dart-define=ENV=prod --dart-define=PROD_API_KEY=$5FrEfruFrlz
```

### For iOS

Before running on iOS, select the Firebase config:

```bash
./ios/select_firebase_config.sh dev   # For development
./ios/select_firebase_config.sh prod  # For production
```

### For Android

The build system automatically selects the correct `google-services.json`:

```bash
flutter run -d android --dart-define=ENV=dev   # Uses google-services-dev.json
flutter run -d android --dart-define=ENV=prod  # Uses google-services-prod.json
```

## Firebase Configuration Files

**iOS:**
- `ios/Runner/GoogleService-Info-dev.plist` - Dev Firebase config
- `ios/Runner/GoogleService-Info-prod.plist` - Prod Firebase config

**Android:**
- `android/app/google-services-dev.json` - Dev Firebase config
- `android/app/google-services-prod.json` - Prod Firebase config

## Environment Details

### Development
- **API Base URL:** `http://localhost:8000`
- **API Key:** `test123`
- **Firebase Project:** `dev-language-firebase`

### Production
- **API Base URL:** `http://54.86.227.155:8000`
- **API Key:** `$5FrEfruFrlz`
- **Firebase Project:** `language-firebase-d5667`

## Complete Build for Production

```bash
# Web
flutter build web --dart-define=ENV=prod --dart-define=PROD_API_KEY=$5FrEfruFrlz

# Android
flutter build apk --flavor prod --dart-define=ENV=prod --dart-define=PROD_API_KEY=$5FrEfruFrlz

# iOS
./ios/select_firebase_config.sh prod
flutter build ios --dart-define=ENV=prod
```

## CI/CD Setup (GitHub Actions)

```yaml
- name: Build Production Web
  run: |
    flutter build web \
      --dart-define=ENV=prod \
      --dart-define=PROD_API_KEY=${{ secrets.PROD_API_KEY }}
```

## Files Setup

- `lib/config/environment.dart` - Environment configuration
- `lib/firebase_options.dart` - Dev & prod Firebase configs
- `ios/select_firebase_config.sh` - iOS Firebase config switcher
- `run.sh` - Convenience build script
- `android/app/build.gradle.kts` - Android flavor configuration
- `ios/Runner/GoogleService-Info-dev.plist` - Dev iOS config
- `ios/Runner/GoogleService-Info-prod.plist` - Prod iOS config
- `android/app/google-services-dev.json` - Dev Android config
- `android/app/google-services-prod.json` - Prod Android config
- `.env.local` - Local environment variables (gitignored)
