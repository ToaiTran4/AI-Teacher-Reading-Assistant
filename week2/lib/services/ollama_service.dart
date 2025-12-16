import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  final String baseUrl;
  
  OllamaService({
    this.baseUrl = 'http://localhost:11434',
  });

  // Tạo embedding
  Future<List<double>> createEmbedding(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/embeddings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'nomic-embed-text',
          'prompt': text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<double>.from(data['embedding']);
      } else {
        throw 'Ollama Error: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Lỗi kết nối Ollama: $e';
    }
  }

  // Chat streaming
  Stream<String> chat({
    required String prompt,
    String model = 'llama3.2',
    String? systemPrompt,
  }) async* {
    try {
      final messages = <Map<String, String>>[];
      
      if (systemPrompt != null) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      
      messages.add({'role': 'user', 'content': prompt});

      final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': model,
        'messages': messages,
        'stream': true,
      });

      final response = await request.send();

      await for (var chunk in response.stream.transform(utf8.decoder)) {
        try {
          final json = jsonDecode(chunk);
          final content = json['message']?['content'];
          if (content != null && content.isNotEmpty) {
            yield content;
          }
          if (json['done'] == true) break;
        } catch (_) {}
      }
    } catch (e) {
      yield '[ERROR] $e';
    }
  }
}