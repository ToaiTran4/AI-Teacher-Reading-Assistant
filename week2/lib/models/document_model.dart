class DocumentModel {
  final String id;
  final String userId;
  final String fileName;
  final String storageUrl; // URL trên Firebase Storage
  final int fileSize;
  final DateTime uploadedAt;
  final bool isProcessed; // Đã xử lý và đưa vào Qdrant chưa
  final String? qdrantCollectionId; // Collection ID trong Qdrant
  final int? vectorCount; // Số lượng vectors đã tạo

  DocumentModel({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.storageUrl,
    required this.fileSize,
    required this.uploadedAt,
    this.isProcessed = false,
    this.qdrantCollectionId,
    this.vectorCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fileName': fileName,
      'storageUrl': storageUrl,
      'fileSize': fileSize,
      'uploadedAt': uploadedAt.toIso8601String(),
      'isProcessed': isProcessed,
      'qdrantCollectionId': qdrantCollectionId,
      'vectorCount': vectorCount,
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      fileName: map['fileName'] ?? '',
      storageUrl: map['storageUrl'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      uploadedAt: DateTime.parse(map['uploadedAt']),
      isProcessed: map['isProcessed'] ?? false,
      qdrantCollectionId: map['qdrantCollectionId'],
      vectorCount: map['vectorCount'],
    );
  }

  DocumentModel copyWith({
    String? id,
    String? userId,
    String? fileName,
    String? storageUrl,
    int? fileSize,
    DateTime? uploadedAt,
    bool? isProcessed,
    String? qdrantCollectionId,
    int? vectorCount,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fileName: fileName ?? this.fileName,
      storageUrl: storageUrl ?? this.storageUrl,
      fileSize: fileSize ?? this.fileSize,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isProcessed: isProcessed ?? this.isProcessed,
      qdrantCollectionId: qdrantCollectionId ?? this.qdrantCollectionId,
      vectorCount: vectorCount ?? this.vectorCount,
    );
  }
}