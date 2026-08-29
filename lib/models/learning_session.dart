class LearningSession {
  LearningSession({
    required this.id,
    required this.createdAtMs,
    required this.durationMin,
    required this.mode,
    required this.accuracyPct,
    required this.levelDelta,
    required this.improvements,
  });

  final String id;
  final int createdAtMs;
  final int durationMin;
  final String mode; // voice/text
  final int accuracyPct;
  final double levelDelta;
  final List<String> improvements;

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAtMs,
        'durationMin': durationMin,
        'mode': mode,
        'accuracyPct': accuracyPct,
        'levelDelta': levelDelta,
        'improvements': improvements,
      };

  factory LearningSession.fromMap(Map<String, dynamic> m) => LearningSession(
        id: m['id'] as String,
        createdAtMs: (m['createdAt'] ?? 0) as int,
        durationMin: (m['durationMin'] ?? 0) as int,
        mode: (m['mode'] ?? 'voice') as String,
        accuracyPct: (m['accuracyPct'] ?? 0) as int,
        levelDelta: (m['levelDelta'] ?? 0).toDouble(),
        improvements: (m['improvements'] as List?)?.cast<String>() ?? const [],
      );
}
