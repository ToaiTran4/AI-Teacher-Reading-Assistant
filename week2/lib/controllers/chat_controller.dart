import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // [CẦN THÊM] nhớ chạy flutter pub add shared_preferences
import '../models/message_model.dart';
import '../models/document_model.dart';
import '../models/quiz_model.dart';
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

  // [NÂNG CẤP] Chọn document -> Tải lịch sử chat của document đó
  Future<void> selectDocument(DocumentModel? document) async {
    selectedDocument = document;
    if (document != null) {
      await _loadChatHistory(document.id);
    } else {
      messages.clear();
    }
    notifyListeners();
  }

  // [MỚI] Hàm tải lịch sử chat từ bộ nhớ máy
  Future<void> _loadChatHistory(String docId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_history_$docId';
    final List<String>? jsonList = prefs.getStringList(key);

    messages.clear();

    if (jsonList != null) {
      try {
        messages.addAll(jsonList.map((str) {
          final map = jsonDecode(str);
          // Tự map thủ công để tránh lỗi nếu MessageModel chưa có fromJson
          final msg = ChatMessage(
            role: map['role'],
            content: map['content'],
          );
          if (map['documentContext'] != null) {
            msg.documentContext = map['documentContext'];
          }
          return msg;
        }).toList());
      } catch (e) {
        debugPrint("Lỗi tải lịch sử chat: $e");
      }
    }
    notifyListeners();
  }

  // [MỚI] Hàm lưu lịch sử chat xuống bộ nhớ máy
  Future<void> _saveChatHistory() async {
    if (selectedDocument == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_history_${selectedDocument!.id}';

    // Chuyển List<ChatMessage> thành List<String> (JSON)
    final List<String> jsonList = messages.map((msg) {
      return jsonEncode({
        'role': msg.role,
        'content': msg.content,
        'documentContext': msg.documentContext,
      });
    }).toList();

    await prefs.setStringList(key, jsonList);
  }

  // [NÂNG CẤP] Xóa lịch sử -> Xóa cả trong bộ nhớ
  Future<void> clearMessages() async {
    messages.clear();
    notifyListeners();

    if (selectedDocument != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chat_history_${selectedDocument!.id}');
    }
  }

  // [NÂNG CẤP] Gửi tin nhắn -> Tự động lưu
  Future<void> send(String text) async {
    // 1. Thêm tin nhắn User
    messages.add(ChatMessage(role: "user", content: text));
    notifyListeners();
    await _saveChatHistory(); // Lưu ngay

    isTyping = true;
    final botMsg = ChatMessage(role: "assistant", content: "");
    messages.add(botMsg);
    notifyListeners();

    try {
      String? context;
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
        }
      }

      await for (final token in chatService.sendMessageWithContext(
        userMessage: text,
        conversationHistory: messages.sublist(0, messages.length - 1),
        context: context,
      )) {
        botMsg.content += token;
        notifyListeners();
      }

      // 2. Sau khi AI trả lời xong -> Lưu lại lần nữa
      await _saveChatHistory();
    } catch (e) {
      botMsg.content += '\n[ERROR] $e';
      notifyListeners();
      await _saveChatHistory(); // Lưu cả lỗi để user biết
    }

    isTyping = false;
    notifyListeners();
  }

  // Các hàm askAboutSelection và generateQuiz giữ nguyên như cũ
  Stream<String> askAboutSelection({
    required String selectedText,
    DocumentModel? document,
  }) async* {
    String? context;
    if (document != null && document.isProcessed) {
      final collectionName = 'doc_${document.id}';
      context = await ragService.retrieveContext(
        query: selectedText,
        collectionName: collectionName,
        topK: 3,
      );
    }
    final question = 'Giải thích ngắn gọn đoạn này:\n\n$selectedText';
    yield* chatService.sendMessageWithContext(
      userMessage: question,
      conversationHistory: [],
      context: context,
    );
  }

  Future<List<QuizModel>> generateQuizFromText(String pageText) async {
    try {
      debugPrint("Đang sinh quiz...");
      final stream = chatService.generateQuiz(pageText);
      String jsonBuffer = '';
      await for (final chunk in stream) {
        jsonBuffer += chunk;
      }

      if (jsonBuffer.trim().startsWith('[ERROR]')) {
        throw Exception(jsonBuffer.replaceAll('[ERROR]', '').trim());
      }

      jsonBuffer = jsonBuffer
          .replaceAll(RegExp(r'^```json', caseSensitive: false), '')
          .replaceAll(RegExp(r'^```', caseSensitive: false), '')
          .replaceAll(RegExp(r'```$', caseSensitive: false), '')
          .trim();

      if (jsonBuffer.isEmpty) throw Exception("AI trả về dữ liệu rỗng.");

      final List<dynamic> rawList = jsonDecode(jsonBuffer);
      return rawList.map((e) => QuizModel.fromJson(e)).toList();
    } catch (e) {
      if (e.toString().contains('overloaded') || e.toString().contains('503')) {
        throw Exception(
            "Server AI đang quá tải, vui lòng thử lại sau vài giây.");
      }
      throw Exception("Không thể tạo bài kiểm tra: $e");
    }
  }
}
