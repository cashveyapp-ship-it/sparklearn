class ChatMessage {
  ChatMessage({
    required this.id,
    required this.studentId,
    required this.role, // user|assistant
    required this.text,
    required this.createdAtMs,
  });

  final String id;
  final String studentId;
  final String role;
  final String text;
  final int createdAtMs;

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'role': role,
        'text': text,
        'createdAt': createdAtMs,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        studentId: m['studentId'] as String,
        role: (m['role'] ?? 'user') as String,
        text: (m['text'] ?? '') as String,
        createdAtMs: (m['createdAt'] ?? 0) as int,
      );
}
