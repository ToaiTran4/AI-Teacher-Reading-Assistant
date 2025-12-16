/// App configuration helpers.
///
/// Use `--dart-define=MONGO_URI="your_connection_string"` when running
/// the app to override the default local value.
class AppConfig {
  static const mongoUri = String.fromEnvironment(
    'MONGO_URI',
    defaultValue: 'mongodb://localhost:27017/Teachain',
  );
}
