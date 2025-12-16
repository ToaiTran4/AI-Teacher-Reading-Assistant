// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/message_model.dart';
// import 'ollama_service.dart';

// class OllamaChatService {
//   final OllamaService ollamaService;

//   OllamaChatService({required this.ollamaService});

//   Stream<String> sendMessageWithContext({
//     required String userMessage,
//     required List<ChatMessage> conversationHistory,
//     String? context,
//   }) async* {
//     String systemPrompt = "Bạn là một trợ lý AI thông minh và hữu ích.";
    
//     if (context != null && context.isNotEmpty) {
//       systemPrompt += "\n\nDựa vào thông tin sau để trả lời câu hỏi:\n\n$context";
//     }

//     // Ghép lịch sử hội thoại
//     String fullPrompt = userMessage;
//     if (conversationHistory.isNotEmpty) {
//       final history = conversationHistory
//           .skip(conversationHistory.length > 10 ? conversationHistory.length - 10 : 0)
//           .map((msg) => '${msg.role}: ${msg.content}')
//           .join('\n');
//       fullPrompt = '$history\nuser: $userMessage';
//     }

//     yield* ollamaService.chat(
//       prompt: fullPrompt,
//       systemPrompt: systemPrompt,
//       model: 'llama3.2',
//     );
//   }

//   Stream<String> sendMessage(String userMessage) async* {
//     yield* sendMessageWithContext(
//       userMessage: userMessage,
//       conversationHistory: [],
//     );
//   }
// }