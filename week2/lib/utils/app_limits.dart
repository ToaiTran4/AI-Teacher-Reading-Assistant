import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý các giới hạn của app
class AppLimits {
  // ===== GIỚI HẠN FILE =====
  /// Kích thước file tối đa: 50MB
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50MB
  static const double maxFileSizeMB = 50.0;

  /// Kiểm tra file size có hợp lệ không
  static bool isValidFileSize(int fileSizeBytes) {
    return fileSizeBytes <= maxFileSizeBytes;
  }

  /// Format file size để hiển thị
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ===== GIỚI HẠN CÂU HỎI =====
  /// Số câu hỏi tối đa mỗi ngày cho mỗi user: 50
  static const int maxQuestionsPerDay = 50;

  /// Key để lưu số câu hỏi đã tạo trong ngày
  static String getDailyQuestionKey(String userId) {
    final today = DateTime.now();
    return 'questions_count_${userId}_${today.year}_${today.month}_${today.day}';
  }

  /// Kiểm tra xem user còn có thể tạo câu hỏi không
  static Future<bool> canCreateQuestion(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getDailyQuestionKey(userId);
      final count = prefs.getInt(key) ?? 0;
      return count < maxQuestionsPerDay;
    } catch (e) {
      // Nếu lỗi, cho phép tạo (fail-safe)
      return true;
    }
  }

  /// Tăng số câu hỏi đã tạo trong ngày
  static Future<int> incrementQuestionCount(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getDailyQuestionKey(userId);
      final currentCount = prefs.getInt(key) ?? 0;
      final newCount = currentCount + 1;
      await prefs.setInt(key, newCount);
      return newCount;
    } catch (e) {
      return 0;
    }
  }

  /// Lấy số câu hỏi đã tạo trong ngày
  static Future<int> getTodayQuestionCount(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getDailyQuestionKey(userId);
      return prefs.getInt(key) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Reset số câu hỏi (dùng cho testing hoặc admin)
  static Future<void> resetQuestionCount(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = getDailyQuestionKey(userId);
      await prefs.remove(key);
    } catch (e) {
      // Ignore
    }
  }

  // ===== GIỚI HẠN NGÔN NGỮ =====
  /// Danh sách ngôn ngữ được hỗ trợ
  static const List<String> supportedLanguages = [
    'vi',
    'en'
  ]; // Tiếng Việt, Tiếng Anh

  /// Kiểm tra ngôn ngữ có được hỗ trợ không
  static bool isLanguageSupported(String languageCode) {
    return supportedLanguages.contains(languageCode.toLowerCase());
  }
}
