import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_controller.dart';
import 'controllers/chat_controller.dart';
import 'services/chat_service.dart';
import 'services/ollama_service.dart'; // ✅ Thêm
import 'services/rag_service.dart';
import 'services/qdrant_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'config.dart';

// ===== CẤU HÌNH =====
// Thay bằng API key của Google Gemini (Generative Language API).
// Ví dụ: const String geminiApiKey = "AIza...";
const String geminiApiKey = "";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Chat dùng Google Gemini
    final chatService = ChatService(apiKey: geminiApiKey);

    // Qdrant local (tự động detect platform)
    final qdrantService = QdrantService(
      baseUrl: AppConfig.getQdrantUrl(),
      apiKey: null,
    );

    // Ollama service (chỉ dùng cho embedding, tự động detect platform)
    final ollamaService = OllamaService(baseUrl: AppConfig.getOllamaUrl());

    // RAG dùng Ollama embedding
    final ragService = RAGService(
      ollamaService: ollamaService, // ✅ Embedding dùng Ollama
      qdrantService: qdrantService,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(
          create: (_) => ChatController(
            chatService: chatService, // ✅ Chat vẫn dùng OpenAI
            ragService: ragService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'RAG Chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    if (authController.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return authController.isAuthenticated
        ? const HomeScreen()
        : const LoginScreen();
  }
}
