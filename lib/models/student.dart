class Student {
  Student({
    required this.id,
    required this.name,
    required this.readingLevel,
    required this.weeklyProgress, // 0..1
    required this.timeSpentMinThisWeek,
    required this.voiceUsagePct,
    required this.engagement,
    required this.skillTrends,
    required this.parentUids,
    required this.preferredMode,
    this.todayGoal = 'Reading: Understanding paragraphs',
    required this.updatedAtMs,
  });

  final String id;
  final String name;
  final double readingLevel;
  final double weeklyProgress;
  final int timeSpentMinThisWeek;
  final int voiceUsagePct;
  final String engagement; // High/Med/Low
  final Map<String, String> skillTrends; // skill -> improving/needs_work
  final List<String> parentUids;
  final String preferredMode; // Voice/Text
  final String todayGoal;
  final int updatedAtMs;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'readingLevel': readingLevel,
        'weeklyProgress': weeklyProgress,
        'timeSpentMinThisWeek': timeSpentMinThisWeek,
        'voiceUsagePct': voiceUsagePct,
        'engagement': engagement,
        'skillTrends': skillTrends,
        'parentUids': parentUids,
        'preferredMode': preferredMode,
        'todayGoal': todayGoal,
        'updatedAtMs': updatedAtMs,
      };

  factory Student.fromMap(Map<String, dynamic> m) => Student(
        id: m['id'] as String,
        name: (m['name'] ?? 'Student') as String,
        readingLevel: (m['readingLevel'] ?? 3.9).toDouble(),
        weeklyProgress: (m['weeklyProgress'] ?? 0.45).toDouble(),
        timeSpentMinThisWeek: (m['timeSpentMinThisWeek'] ?? 0) as int,
        voiceUsagePct: (m['voiceUsagePct'] ?? 0) as int,
        engagement: (m['engagement'] ?? 'High') as String,
        skillTrends: (m['skillTrends'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            const {},
        parentUids: (m['parentUids'] as List?)?.cast<String>() ?? const [],
        preferredMode: (m['preferredMode'] ?? 'Voice') as String,
        todayGoal:
            (m['todayGoal'] ?? 'Reading: Understanding paragraphs') as String,
        updatedAtMs: (m['updatedAtMs'] ?? 0) as int,
      );
}
