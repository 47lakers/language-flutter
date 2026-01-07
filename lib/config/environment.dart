import 'package:flutter/foundation.dart';

enum Environment { dev, prod }

class EnvironmentConfig {
  static late Environment _currentEnvironment;

  static void initialize() {
    // Read from --dart-define=ENV=prod or --dart-define=ENV=dev
    const String env = String.fromEnvironment('ENV', defaultValue: 'dev');
    
    if (env == 'prod') {
      _currentEnvironment = Environment.prod;
    } else {
      _currentEnvironment = Environment.dev;
    }
    
    if (kDebugMode) {
      print('🌍 Environment: ${environmentName}');
      print('🔌 API URL: $baseUrl');
      print('🔑 API Key: ${apiKey.substring(0, 4)}***');
    }
  }

  static Environment get currentEnvironment => _currentEnvironment;

  static String get baseUrl {
    switch (_currentEnvironment) {
      case Environment.dev:
        return 'http://localhost:8000';
      case Environment.prod:
        return 'https://api.dailyfrase.com';
    }
  }

  static String get apiKey {
    switch (_currentEnvironment) {
      case Environment.dev:
        return 'test123';
      case Environment.prod:
        // Read from --dart-define=PROD_API_KEY=your_key at build time
        // Example: flutter run -d chrome --dart-define=ENV=prod --dart-define=PROD_API_KEY=your_key
        const String prodKey = String.fromEnvironment('PROD_API_KEY', defaultValue: r'$5FrEfruFrlz');
        return prodKey;
    }
  }

  /// Firebase Project ID for the current environment
  static String get firebaseProjectId {
    switch (_currentEnvironment) {
      case Environment.dev:
        // Use dev Firebase project ID
        const String devId = String.fromEnvironment('DEV_FIREBASE_PROJECT_ID', defaultValue: '');
        return devId;
      case Environment.prod:
        // Use prod Firebase project ID
        const String prodId = String.fromEnvironment('PROD_FIREBASE_PROJECT_ID', defaultValue: '');
        return prodId;
    }
  }

  static String get environmentName {
    switch (_currentEnvironment) {
      case Environment.dev:
        return 'Development';
      case Environment.prod:
        return 'Production';
    }
  }
}
