import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;

class QdrantService {
  final String baseUrl;
  final String? apiKey;

  QdrantService({
    required this.baseUrl,
    this.apiKey,
  });

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (apiKey != null) {
      headers['api-key'] = apiKey!;
    }
    return headers;
  }

  // Tạo collection mới
  Future<bool> createCollection({
    required String collectionName,
    required int vectorSize,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/collections/$collectionName');
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({
          'vectors': {
            'size': vectorSize,
            'distance': 'Cosine',
          }
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating collection: $e');
      return false;
    }
  }

  // Kiểm tra collection có tồn tại không
  Future<bool> collectionExists(String collectionName) async {
    try {
      final url = Uri.parse('$baseUrl/collections/$collectionName');
      final response = await http.get(url, headers: _headers);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error checking collection exists: $e');
      return false;
    }
  }

  // Thêm vectors vào collection
  Future<bool> upsertVectors({
    required String collectionName,
    required List<Map<String, dynamic>> points,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/collections/$collectionName/points');
      
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({
          'points': points,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error upserting vectors: $e');
      return false;
    }
  }

  // Tìm kiếm vectors tương tự
  Future<List<Map<String, dynamic>>> searchVectors({
    required String collectionName,
    required List<double> queryVector,
    int limit = 5,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/collections/$collectionName/points/search');
      
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'vector': queryVector,
          'limit': limit,
          'with_payload': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['result'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Error searching vectors: $e');
      return [];
    }
  }

  // Xóa collection
  Future<bool> deleteCollection(String collectionName) async {
    try {
      final url = Uri.parse('$baseUrl/collections/$collectionName');
      final response = await http.delete(url, headers: _headers);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting collection: $e');
      return false;
    }
  }

  // Lấy thông tin collection
  Future<Map<String, dynamic>?> getCollectionInfo(String collectionName) async {
    try {
      final url = Uri.parse('$baseUrl/collections/$collectionName');
      final response = await http.get(url, headers: _headers);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting collection info: $e');
      return null;
    }
  }
}