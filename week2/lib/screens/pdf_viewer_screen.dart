import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../models/document_model.dart';
import '../services/storage_service.dart';
import '../controllers/chat_controller.dart';

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
  int _initialPage = 1;
  double _zoomLevel = 1.0;
  String? _currentSelectedText;

  String get _prefsKey => 'pdf_last_page_${widget.document.id}';

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _initialPage = prefs.getInt(_prefsKey) ?? 1;

      final bytes =
          await widget.storageService.downloadDocumentBytes(widget.document);

      if (!mounted) return;

      setState(() {
        _pdfBytes = bytes;
        _isLoading = false;
      });

      // Jump to last page after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_initialPage > 1) {
          _pdfController.jumpToPage(_initialPage);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể mở PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveLastPage(int pageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, pageNumber);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _pdfBytes == null ? null : _zoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _pdfBytes == null ? null : _zoomIn,
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonLoader()
          : _pdfBytes == null
              ? const Center(
                  child: Text('Không thể tải PDF'),
                )
              : Stack(
                  children: [
                    SfPdfViewer.memory(
                      _pdfBytes!,
                      key: _pdfKey,
                      controller: _pdfController,
                      canShowScrollStatus: true,
                      enableTextSelection: true,
                      onPageChanged: (details) {
                        _saveLastPage(details.newPageNumber);
                      },
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
                            // Xóa selection để toolbar mặc định không che UI chat
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

  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSkeletonBox(width: 120, height: 20),
              Row(
                children: [
                  _buildSkeletonCircle(size: 32),
                  const SizedBox(width: 12),
                  _buildSkeletonCircle(size: 32),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              children: [
                _buildSkeletonBox(height: 12),
                const SizedBox(height: 8),
                _buildSkeletonBox(height: 12),
                const SizedBox(height: 8),
                _buildSkeletonBox(height: 12),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildSkeletonBox(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({double? width, double? height}) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildSkeletonCircle({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
    );
  }

  Future<void> _openAskAIBottomSheet(String selectedText) async {
    final chatController = context.read<ChatController>();
    // Tạo stream một lần để tránh gọi API nhiều lần khi UI rebuild.
    final answerStream = chatController.askAboutSelection(
      selectedText: selectedText,
      document: widget.document,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return StreamBuilder<String>(
                stream: answerStream,
                builder: (context, snapshot) {
                  final isLoading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final answer = snapshot.data ?? '';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Giải thích từ AI',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Đoạn được chọn:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            selectedText,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isLoading
                                  ? 'Đang trả lời...'
                                  : 'Câu trả lời của AI',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Copy câu trả lời',
                                  icon: const Icon(Icons.copy),
                                  onPressed: answer.isEmpty
                                      ? null
                                      : () {
                                          Clipboard.setData(
                                            ClipboardData(text: answer),
                                          );
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Đã copy câu trả lời'),
                                            ),
                                          );
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: Text(
                              answer.isEmpty
                                  ? (isLoading
                                      ? ''
                                      : 'Không nhận được câu trả lời từ AI.')
                                  : answer,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.question_answer_outlined),
                            label: const Text('Hỏi thêm trong màn hình Chat'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
