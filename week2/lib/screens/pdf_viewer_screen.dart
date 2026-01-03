import 'dart:async';
import 'dart:convert'; // [MỚI] Để mã hóa/giải mã JSON
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/document_model.dart';
import '../models/quiz_model.dart'; // Đảm bảo đã cập nhật file này
import '../services/storage_service.dart';
import '../controllers/chat_controller.dart';
import 'quiz_screen.dart';

class PdfViewerScreen extends StatefulWidget {
  final DocumentModel document;
  final StorageService storageService;

  const PdfViewerScreen({
    super.key,
    required this.document,
    required this.storageService,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey();

  Uint8List? _pdfBytes;
  bool _isLoading = true;

  int _currentPage = 1;
  int _totalPages = 0;
  double _zoomLevel = 1.0;
  String? _currentSelectedText;
  bool _isCompletedLocal = false;

  PdfDocument? _extractedPdfDocument;

  Timer? _readingTimer;
  final Set<int> _readPages = {};
  final int _timeThreshold = 45;

  int _lastSummarizedPage = 0;

  String get _prefsKey => 'pdf_last_page_${widget.document.id}';
  // [MỚI] Key để lưu lịch sử quiz cho tài liệu này
  String get _quizHistoryKey => 'quiz_history_${widget.document.id}';

  @override
  void initState() {
    super.initState();
    _currentPage = 1;
    _isCompletedLocal = widget.document.isCompleted;
    _loadPdf();
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _extractedPdfDocument?.dispose();
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt(_prefsKey) ?? 1;

      setState(() {
        _currentPage = savedPage;
      });

      final bytes =
          await widget.storageService.downloadDocumentBytes(widget.document);
      final document = PdfDocument(inputBytes: bytes);

      if (!mounted) return;

      setState(() {
        _pdfBytes = bytes;
        _extractedPdfDocument = document;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (savedPage > 1) {
          _pdfController.jumpToPage(savedPage);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Không thể mở PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveLastPage(int pageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, pageNumber);

    if (_totalPages > 0 && pageNumber >= _totalPages && !_isCompletedLocal) {
      setState(() {
        _isCompletedLocal = true;
      });
    }
  }

  // [MỚI] Lưu quiz vào lịch sử
  Future<void> _saveQuizHistory(
      List<QuizModel> questions, int startPage, int endPage) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Tạo object chứa thông tin lần tạo quiz này
    final quizSession = {
      'date': DateTime.now().toIso8601String(),
      'range': 'Trang $startPage - $endPage',
      'questions': questions.map((q) => q.toJson()).toList(),
    };

    // 2. Lấy danh sách cũ lên
    List<String> history = prefs.getStringList(_quizHistoryKey) ?? [];

    // 3. Thêm cái mới vào đầu danh sách
    history.insert(0, jsonEncode(quizSession));

    // 4. Lưu lại (Giới hạn lưu 20 bài gần nhất để nhẹ máy)
    if (history.length > 20) history = history.sublist(0, 20);
    await prefs.setStringList(_quizHistoryKey, history);
  }

  // [MỚI] Hiển thị danh sách lịch sử để làm lại
  Future<void> _showQuizHistoryDialog() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_quizHistoryKey) ?? [];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        if (history.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text("Chưa có bài kiểm tra nào được tạo.")),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Lịch sử bài kiểm tra",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final session = jsonDecode(history[index]);
                    final date = DateTime.parse(session['date']);
                    final range = session['range'];
                    final questionsRaw = session['questions'] as List;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.history_edu, color: Colors.white),
                        ),
                        title: Text(range,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            "Tạo lúc: ${date.hour}:${date.minute} - ${date.day}/${date.month}"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Parse lại câu hỏi và mở màn hình làm bài
                          final questions = questionsRaw
                              .map((e) => QuizModel.fromJson(e))
                              .toList();
                          Navigator.pop(context); // Đóng modal
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  QuizScreen(questions: questions),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getCombinedText(int startPage, int endPage) {
    String combinedText = '';
    for (int i = startPage; i <= endPage; i++) {
      String pageText = PdfTextExtractor(_extractedPdfDocument!)
          .extractText(startPageIndex: i - 1, endPageIndex: i - 1);
      combinedText += "--- Nội dung trang $i ---\n$pageText\n\n";
    }
    return combinedText;
  }

  Future<void> _summarizeRange(int endPage) async {
    if (_extractedPdfDocument == null) return;
    int startPage = _lastSummarizedPage + 1;
    if (startPage > endPage) startPage = endPage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String combinedText = _getCombinedText(startPage, endPage);
      if (combinedText.trim().isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không có nội dung văn bản.')));
        return;
      }

      final prompt =
          'Tóm tắt ngắn gọn nội dung từ trang $startPage đến trang $endPage trong 3 gạch đầu dòng:\n\n$combinedText';
      final chatController = context.read<ChatController>();
      final stream = chatController.chatService.sendMessage(prompt);

      String fullAnswer = '';
      await for (final chunk in stream) {
        fullAnswer += chunk;
      }

      if (!mounted) return;
      Navigator.pop(context);

      setState(() {
        _lastSummarizedPage = endPage;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Tóm tắt trang $startPage - $endPage'),
          content: SingleChildScrollView(child: Text(fullAnswer)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _createQuizForRange(int endPage) async {
    if (_extractedPdfDocument == null) return;
    int startPage = _lastSummarizedPage + 1;
    if (startPage > endPage) startPage = endPage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String combinedText = _getCombinedText(startPage, endPage);
      if (combinedText.trim().isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không có nội dung để tạo Quiz.')));
        return;
      }

      final chatController = context.read<ChatController>();
      final questions = await chatController.generateQuizFromText(combinedText);

      if (!mounted) return;
      Navigator.pop(context);

      if (questions.isNotEmpty) {
        // [MỚI] Lưu quiz vừa tạo vào lịch sử ngay lập tức
        await _saveQuizHistory(questions, startPage, endPage);

        setState(() {
          _lastSummarizedPage = endPage;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(questions: questions),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI không thể tạo câu hỏi.')));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.25).clamp(1.0, 3.0);
      _pdfController.zoomLevel = _zoomLevel;
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.25).clamp(1.0, 3.0);
      _pdfController.zoomLevel = _zoomLevel;
    });
  }

  double get _readPercentage {
    if (_totalPages == 0) return 0.0;
    return (_currentPage / _totalPages);
  }

  @override
  Widget build(BuildContext context) {
    final progressText = _totalPages > 0
        ? 'Trang $_currentPage/$_totalPages - ${(_readPercentage * 100).toStringAsFixed(1)}%'
        : 'Đang tải...';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.document.fileName,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis),
            Text(progressText,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          // [MỚI] Nút Lịch sử Quiz
          IconButton(
            tooltip: "Lịch sử kiểm tra",
            icon: const Icon(Icons.history, color: Colors.blue),
            onPressed: () => _showQuizHistoryDialog(),
          ),

          if (_isCompletedLocal)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(Icons.check_circle, color: Colors.green),
            ),
          IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: _pdfBytes == null ? null : _zoomOut),
          IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: _pdfBytes == null ? null : _zoomIn),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: _isLoading
              ? const LinearProgressIndicator()
              : LinearProgressIndicator(
                  value: _readPercentage,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(_isCompletedLocal
                      ? Colors.green
                      : Theme.of(context).primaryColor),
                ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfBytes == null
              ? const Center(child: Text('Không thể tải PDF'))
              : Stack(
                  children: [
                    SfPdfViewer.memory(
                      _pdfBytes!,
                      key: _pdfKey,
                      controller: _pdfController,
                      canShowScrollStatus: true,
                      enableTextSelection: true,

                      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _totalPages = details.document.pages.count;
                              if (_currentPage >= _totalPages) {
                                _isCompletedLocal = true;
                              }
                            });
                          }
                        });
                      },

                      onPageChanged: (PdfPageChangedDetails details) {
                        _readingTimer?.cancel();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted)
                            setState(() {
                              _currentPage = details.newPageNumber;
                            });
                        });

                        _readingTimer =
                            Timer(Duration(seconds: _timeThreshold), () {
                          if (mounted) {
                            setState(() {
                              _readPages.add(details.newPageNumber);
                            });
                            _saveLastPage(details.newPageNumber);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Đã đọc xong trang ${details.newPageNumber}. Bạn muốn làm gì?',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Colors.yellowAccent),
                                          foregroundColor: Colors.yellowAccent,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                        onPressed: () => _summarizeRange(
                                            details.newPageNumber),
                                        icon: const Icon(Icons.summarize),
                                        label: const Text('TÓM TẮT NỘI DUNG'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.greenAccent,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                        onPressed: () => _createQuizForRange(
                                            details.newPageNumber),
                                        icon: const Icon(Icons.quiz),
                                        label: const Text('LÀM BÀI QUIZ NGAY'),
                                      ),
                                    ),
                                  ],
                                ),
                                duration: const Duration(seconds: 15),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        });
                      },

                      // ... Giữ nguyên phần Text Selection
                      onTextSelectionChanged: (details) {
                        setState(() {
                          final txt = details.selectedText?.trim() ?? '';
                          _currentSelectedText = txt.isNotEmpty ? txt : null;
                        });
                      },
                    ),
                    if (_currentSelectedText != null)
                      Positioned(
                        right: 16,
                        bottom: 24,
                        child: FloatingActionButton.extended(
                          heroTag: 'ask_ai_fab',
                          onPressed: () {
                            final text = _currentSelectedText;
                            if (text == null || text.isEmpty) return;
                            _pdfController.clearSelection();
                            _openAskAIBottomSheet(text);
                          },
                          icon: const Icon(Icons.smart_toy_outlined),
                          label: const Text('Hỏi AI'),
                        ),
                      ),
                  ],
                ),
    );
  }

  Future<void> _openAskAIBottomSheet(String selectedText) async {
    final chatController = context.read<ChatController>();
    final stream = chatController.askAboutSelection(
        selectedText: selectedText, document: widget.document);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (ctx, scroll) => StreamBuilder<String>(
          stream: stream,
          builder: (ctx, snap) => Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              controller: scroll,
              child: Text(snap.data ?? 'Đang suy nghĩ...'),
            ),
          ),
        ),
      ),
    );
  }
}
