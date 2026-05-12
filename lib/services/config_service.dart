import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service to manage environment variables and configuration from .env file
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();

  factory ConfigService() => _instance;

  ConfigService._internal();

  /// Get encryption key from .env file
  String get encryptionKey {
    final key = dotenv.env['ENCRYPTION_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception(
        'ENCRYPTION_KEY not found in .env file. '
        'Please ensure .env file contains ENCRYPTION_KEY variable.',
      );
    }
    if (key.length < 16) {
      throw Exception(
        'ENCRYPTION_KEY must be at least 16 characters long for security.',
      );
    }
    return key;
  }

  /// Get app environment (production, staging, development)
  String get appEnv => dotenv.env['APP_ENV'] ?? 'production';

  /// Get debug flag
  bool get isDebug => dotenv.env['APP_DEBUG']?.toLowerCase() == 'true';

  /// Get any environment variable by key
  String? getEnv(String key) => dotenv.env[key];

  /// Get environment variable with default fallback
  String getEnvWithDefault(String key, String defaultValue) =>
      dotenv.env[key] ?? defaultValue;

  /// Check if environment variable exists
  bool hasEnv(String key) => dotenv.env.containsKey(key);
}
