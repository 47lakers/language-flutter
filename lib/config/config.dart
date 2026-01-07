// This file initializes the environment at app startup
// The environment is determined by the --dart-define flag when running flutter

import 'environment.dart';

void initializeEnvironment() {
  EnvironmentConfig.initialize();
}
