import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';

/// Universal Storage Service với GridFS
/// - Web: Upload qua REST API
/// - Mobile/Desktop: Lưu trực tiếp MongoDB GridFS
class StorageService {
  final String apiUrl;
  final String mongoUri;

  late Db _db;
  late DbCollection _documentsCollection;
  late DbCollection _filesCollection; // GridFS fs.files
  final _uuid = Uuid();
  bool _isInitialized = false;

  StorageService({
    this.apiUrl = 'http://localhost:3000/api',
    this.mongoUri = 'mongodb://localhost:27017/Teachain',
  });

  Future<void> init() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      debugPrint('🌐 Storage on WEB - Using REST API');
      _isInitialized = true;
    } else {
      debugPrint('📱 Storage on MOBILE/DESKTOP - Direct MongoDB GridFS');
      try {
        _db = Db(mongoUri);
        await _db.open();
        _documentsCollection = _db.collection('documents');
        _filesCollection = _db.collection('fs.files'); // GridFS collection
        _isInitialized = true;
        debugPrint('✅ Storage MongoDB connected!');
      } catch (e) {
        debugPrint('❌ Storage MongoDB error: $e');
        throw 'Không thể kết nối MongoDB: $e';
      }
    }
  }

  Future<void> dispose() async {
    if (!kIsWeb && _isInitialized) {
      await _db.close();
    }
  }

  // ============= UPLOAD DOCUMENT =============
  Future<DocumentModel> uploadPDFBytes({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!_isInitialized) await init();

    if (kIsWeb) {
      return _uploadViaAPI(userId, bytes, fileName);
    } else {
      return _uploadViaMongo(userId, bytes, fileName);
    }
  }

  Future<DocumentModel> _uploadViaAPI(
    String userId,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final docId = _uuid.v4();

      debugPrint('📤 Uploading via API: $fileName (${bytes.length} bytes)');

      // Nếu file nhỏ (<10MB), upload thẳng
      if (bytes.length < 10 * 1024 * 1024) {
        return _uploadDirectAPI(docId, userId, bytes, fileName);
      }

      // Nếu file lớn, upload theo chunks
      return _uploadChunkedAPI(docId, userId, bytes, fileName);
    } catch (e) {
      debugPrint('❌ Lỗi upload (API): $e');
      rethrow;
    }
  }

  // Upload trực tiếp (file nhỏ)
  Future<DocumentModel> _uploadDirectAPI(
    String docId,
    String userId,
    Uint8List bytes,
    String fileName,
  ) async {
    final base64Data = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('$apiUrl/documents/upload'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'docId': docId,
        'userId': userId,
        'fileName': fileName,
        'fileData': base64Data,
        'fileSize': bytes.length,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      debugPrint('✅ Upload thành công (API Direct): $fileName');
      return DocumentModel.fromMap(data['document']);
    } else {
      final error = jsonDecode(response.body);
      throw error['message'] ?? 'Lỗi upload';
    }
  }

  // Upload theo chunks (file lớn)
  Future<DocumentModel> _uploadChunkedAPI(
    String docId,
    String userId,
    Uint8List bytes,
    String fileName,
  ) async {
    const chunkSize = 1024 * 1024; // 1MB per chunk
    final totalChunks = (bytes.length / chunkSize).ceil();

    debugPrint('📦 Chunked upload: $totalChunks chunks');

    // 1. Start upload session
    final startResponse = await http.post(
      Uri.parse('$apiUrl/documents/upload/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'docId': docId,
        'userId': userId,
        'fileName': fileName,
        'fileSize': bytes.length,
        'totalChunks': totalChunks,
      }),
    );

    if (startResponse.statusCode != 200) {
      throw 'Không thể bắt đầu upload';
    }

    // 2. Upload từng chunk
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end =
          (start + chunkSize < bytes.length) ? start + chunkSize : bytes.length;

      final chunk = bytes.sublist(start, end);
      final chunkBase64 = base64Encode(chunk);

      final chunkResponse = await http.post(
        Uri.parse('$apiUrl/documents/upload/chunk'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'docId': docId,
          'chunkIndex': i,
          'chunkData': chunkBase64,
        }),
      );

      if (chunkResponse.statusCode == 200) {
        final data = jsonDecode(chunkResponse.body);
        final progress = data['progress'];
        debugPrint('📤 Upload progress: $progress%');
      } else {
        throw 'Lỗi upload chunk $i';
      }
    }

    // 3. Complete upload
    final completeResponse = await http.post(
      Uri.parse('$apiUrl/documents/upload/complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'docId': docId}),
    );

    if (completeResponse.statusCode == 200) {
      final data = jsonDecode(completeResponse.body);
      debugPrint('✅ Upload thành công (API Chunked): $fileName');
      return DocumentModel.fromMap(data['document']);
    } else {
      final error = jsonDecode(completeResponse.body);
      throw error['message'] ?? 'Lỗi hoàn tất upload';
    }
  }

  Future<DocumentModel> _uploadViaMongo(
    String userId,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final docId = _uuid.v4();

      debugPrint('📤 Uploading via MongoDB: $fileName (${bytes.length} bytes)');

      // Lưu vào GridFS (fs.files collection)
      final fileDoc = {
        '_id': docId,
        'filename': fileName,
        'userId': userId,
        'data': bytes,
        'length': bytes.length,
        'uploadedAt': DateTime.now().toIso8601String(),
        'contentType': 'application/pdf',
      };

      await _filesCollection.insertOne(fileDoc);
      debugPrint('✅ File saved to GridFS: $docId');

      // Lưu metadata vào documents collection
      final document = DocumentModel(
        id: docId,
        userId: userId,
        fileName: fileName,
        storageUrl: 'mongo://fs.files/$docId',
        fileSize: bytes.length,
        uploadedAt: DateTime.now(),
        isProcessed: false,
      );

      await _documentsCollection.insertOne(document.toMap());
      debugPrint('✅ Upload thành công (MongoDB): $fileName');

      return document;
    } catch (e) {
      debugPrint('❌ Lỗi upload (MongoDB): $e');
      throw 'Lỗi upload file: $e';
    }
  }

  // ============= GET USER DOCUMENTS =============
  Future<List<DocumentModel>> getUserDocuments(String userId) async {
    if (!_isInitialized) await init();

    if (kIsWeb) {
      return _getUserDocumentsViaAPI(userId);
    } else {
      return _getUserDocumentsViaMongo(userId);
    }
  }

  Future<List<DocumentModel>> _getUserDocumentsViaAPI(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/documents/user/$userId'),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((doc) => DocumentModel.fromMap(doc)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Lỗi get documents (API): $e');
      return [];
    }
  }

  Future<List<DocumentModel>> _getUserDocumentsViaMongo(String userId) async {
    try {
      final cursor = await _documentsCollection
          .find(
              where.eq('userId', userId).sortBy('uploadedAt', descending: true))
          .toList();

      return cursor
          .map((doc) => DocumentModel.fromMap(Map<String, dynamic>.from(doc)))
          .toList();
    } catch (e) {
      debugPrint('❌ Lỗi get documents (MongoDB): $e');
      return [];
    }
  }

  // ============= STREAM USER DOCUMENTS =============
  Stream<List<DocumentModel>> streamUserDocuments(String userId) async* {
    while (true) {
      final list = await getUserDocuments(userId);
      yield list;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // ============= UPDATE DOCUMENT PROCESSED =============
  Future<void> updateDocumentProcessed({
    required String docId,
    required String qdrantCollectionId,
    required int vectorCount,
  }) async {
    if (!_isInitialized) await init();

    if (kIsWeb) {
      await _updateDocumentViaAPI(docId, qdrantCollectionId, vectorCount);
    } else {
      await _updateDocumentViaMongo(docId, qdrantCollectionId, vectorCount);
    }
  }

  Future<void> _updateDocumentViaAPI(
    String docId,
    String qdrantCollectionId,
    int vectorCount,
  ) async {
    try {
      await http.patch(
        Uri.parse('$apiUrl/documents/$docId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'isProcessed': true,
          'qdrantCollectionId': qdrantCollectionId,
          'vectorCount': vectorCount,
        }),
      );
    } catch (e) {
      debugPrint('❌ Lỗi update document (API): $e');
      rethrow;
    }
  }

  Future<void> _updateDocumentViaMongo(
    String docId,
    String qdrantCollectionId,
    int vectorCount,
  ) async {
    try {
      await _documentsCollection.updateOne(
        where.eq('id', docId),
        modify
            .set('isProcessed', true)
            .set('qdrantCollectionId', qdrantCollectionId)
            .set('vectorCount', vectorCount),
      );
    } catch (e) {
      debugPrint('❌ Lỗi update document (MongoDB): $e');
      throw 'Lỗi cập nhật document: $e';
    }
  }

  // ============= DELETE DOCUMENT =============
  Future<void> deleteDocument(DocumentModel document) async {
    if (!_isInitialized) await init();

    if (kIsWeb) {
      await _deleteDocumentViaAPI(document);
    } else {
      await _deleteDocumentViaMongo(document);
    }
  }

  Future<void> _deleteDocumentViaAPI(DocumentModel document) async {
    try {
      await http.delete(
        Uri.parse('$apiUrl/documents/${document.id}'),
      );
      debugPrint('✅ Xóa document thành công (API)');
    } catch (e) {
      debugPrint('❌ Lỗi xóa document (API): $e');
      throw 'Lỗi xóa document: $e';
    }
  }

  Future<void> _deleteDocumentViaMongo(DocumentModel document) async {
    try {
      // Xóa file từ GridFS
      if (document.storageUrl.startsWith('mongo://fs.files/')) {
        final docId = document.storageUrl.split('/').last;
        await _filesCollection.deleteOne(where.eq('_id', docId));
      }

      // Xóa metadata
      await _documentsCollection.deleteOne(where.eq('id', document.id));

      debugPrint('✅ Xóa document thành công (MongoDB)');
    } catch (e) {
      debugPrint('❌ Lỗi xóa document (MongoDB): $e');
      throw 'Lỗi xóa document: $e';
    }
  }

  // ============= DOWNLOAD DOCUMENT =============
  Future<Uint8List> downloadDocumentBytes(DocumentModel document) async {
    if (!_isInitialized) await init();

    if (kIsWeb) {
      return _downloadViaAPI(document);
    } else {
      return _downloadViaMongo(document);
    }
  }

  Future<Uint8List> _downloadViaAPI(DocumentModel document) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/documents/${document.id}/download'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final base64Data = data['fileData'];
        return base64Decode(base64Data);
      } else {
        throw 'Không thể download file';
      }
    } catch (e) {
      debugPrint('❌ Lỗi download (API): $e');
      throw 'Lỗi download file: $e';
    }
  }

  Future<Uint8List> _downloadViaMongo(DocumentModel document) async {
    try {
      if (document.storageUrl.startsWith('mongo://fs.files/')) {
        final docId = document.storageUrl.split('/').last;

        final fileDoc = await _filesCollection.findOne(where.eq('_id', docId));

        if (fileDoc == null) {
          throw 'File không tồn tại trong MongoDB';
        }

        final data = fileDoc['data'];

        if (data is Uint8List) {
          return data;
        } else if (data is List<int>) {
          return Uint8List.fromList(data);
        } else if (data is List) {
          // Trường hợp List<dynamic> → cast sang List<int>
          try {
            final list = data.cast<int>();
            return Uint8List.fromList(list);
          } catch (_) {
            throw 'Định dạng data không hợp lệ (List<dynamic> không phải int): ${data.runtimeType}';
          }
        } else {
          // mongo_dart có thể trả về kiểu Binary/BsonBinary cho dữ liệu nhị phân
          try {
            final dynamic binary = data;
            final bytes = (binary.bytes ?? binary.byteList) as List<int>;
            return Uint8List.fromList(bytes);
          } catch (_) {
            throw 'Định dạng data không hợp lệ: ${data.runtimeType}';
          }
        }
      } else {
        throw 'Storage URL không hợp lệ';
      }
    } catch (e) {
      debugPrint('❌ Lỗi download (MongoDB): $e');
      throw 'Lỗi download file: $e';
    }
  }
}
