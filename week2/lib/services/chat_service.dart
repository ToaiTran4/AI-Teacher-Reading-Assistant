import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/message_model.dart';

/// Chat service dùng Google Gemini (Generative Language API).
class ChatService {
  final String apiKey;
  // Dùng Gemini 1.5 Flash để tiết kiệm chi phí/quota và trả lời nhanh.
  final String model;

  ChatService({
    required this.apiKey,
    // Dùng gemini-1.0-pro (ổn định, hỗ trợ v1 generateContent).
    this.model = 'gemini-2.5-flash',
  });

  // Send message với (tùy chọn) RAG context.
  // Trả về stream nhưng hiện tại yield toàn bộ câu trả lời một lần cho đơn giản.
  Stream<String> sendMessageWithContext({
    required String userMessage,
    required List<ChatMessage> conversationHistory,
    String? context,
  }) async* {
    try {
      // Tạo system prompt với context.
      String systemMessage =
          'Bạn là một trợ lý AI thông minh, trả lời bằng tiếng Việt, rõ ràng và dễ hiểu.';
      if (context != null && context.isNotEmpty) {
        systemMessage +=
            '\n\nDưới đây là trích đoạn tài liệu liên quan, hãy ưu tiên dùng thông tin này khi trả lời:\n$context';
      }

      // Gộp lịch sử hội thoại (tối đa 10 tin nhắn gần nhất) thành một đoạn text.
      final buffer = StringBuffer();
      buffer.writeln(systemMessage);

      if (conversationHistory.isNotEmpty) {
        buffer.writeln('\n\nLịch sử hội thoại gần đây:');
        final recent = conversationHistory
            .skip(conversationHistory.length > 10
                ? conversationHistory.length - 10
                : 0)
            .toList();
        for (final msg in recent) {
          final roleLabel = msg.role == 'user' ? 'Người dùng' : 'Trợ lý';
          buffer.writeln('$roleLabel: ${msg.content}');
        }
      }

      buffer.writeln('\n\nCâu hỏi hiện tại của người dùng:');
      buffer.writeln(userMessage);

      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1/models/$model:generateContent?key=$apiKey');

      final response = await http.post(
        uri,
        headers: const {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': buffer.toString()},
              ],
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        String errMsg = 'Lỗi không xác định (HTTP ${response.statusCode})';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map && decoded['error'] is Map) {
            final error = decoded['error'] as Map;
            final code = error['code'];
            final message = error['message']?.toString();
            if (code == 429) {
              errMsg =
                  'Bạn đã hết quota hoặc vượt giới hạn tốc độ của Gemini. Vui lòng kiểm tra billing hoặc thử lại sau.';
            } else if (message != null && message.isNotEmpty) {
              errMsg = message;
            }
          }
        } catch (_) {}

        yield '[ERROR] $errMsg';
        return;
      }

      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final candidates = decoded['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          yield '[ERROR] Không nhận được câu trả lời từ Gemini.';
          return;
        }

        final content = candidates.first['content'] as Map?;
        final parts = content?['parts'] as List?;
        final text =
            parts?.map((p) => p['text']?.toString() ?? '').join('').trim() ??
                '';

        if (text.isEmpty) {
          yield '[ERROR] Câu trả lời trống từ Gemini.';
        } else {
          yield text;
        }
      } catch (e) {
        yield '[ERROR] Lỗi phân tích phản hồi từ Gemini: $e';
      }
    } catch (e) {
      yield '[ERROR] Lỗi kết nối tới Gemini: $e';
    }
  }

  // Send message thông thường (không có RAG)
  Stream<String> sendMessage(String userMessage) async* {
    yield* sendMessageWithContext(
      userMessage: userMessage,
      conversationHistory: [],
    );
  }
}
