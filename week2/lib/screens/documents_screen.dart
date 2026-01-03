import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/document_model.dart';
import '../services/storage_service.dart';
import '../config.dart';
import '../services/rag_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import 'pdf_viewer_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late final StorageService _storageService;
  late final RAGService _ragService;
  List<DocumentModel> _documents = [];
  bool _isLoading = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final chatController = context.read<ChatController>();
    _ragService = chatController.ragService;
    _initServicesAndLoad();
  }

  Future<void> _initServicesAndLoad() async {
    _storageService = StorageService();
    await _storageService.init();
    await _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final authController = context.read<AuthController>();
    final userId = authController.currentUser?.uid;

    if (userId != null) {
      final docs = await _storageService.getUserDocuments(userId);
      if (!mounted) return;
      setState(() => _documents = docs);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadPDF() async {
    try {
      // Pick file với withData: true để có bytes trên Web
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Quan trọng cho Web!
      );

      if (!mounted) return;
      if (result == null) return;

      final platformFile = result.files.single;
      final fileName = platformFile.name;

      // Lấy bytes tùy theo platform
      Uint8List? fileBytes;

      if (kIsWeb) {
        // Trên Web: Chỉ dùng bytes
        fileBytes = platformFile.bytes;
        debugPrint('Web: Using bytes, length=${fileBytes?.length}');
      } else {
        // Trên Mobile: Ưu tiên bytes từ FilePicker
        fileBytes = platformFile.bytes;
        debugPrint('Mobile: Using bytes, length=${fileBytes?.length}');
      }

      // Kiểm tra bytes
      if (fileBytes == null || fileBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể đọc file. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() => _isProcessing = true);

      final authController = context.read<AuthController>();
      final userId = authController.currentUser!.uid;

      // Upload file
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang upload file...')),
        );
      }

      final document = await _storageService.uploadPDFBytes(
        userId: userId,
        bytes: fileBytes,
        fileName: fileName,
      );

      // Xử lý PDF
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang xử lý PDF...')),
        );
      }

      final success = await _ragService.processDocumentBytes(
        document: document,
        pdfBytes: fileBytes,
      );

      if (success) {
        await _storageService.updateDocumentProcessed(
          docId: document.id,
          qdrantCollectionId: 'doc_${document.id}',
          vectorCount: 0,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _loadDocuments();
      } else {
        throw 'Lỗi xử lý PDF';
      }
    } catch (e) {
      String message = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteDocument(DocumentModel document) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${document.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm != true) return;

    try {
      await _storageService.deleteDocument(document);

      if (document.qdrantCollectionId != null) {
        await _ragService.qdrantService.deleteCollection(
          document.qdrantCollectionId!,
        );
      }

      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa document')),
        );
      }
    } catch (e) {
      String message = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// Tìm hàm _selectDocument và sửa lại thành async
  Future<void> _selectDocument(DocumentModel document) async {
    if (!mounted) return;
    final chatController = context.read<ChatController>();

    // Đợi tải lịch sử xong
    await chatController.selectDocument(document);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chọn: ${document.fileName}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatController = context.watch<ChatController>();
    final selectedDoc = chatController.selectedDocument;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài liệu PDF'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Chưa có tài liệu nào'),
                      SizedBox(height: 8),
                      Text(
                        'Nhấn nút + để thêm PDF',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    final isSelected = selectedDoc?.id == doc.id;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: ListTile(
                        leading: Icon(
                          Icons.picture_as_pdf,
                          color: doc.isProcessed ? Colors.green : Colors.orange,
                          size: 40,
                        ),
                        title: Text(doc.fileName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(doc.fileSize / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              doc.isProcessed ? 'Đã xử lý' : 'Đang xử lý...',
                              style: TextStyle(
                                color: doc.isProcessed
                                    ? Colors.green
                                    : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'select',
                              child: Text('Chọn để chat'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Xóa',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'select') {
                              _selectDocument(doc);
                            } else if (value == 'delete') {
                              _deleteDocument(doc);
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PdfViewerScreen(
                                document: doc,
                                storageService: _storageService,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: _isProcessing
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : FloatingActionButton(
              onPressed: _pickAndUploadPDF,
              tooltip: 'Thêm PDF',
              child: const Icon(Icons.add),
            ),
    );
  }
}
