# DailyFrase

A Flutter app for learning languages one phrase at a time, using AI-generated sentences with text-to-speech pronunciation.

## Features
- AI-generated practice phrases focused on a single verb per session
- Text-to-speech with native pronunciation
- Customizable settings: language pair, tenses, verb focus, questions/negations
- Progress tracking and streaks
- Dark/Light theme toggle
- Firebase authentication

---

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed
- For iOS: Xcode + CocoaPods (`brew install cocoapods`)
- For web: Chrome browser

Install Flutter dependencies:
```bash
flutter pub get
```

For iOS (first time only):
```bash
cd ios && pod install && cd ..
```

---

## Local Development (Testing)

The easiest way to run the app locally is the convenience script, which automatically sets `ENV=dev` and uses the **dev** Firebase project:

```bash
./run.sh           # Runs on Chrome (default)
./run.sh ios       # Runs on a connected iOS device
./run.sh android   # Runs on a connected Android device
```

Or run Flutter directly:
```bash
flutter run -d chrome --dart-define=ENV=dev
```

### Dev environment
| Setting | Value |
|---|---|
| API Base URL | `http://localhost:8000` |
| API Key | `test123` |
| Firebase Project | `dev-language-firebase` |

> **iOS note:** The script automatically calls `./ios/select_firebase_config.sh dev` before running. If running Flutter directly on iOS, call this manually first.

---

## Pushing to Production

Production deploys are **fully automated via GitHub Actions**. There is nothing to run manually.

### How it works

1. Merge a branch (or push a commit) to **`main`**
2. GitHub Actions triggers the [Deploy to Production](.github/workflows/deploy.yml) workflow automatically
3. The workflow:
   - Builds Flutter web with `ENV=prod`
   - Deploys the build output to the EC2 server via `rsync` over SSH

### Manual trigger

You can also trigger a production deploy without a code change from the GitHub UI:

> **GitHub → Actions → Deploy to Production → Run workflow**

### Production environment
| Setting | Value |
|---|---|
| API Base URL | `http://54.86.227.155:8000` |
| Firebase Project | `language-firebase-d5667` |

### Required GitHub Secrets
| Secret | Purpose |
|---|---|
| `PROD_API_KEY` | Passed as `--dart-define` to the Flutter build |
| `EC2_SSH_KEY` | SSH private key for the EC2 server |
| `EC2_IP` | IP address of the EC2 server |

---

## Project Structure

| Path | Purpose |
|---|---|
| `lib/config/environment.dart` | Dev/prod environment config |
| `lib/firebase_options.dart` | Dev & prod Firebase options |
| `ios/select_firebase_config.sh` | Copies correct `GoogleService-Info.plist` for iOS |
| `android/app/google-services-dev.json` | Dev Firebase config for Android |
| `android/app/google-services-prod.json` | Prod Firebase config for Android |
| `run.sh` | Convenience script for local dev |
| `.github/workflows/deploy.yml` | CI/CD pipeline |

For a full breakdown of environment configuration see [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md).
