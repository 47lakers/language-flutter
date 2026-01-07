# Language Learning Flutter App

A Flutter mobile app for learning languages through AI-generated sentences with text-to-speech pronunciation.

## Features
- Dark/Light theme toggle
- AI-generated practice sentences in Spanish, French, Portuguese, or English
- Text-to-speech with native pronunciation
- Customizable settings: language, tenses, verb focus, questions/negations
- Responsive design with hamburger menu for mobile

## Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. For iOS devices, install CocoaPods dependencies:
   ```bash
   cd ios
   pod install
   cd ..
   ```

## Testing

### Testing on Laptop (Chrome/Web)

1. Make sure your backend API server is running on `http://10.0.0.115:8000`

2. Run the app in Chrome:
   ```bash
   flutter run -d chrome
   ```

3. Login with any credentials (auth is mocked)

4. Test features:
   - Click speaker icons to hear text-to-speech
   - Toggle theme with sun/moon icon
   - Use hamburger menu to adjust settings
   - Change languages, tenses, verb focus

### Testing on iPhone

1. Prerequisites:
   - Mac with Xcode installed
   - iPhone connected via USB cable
   - iPhone trusted this computer (check iPhone popup)
   - CocoaPods installed: `brew install cocoapods`

2. Run pod install (first time only):
   ```bash
   cd ios
   pod install
   cd ..
   ```

3. List available devices:
   ```bash
   flutter devices
   ```

4. Run on iPhone:
   ```bash
   flutter run -d <device-id>
   ```
   Or just `flutter run` and select your iPhone from the list

5. Test features:
   - Text-to-speech should work with correct pronunciation
   - Normal speech rate (not too fast)
   - Theme toggle
   - All UI interactions

## Files to Ignore in Git

Create a `.gitignore` file with:

```
# Build outputs
build/
*.iml
.flutter-plugins
.flutter-plugins-dependencies

# iOS
ios/Pods/
ios/.symlinks/
ios/Flutter/Generated.xcconfig
ios/Flutter/flutter_export_environment.sh
ios/Flutter/ephemeral/
ios/Runner.xcworkspace/xcuserdata/
*.pbxuser
*.mode1v3
*.mode2v3
*.perspectivev3
*.xcuserdata
xcuserdata/

# Android
android/.gradle/
android/gradle/
android/local.properties
android/app/debug/
android/app/profile/
android/app/release/

# macOS
macos/Flutter/ephemeral/
macos/Pods/

# Web
web/flutter_service_worker.js
web/flutter.js

# IDE
.idea/
.vscode/
*.swp
*.swo
.DS_Store

# Dart
.dart_tool/
.packages
pubspec.lock
```

## Tech Stack
- Flutter/Dart
- Provider for state management
- flutter_tts for text-to-speech
- HTTP API client for sentence generation