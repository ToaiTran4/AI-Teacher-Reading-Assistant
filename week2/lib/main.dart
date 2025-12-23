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

// ===== CẤU HÌNH =====
// Thay bằng API key của Google Gemini (Generative Language API).
// Ví dụ: const String geminiApiKey = "AIza...";
const String geminiApiKey = "";
const String qdrantUrl = "http://localhost:6333";

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

    // Qdrant local
    final qdrantService = QdrantService(baseUrl: qdrantUrl, apiKey: null);

    // Ollama service (chỉ dùng cho embedding)
    final ollamaService = OllamaService();

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
