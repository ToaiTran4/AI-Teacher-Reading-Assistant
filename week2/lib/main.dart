import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// --- CONTROLLERS ---
import 'controllers/auth_controller.dart';
import 'controllers/chat_controller.dart';
// --- SERVICES ---
import 'services/chat_service.dart';
import 'services/ollama_service.dart';
import 'services/rag_service.dart';
import 'services/qdrant_service.dart';
// --- SCREENS ---
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
// --- THEME & CONFIG ---
import 'config.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart'; // ✅ Import ThemeProvider

// ===== CẤU HÌNH =====
const String geminiApiKey = "";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Khởi tạo các Service
    final chatService = ChatService(apiKey: geminiApiKey);

    final qdrantService = QdrantService(
      baseUrl: AppConfig.getQdrantUrl(),
      apiKey: null,
    );

    final ollamaService = OllamaService(baseUrl: AppConfig.getOllamaUrl());

    final ragService = RAGService(
      ollamaService: ollamaService,
      qdrantService: qdrantService,
    );

    return MultiProvider(
      providers: [
        // ✅ 2. Thêm ThemeProvider vào đây để quản lý giao diện toàn app
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(
          create: (_) => ChatController(
            chatService: chatService,
            ragService: ragService,
          ),
        ),
      ],
      // ✅ 3. Dùng Consumer để lắng nghe thay đổi theme
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'RAG Chat',
            debugShowCheckedModeBanner: false,

            // --- CẤU HÌNH THEME ---
            theme: AppTheme.lightTheme, // Giao diện Sáng
            darkTheme: AppTheme.darkTheme, // Giao diện Tối
            themeMode: themeProvider.themeMode, // Tự động chuyển theo settings
            // ---------------------

            home: const AuthWrapper(),
          );
        },
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
