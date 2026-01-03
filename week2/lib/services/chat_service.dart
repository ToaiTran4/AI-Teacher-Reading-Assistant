import 'dart:convert';
import 'dart:async'; // Import thêm để dùng Future.delayed
import 'package:http/http.dart' as http;
import '../models/message_model.dart';

class ChatService {
  final String apiKey;
  final String model;

  ChatService({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
  });

  // [MỚI] Hàm gửi request có cơ chế tự động thử lại (Retry)
  Future<http.Response> _postWithRetry(
      Uri uri, Map<String, String> headers, Object? body) async {
    int attempts = 0;
    const maxAttempts = 3; // Thử tối đa 3 lần

    while (attempts < maxAttempts) {
      try {
        final response = await http.post(uri, headers: headers, body: body);

        // Nếu thành công hoặc lỗi không phải do server bận (429, 503) thì trả về luôn
        if (response.statusCode != 429 && response.statusCode != 503) {
          return response;
        }

        // Nếu lỗi 429 (Too Many Requests) hoặc 503 (Service Unavailable) -> Đợi rồi thử lại
        print(
            '⚠️ Server Gemini đang bận (Lần ${attempts + 1}). Đang thử lại...');
      } catch (e) {
        // Nếu lỗi mạng cũng thử lại
        print('⚠️ Lỗi kết nối (Lần ${attempts + 1}): $e');
      }

      attempts++;
      // Đợi tăng dần: 2s, 4s, 6s...
      await Future.delayed(Duration(seconds: 2 * attempts));
    }

    // Nếu hết số lần thử mà vẫn lỗi, thực hiện lần cuối để lấy lỗi gốc
    return await http.post(uri, headers: headers, body: body);
  }

  Stream<String> sendMessageWithContext({
    required String userMessage,
    required List<ChatMessage> conversationHistory,
    String? context,
    String? customSystemPrompt,
  }) async* {
    try {
      String systemMessage;

      if (customSystemPrompt != null && customSystemPrompt.isNotEmpty) {
        systemMessage = customSystemPrompt;
      } else {
        systemMessage = '''
          Bạn là một giáo viên tâm huyết, hài hước và am hiểu sâu sắc.
          Khi trả lời học sinh, bạn BẮT BUỘC tuân thủ 3 nguyên tắc sau:
          1. VÍ DỤ ĐỜI SỐNG: Không định nghĩa khô khan. Hãy dùng ẩn dụ hoặc tình huống thực tế đời thường để giải thích.
          2. TỪNG BƯỚC LOGIC: Chia nhỏ vấn đề thành các phần rõ ràng.
          3. KIỂM TRA LẠI: Luôn kết thúc câu trả lời bằng một câu hỏi ngắn để kiểm tra hiểu bài.
          ''';
      }

      if (context != null && context.isNotEmpty) {
        systemMessage +=
            '\n\nDưới đây là trích đoạn tài liệu liên quan, hãy ưu tiên dùng thông tin này khi trả lời:\n$context';
      }

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

      // [SỬA] Gọi hàm _postWithRetry thay vì http.post trực tiếp
      final response = await _postWithRetry(
        uri,
        {
          'Content-Type': 'application/json; charset=utf-8',
        },
        jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': buffer.toString()}
              ],
            },
          ],
          'generationConfig': {
            'temperature': customSystemPrompt != null ? 0.2 : 0.7,
          }
        }),
      );

      if (response.statusCode != 200) {
        String errMsg = 'Lỗi không xác định (HTTP ${response.statusCode})';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map && decoded['error'] is Map) {
            final error = decoded['error'] as Map;
            final message = error['message']?.toString();
            if (message != null) errMsg = message;
          }
        } catch (_) {}

        // Trả về chuỗi lỗi có định dạng để Controller bắt được
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
        yield '[ERROR] Lỗi phân tích phản hồi: $e';
      }
    } catch (e) {
      yield '[ERROR] Lỗi kết nối: $e';
    }
  }

  Stream<String> sendMessage(String userMessage) async* {
    yield* sendMessageWithContext(
      userMessage: userMessage,
      conversationHistory: [],
    );
  }

  Stream<String> generateQuiz(String pageText) async* {
    const quizSystemPrompt = '''
    Bạn là một máy chủ sinh dữ liệu JSON (JSON Generator).
    Nhiệm vụ: Tạo 5 câu hỏi trắc nghiệm (Multiple Choice) hoặc Đúng/Sai (True/False) dựa trên văn bản được cung cấp.
    
    YÊU CẦU ĐỊNH DẠNG (BẮT BUỘC):
    1. Chỉ trả về một mảng JSON thuần túy (Raw JSON Array).
    2. KHÔNG được bọc trong markdown (không dùng ```json ... ```).
    3. KHÔNG được có bất kỳ lời dẫn hay giải thích nào ngoài JSON.
    
    Cấu trúc JSON cho mỗi câu hỏi:
    {
      "question": "Nội dung câu hỏi?",
      "type": "multiple_choice", // hoặc "true_false"
      "options": ["Đáp án A", "Đáp án B", "Đáp án C", "Đáp án D"],
      "correct_index": 0, // Index của đáp án đúng trong mảng options (0, 1, 2, 3)
      "explanation": "Giải thích ngắn gọn tại sao đáp án này đúng."
    }
    ''';

    final userRequest = 'Hãy tạo quiz dựa trên nội dung sau:\n$pageText';

    yield* sendMessageWithContext(
      userMessage: userRequest,
      conversationHistory: [],
      customSystemPrompt: quizSystemPrompt,
    );
  }
}
