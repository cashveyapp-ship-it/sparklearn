import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../providers/firebase_providers.dart';
import '../../providers/student_provider.dart';
import '../../services/practice_repository.dart';
import '../../services/adaptive_difficulty.dart';
import 'celebration_screen.dart';
import 'package:uuid/uuid.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.studentId});
  final String studentId;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  final _repo = PracticeRepository();
  int _bucket = 3;
  int _idx = 0;
  int _correct = 0;
  int _total = 0;
  bool _loading = true;
  String _activeGoal = 'Reading: Understanding paragraphs';

  List<PracticeItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final student =
        ref.read(studentDocProvider(widget.studentId)).asData?.value;
    final level = student?.readingLevel ?? 3.9;
    final goal = student?.todayGoal ?? 'Reading: Understanding paragraphs';
    _activeGoal = goal;
    _bucket = level.round().clamp(3, 4);
    _items = await _repo.loadReadingItems(
      _bucket,
      goal: goal,
    );
    _idx = 0;
    _correct = 0;
    _total = 0;
    setState(() => _loading = false);
  }

  Future<void> _answer(String choice) async {
    final item = _items[_idx];
    _total += 1;

    // Gentle evaluation: check for keyword overlap
    final c = choice.toLowerCase();
    final ideal = item.ideal.toLowerCase();
    final ok = _softMatch(c, ideal);

    if (ok) _correct += 1;

    final feedback = ok
        ? 'Nice work - that' 's right.'
        : 'Good try. A gentle hint: ${_hint(ideal)}';

    // Show snack (no red X)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(feedback),
        backgroundColor: ok ? AppColors.green : AppColors.indigo,
        behavior: SnackBarBehavior.floating,
      ),
    );

    await Future.delayed(600.ms);

    if (!mounted) return;

    if (_idx < _items.length - 1) {
      setState(() => _idx += 1);
    } else {
      await _finishSession();
    }
  }

  Future<void> _finishSession() async {
    final accuracy = (_correct / max(1, _total) * 100).round();

    final student =
        ref.read(studentDocProvider(widget.studentId)).asData?.value;
    final currentBucket = (student?.readingLevel ?? 3.9).round().clamp(3, 6);
    final nextBucket = nextReadingLevelBucket(
        currentBucket: currentBucket, lastAccuracyPct: accuracy);

    final levelDelta = nextBucket == currentBucket
        ? 0.0
        : (nextBucket > currentBucket ? 0.2 : -0.2);

    final improvements = <String>[];
    if (accuracy >= 80) improvements.add('Reading accuracy improved');
    improvements.add('Faster responses');
    improvements.add('More confidence');

    final db = ref.read(firestoreProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionId = const Uuid().v4();

    // Write session
    await db
        .collection('students')
        .doc(widget.studentId)
        .collection('sessions')
        .doc(sessionId)
        .set({
      'id': sessionId,
      'createdAt': now,
      'durationMin': 7,
      'mode': 'voice',
      'accuracyPct': accuracy,
      'levelDelta': levelDelta,
      'improvements': improvements,
    });

    // Update student stats
    final newLevel =
        ((student?.readingLevel ?? 3.9) + levelDelta).clamp(1.0, 12.0);

    final currentDate = DateTime.now();
    final weekStart = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    ).subtract(Duration(days: currentDate.weekday - 1));

    final weekStartMs = weekStart.millisecondsSinceEpoch;

    final isCurrentWeek = (student?.weeklyStatsStartedAtMs ?? 0) >= weekStartMs;

    final baseWeekly = isCurrentWeek ? (student?.weeklyProgress ?? 0.0) : 0.0;
    final baseTime = isCurrentWeek ? (student?.timeSpentMinThisWeek ?? 0) : 0;
    final baseVoice = isCurrentWeek ? (student?.voiceUsagePct ?? 0) : 0;

    final newWeekly = (baseWeekly + 0.05).clamp(0.0, 1.0);
    final newTime = baseTime + 7;
    final newVoice = (baseVoice + 2).clamp(0, 100);

    final newEngagement = newTime >= 35 || newWeekly >= 0.50
        ? 'High'
        : newTime >= 14 || newWeekly >= 0.20
            ? 'Moderate'
            : 'Building';

    await db.doc('students/${widget.studentId}').update({
      'readingLevel': newLevel,
      'weeklyProgress': newWeekly,
      'timeSpentMinThisWeek': newTime,
      'voiceUsagePct': newVoice,
      'engagement': newEngagement,
      'weeklyStatsStartedAtMs': weekStartMs,
      'preferredMode': 'Voice',
      'skillTrends.${_goalSkillName(_activeGoal)}':
          _trendFromAccuracy(accuracy),
      'updatedAtMs': now,
    });

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CelebrationScreen(
          improvements: improvements,
          levelDelta: levelDelta,
        ),
      ),
    );

    // Reload items for next time
    await Future.delayed(300.ms);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(studentDocProvider(widget.studentId));
    final latestGoal = studentAsync.asData?.value?.todayGoal;

    if (!_loading &&
        latestGoal != null &&
        latestGoal.isNotEmpty &&
        latestGoal != _activeGoal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _load();
        }
      });
    }

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_items.isEmpty) {
      return const Center(
        child: Text('No practice items are available for this goal.'),
      );
    }

    final item = _items[_idx];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Practice',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            _activeGoal,
            style: const TextStyle(
              color: AppColors.indigo,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Practice for today' 's goal',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: AppColors.indigo),
                    SizedBox(width: 10),
                    Text(
                        _activeGoal.toLowerCase().contains('spell')
                            ? 'Choose the correctly spelled word:'
                            : 'Read this sentence:',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: AppColors.indigo.withOpacity(0.08),
                  ),
                  child: Text('"${item.sentence}"',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 14),
                Text(item.question,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _AnswerGrid(
                  onPick: _answer,
                  ideal: item.ideal,
                  goal: _activeGoal,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, end: 0),
          const SizedBox(height: 10),
          Text('Question ${_idx + 1} of ${_items.length}',
              style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  String _goalSkillName(String goal) {
    final g = goal.toLowerCase();

    if (g.contains('spell')) return 'Spelling';

    if (g.contains('vocabulary') || g.contains('context clue')) {
      return 'Vocabulary';
    }

    if (g.contains('main idea')) return 'Main Idea';

    if (g.contains('inference') || g.contains('infer')) {
      return 'Inference';
    }

    return 'Comprehension';
  }

  String _trendFromAccuracy(int accuracy) {
    if (accuracy >= 95) return 'Strong';
    if (accuracy >= 80) return 'Improving';
    return 'Needs work';
  }

  bool _softMatch(String choice, String ideal) {
    final cleanChoice = choice.trim().toLowerCase();
    final cleanIdeal = ideal.trim().toLowerCase();

    if (!cleanIdeal.contains(' ')) {
      return cleanChoice == cleanIdeal;
    }

    final words =
        cleanChoice.split(RegExp(r'\W+')).where((w) => w.length >= 4).toSet();
    final idealWords =
        cleanIdeal.split(RegExp(r'\W+')).where((w) => w.length >= 4).toSet();
    final overlap = words.intersection(idealWords).length;

    return overlap >= 2 ||
        (cleanChoice.length > 10 && cleanIdeal.contains(cleanChoice));
  }

  String _hint(String ideal) {
    final parts = ideal.split('.');
    final h = parts.first.trim();
    return h.length > 70 ? '${h.substring(0, 70)}...' : h;
  }
}

class _AnswerGrid extends StatelessWidget {
  const _AnswerGrid({
    required this.onPick,
    required this.ideal,
    required this.goal,
  });

  final Future<void> Function(String) onPick;
  final String ideal;
  final String goal;

  @override
  Widget build(BuildContext context) {
    final normalizedGoal = goal.toLowerCase();

    final choices =
        normalizedGoal.contains('spelling') || normalizedGoal.contains('spell')
            ? _spellingChoices(ideal)
            : <String>[
                ideal,
                'Something about a person doing an action.',
                'Something about an object or place.',
                'It describes what happened in the sentence.',
              ];

    return Column(
      children: [
        for (final c in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppButton(
              label: c,
              icon: Icons.check_circle_outline,
              isPrimary: false,
              onPressed: () => onPick(c),
            ),
          ),
      ],
    );
  }

  List<String> _spellingChoices(String answer) {
    final word = answer.trim().toLowerCase();

    const choices = <String, List<String>>{
      'beautiful': [
        'beautiful',
        'beautifull',
        'beutiful',
        'beautifal',
      ],
      'because': [
        'because',
        'becuase',
        'beacuse',
        'becouse',
      ],
      'different': [
        'different',
        'diffrent',
        'diferent',
        'differant',
      ],
      'favorite': [
        'favorite',
        'faverite',
        'favorit',
        'favrite',
      ],
      'remember': [
        'remember',
        'remeber',
        'remmember',
        'remebmer',
      ],
      'necessary': [
        'necessary',
        'neccessary',
        'necessery',
        'nesessary',
      ],
      'separate': [
        'separate',
        'seperate',
        'seperete',
        'separete',
      ],
      'environment': [
        'environment',
        'enviroment',
        'envirnment',
        'environmentt',
      ],
      'beginning': [
        'beginning',
        'begining',
        'beggining',
        'beginnning',
      ],
      'knowledge': [
        'knowledge',
        'knowlege',
        'knowledje',
        'knowladge',
      ],
    };

    return choices[word] ??
        <String>[
          word,
          '${word}e',
          '${word}s',
          '${word}t',
        ];
  }
}
