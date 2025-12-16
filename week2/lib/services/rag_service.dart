import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/document_model.dart';
import 'ollama_service.dart'; 
import 'qdrant_service.dart';

class RAGService {
  final OllamaService ollamaService; //
  final QdrantService qdrantService;
  final _uuid = Uuid();

  RAGService({
    required this.ollamaService,
    required this.qdrantService,
  });

  // Extract text từ PDF bytes
  Future<String> extractTextFromPDFBytes(Uint8List pdfBytes) async {
    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      final textExtractor = PdfTextExtractor(document);
      final text = textExtractor.extractText();
      document.dispose();
      
      // Normalize whitespace
      return text.trim().replaceAll(RegExp(r'\s+'), ' ');
    } catch (e) {
      throw 'Lỗi đọc PDF: $e';
    }
  }

  // Chia text thành chunks nhỏ
  List<String> splitTextIntoChunks(String text, {int chunkSize = 500, int overlap = 100}) {
    final words = text.split(' ');
    final chunks = <String>[];
    
    // Nếu text quá ngắn, trả về toàn bộ
    if (words.length <= chunkSize) {
      final chunk = words.join(' ').trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      return chunks;
    }
    
    for (int i = 0; i < words.length; i += (chunkSize - overlap)) {
      final end = (i + chunkSize).clamp(0, words.length); // ← FIX: Dùng clamp
      final chunk = words.sublist(i, end).join(' ');
      if (chunk.trim().isNotEmpty) {
        chunks.add(chunk);
      }
      
      // Nếu đã đến cuối, thoát loop
      if (end >= words.length) break;
    }
    
    return chunks;
  }

  // Tạo embedding từ text sử dụng OpenAI
  Future<List<double>> createEmbedding(String text) async {
    try {
      final embedding = await ollamaService.createEmbedding(text);
      return embedding;
    } catch (e) {
      throw 'Lỗi tạo embedding: $e';
    }
  }

  // Xử lý PDF từ bytes và lưu vào Qdrant
  Future<bool> processDocumentBytes({
    required DocumentModel document,
    required Uint8List pdfBytes,
  }) async {
    try {
      // 1. Extract text từ PDF bytes
      debugPrint('Extracting text from PDF...');
      final text = await extractTextFromPDFBytes(pdfBytes);
      
      if (text.trim().isEmpty) {
        throw 'PDF không chứa text';
      }

      // 2. Chia thành chunks
      debugPrint('Splitting text into chunks...');
      final chunks = splitTextIntoChunks(text);
      debugPrint('Created ${chunks.length} chunks');

      // 3. Tạo collection name từ document ID
      final collectionName = 'doc_${document.id}';

      // 4. Tạo collection trong Qdrant (nếu chưa có)
      debugPrint('Creating Qdrant collection...');
      final collectionExists = await qdrantService.collectionExists(collectionName);
      
      if (!collectionExists) {
        await qdrantService.createCollection(
          collectionName: collectionName,
          vectorSize: 768, 
        );
      }

      // 5. Tạo embeddings và upload lên Qdrant
      debugPrint('Creating embeddings and uploading to Qdrant...');
      final points = <Map<String, dynamic>>[];
      
      for (int i = 0; i < chunks.length; i++) {
        debugPrint('Processing chunk ${i + 1}/${chunks.length}');
        
        final embedding = await createEmbedding(chunks[i]);
        
        points.add({
          'id': _uuid.v4(),
          'vector': embedding,
          'payload': {
            'text': chunks[i],
            'chunk_index': i,
            'document_id': document.id,
            'document_name': document.fileName,
          },
        });

        // Upload theo batch để tránh request quá lớn
        if (points.length >= 10 || i == chunks.length - 1) {
          await qdrantService.upsertVectors(
            collectionName: collectionName,
            points: points,
          );
          points.clear();
        }
      }

      debugPrint('Document processed successfully!');
      return true;
    } catch (e) {
      debugPrint('Error processing document: $e');
      return false;
    }
  }

  // Tìm kiếm context liên quan từ Qdrant
  Future<String> retrieveContext({
    required String query,
    required String collectionName,
    int topK = 3,
  }) async {
    try {
      // 1. Tạo embedding cho query
      final queryEmbedding = await createEmbedding(query);

      // 2. Search trong Qdrant
      final results = await qdrantService.searchVectors(
        collectionName: collectionName,
        queryVector: queryEmbedding,
        limit: topK,
      );

      // 3. Ghép các text chunks lại
      final contexts = results
          .map((result) => result['payload']['text'] as String)
          .toList();

      return contexts.join('\n\n---\n\n');
    } catch (e) {
      debugPrint('Error retrieving context: $e');
      return '';
    }
  }
}