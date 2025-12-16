class ChatMessage {
  final String role;
  String content;
  final DateTime timestamp;
  String? documentContext; // Context từ PDF (mutable so we can add it later)

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.documentContext,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'documentContext': documentContext,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      role: map['role'] ?? 'user',
      content: map['content'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      documentContext: map['documentContext'],
    );
  }
}