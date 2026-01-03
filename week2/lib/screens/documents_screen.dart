import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/document_model.dart';
import '../services/storage_service.dart';
import '../services/rag_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../theme/app_theme.dart';
import '../utils/app_limits.dart';
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
            SnackBar(
              content: const Text('Không thể đọc file. Vui lòng thử lại.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      // Kiểm tra giới hạn kích thước file (50MB)
      if (!AppLimits.isValidFileSize(fileBytes.length)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File quá lớn! Kích thước tối đa: ${AppLimits.maxFileSizeMB}MB. '
                'File của bạn: ${AppLimits.formatFileSize(fileBytes.length)}',
              ),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 5),
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
            backgroundColor: AppTheme.errorColor,
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
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Xác nhận xóa',
          style: AppTheme.h3,
        ),
        content: Text(
          'Bạn có chắc muốn xóa "${document.fileName}"?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Hủy',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Xóa'),
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
          SnackBar(
            content: const Text('Đã xóa document'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      String message = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa: $message'),
            backgroundColor: AppTheme.errorColor,
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
          backgroundColor: AppTheme.successColor,
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingLG),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLG),
                      Text(
                        'Chưa có tài liệu nào',
                        style: AppTheme.h3.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        'Nhấn nút + để thêm PDF',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    final isSelected = selectedDoc?.id == doc.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withOpacity(0.15)
                            : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.all(AppTheme.spacingMD),
                        leading: Container(
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          decoration: BoxDecoration(
                            color: doc.isProcessed
                                ? AppTheme.successColor.withOpacity(0.2)
                                : AppTheme.warningColor.withOpacity(0.2),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf,
                            color: doc.isProcessed
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                            size: 32,
                          ),
                        ),
                        title: Text(
                          doc.fileName,
                          style: AppTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding:
                              const EdgeInsets.only(top: AppTheme.spacingXS),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(doc.fileSize / 1024).toStringAsFixed(1)} KB',
                                style: AppTheme.caption,
                              ),
                              const SizedBox(height: AppTheme.spacingXS),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingSM,
                                  vertical: AppTheme.spacingXS,
                                ),
                                decoration: BoxDecoration(
                                  color: doc.isProcessed
                                      ? AppTheme.successColor.withOpacity(0.2)
                                      : AppTheme.warningColor.withOpacity(0.2),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusSM),
                                ),
                                child: Text(
                                  doc.isProcessed
                                      ? 'Đã xử lý'
                                      : 'Đang xử lý...',
                                  style: AppTheme.caption.copyWith(
                                    color: doc.isProcessed
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: PopupMenuButton(
                          iconColor: AppTheme.textSecondary,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'select',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 20,
                                    color: AppTheme.textPrimary,
                                  ),
                                  const SizedBox(width: AppTheme.spacingSM),
                                  Text(
                                    'Chọn để chat',
                                    style: AppTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: AppTheme.errorColor,
                                  ),
                                  const SizedBox(width: AppTheme.spacingSM),
                                  Text(
                                    'Xóa',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ],
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
          ? FloatingActionButton(
              onPressed: null,
              backgroundColor: AppTheme.primaryColor,
              child: const CircularProgressIndicator(
                color: AppTheme.textOnPrimary,
                strokeWidth: 2,
              ),
            )
          : FloatingActionButton.extended(
              onPressed: _pickAndUploadPDF,
              tooltip: 'Thêm PDF',
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add),
              label: const Text('Thêm PDF'),
            ),
    );
  }
}
