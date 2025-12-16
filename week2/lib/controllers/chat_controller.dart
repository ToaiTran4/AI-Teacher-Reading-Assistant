import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../models/document_model.dart';
// debugPrint available from material.dart; no extra import needed
import '../services/chat_service.dart';
import '../services/rag_service.dart';

class ChatController extends ChangeNotifier {
  final List<ChatMessage> messages = [];
  final ChatService chatService;
  final RAGService ragService;
  
  bool isTyping = false;
  DocumentModel? selectedDocument;

  ChatController({
    required this.chatService,
    required this.ragService,
  });

  // Chọn document để chat
  void selectDocument(DocumentModel? document) {
    selectedDocument = document;
    notifyListeners();
  }

  // Clear chat history
  void clearMessages() {
    messages.clear();
    notifyListeners();
  }

  // Send message với RAG
  Future<void> send(String text) async {
    // Thêm user message
    messages.add(ChatMessage(role: "user", content: text));
    notifyListeners();

    isTyping = true;
    final botMsg = ChatMessage(role: "assistant", content: "");
    messages.add(botMsg);
    notifyListeners();

    try {
      String? context;

      // Nếu có document được chọn và đã xử lý, lấy context từ Qdrant
      if (selectedDocument != null && selectedDocument!.isProcessed) {
        debugPrint('Retrieving context from Qdrant...');
        
        final collectionName = 'doc_${selectedDocument!.id}';
        context = await ragService.retrieveContext(
          query: text,
          collectionName: collectionName,
          topK: 3,
        );

        if (context.isNotEmpty) {
          botMsg.documentContext = context;
          debugPrint('Context retrieved: ${context.substring(0, 100)}...');
        }
      }

      // Stream response từ ChatGPT
      await for (final token in chatService.sendMessageWithContext(
        userMessage: text,
        conversationHistory: messages.sublist(0, messages.length - 1), // Không include bot message đang tạo
        context: context,
      )) {
        botMsg.content += token;
        notifyListeners();
      }
    } catch (e) {
      botMsg.content += '\n[ERROR] $e';
      notifyListeners();
    }

    isTyping = false;
    notifyListeners();
  }

  /// Hỏi nhanh về một đoạn text được chọn trong PDF.
  /// Không ghi vào lịch sử chat chính, chỉ trả về stream câu trả lời.
  Stream<String> askAboutSelection({
    required String selectedText,
    DocumentModel? document,
  }) async* {
    String? context;

    if (document != null && document.isProcessed) {
      debugPrint('Retrieving context for selection from Qdrant...');
      final collectionName = 'doc_${document.id}';
      context = await ragService.retrieveContext(
        query: selectedText,
        collectionName: collectionName,
        topK: 3,
      );
    }

    final question =
        'Giải thích thật ngắn gọn, dễ hiểu cho người học về đoạn sau trong tài liệu. '
        'Chỉ trả lời tối đa 3 câu ngắn, tập trung vào ý chính, không lan man:\n\n'
        '$selectedText';

    yield* chatService.sendMessageWithContext(
      userMessage: question,
      conversationHistory: [],
      context: context,
    );
  }
}