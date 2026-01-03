import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// App configuration helpers.
///
/// Use `--dart-define=MONGO_URI="your_connection_string"` when running
/// the app to override the default local value.
class AppConfig {
  static const mongoUri = String.fromEnvironment(
    'MONGO_URI',
    defaultValue: 'mongodb://localhost:27017/Teachain',
  );

  /// Trả về host đúng dựa trên platform
  /// - Android emulator: 10.0.2.2 (để truy cập host machine)
  /// - iOS simulator, Web, Desktop: localhost
  static String getLocalHost() {
    if (kIsWeb) {
      return 'localhost';
    }
    
    try {
      if (Platform.isAndroid) {
        return '10.0.2.2';
      }
    } catch (e) {
      // Fallback nếu Platform không khả dụng
    }
    
    return 'localhost';
  }

  /// Trả về MongoDB URI với host đúng
  static String getMongoUri() {
    final host = getLocalHost();
    return mongoUri.replaceFirst('localhost', host);
  }

  /// Trả về API URL với host đúng
  static String getApiUrl() {
    final host = getLocalHost();
    return 'http://$host:3000/api';
  }

  /// Trả về Qdrant URL với host đúng
  static String getQdrantUrl() {
    final host = getLocalHost();
    return 'http://$host:6333';
  }

  /// Trả về Ollama URL với host đúng
  static String getOllamaUrl() {
    final host = getLocalHost();
    return 'http://$host:11434';
  }
}
