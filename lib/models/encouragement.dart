class EncouragementMessageKey {
  static const keepItUp = 'keep_it_up';
  static const proudOfYou = 'proud_of_you';
  static const stayConsistent = 'stay_consistent';
}

class Encouragement {
  Encouragement({
    required this.id,
    required this.studentId,
    required this.parentUid,
    required this.messageKey,
    required this.createdAtMs,
    this.seenAtMs,
  });

  final String id;
  final String studentId;
  final String parentUid;
  final String messageKey;
  final int createdAtMs;
  final int? seenAtMs;

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'parentUid': parentUid,
        'messageKey': messageKey,
        'createdAt': createdAtMs,
        'seenAt': seenAtMs,
      };

  factory Encouragement.fromMap(Map<String, dynamic> m) => Encouragement(
        id: m['id'] as String,
        studentId: m['studentId'] as String,
        parentUid: m['parentUid'] as String,
        messageKey:
            (m['messageKey'] ?? EncouragementMessageKey.keepItUp) as String,
        createdAtMs: (m['createdAt'] ?? 0) as int,
        seenAtMs: m['seenAt'] as int?,
      );
}
