import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/firebase_providers.dart';

final aiTutorServiceProvider = Provider<AiTutorService>((ref) {
  return AiTutorService(db: ref.watch(firestoreProvider));
});

class AiTutorService {
  AiTutorService({required this.db});
  final FirebaseFirestore db;

  // System prompt
  String _systemPrompt({
    required double readingLevel,
    required int lastAccuracyPct,
    required String inputMode,
  }) =>
      '''You are SparkLearn's AI Tutor - a warm, patient, encouraging reading coach for students.

Student profile:
- Current reading level: grade $readingLevel
- Last session accuracy: $lastAccuracyPct%
- Input mode: $inputMode

Your rules:
1. Keep ALL responses SHORT - maximum 3 sentences. Students read on a small screen.
2. Use simple, clear vocabulary appropriate for grade $readingLevel.
3. Always be positive and encouraging. Never say "wrong" or "incorrect".
4. If the student asks a question, answer it directly then ask ONE follow-up question.
5. If the student seems confused, gently rephrase and give a hint.
6. Focus only on reading, vocabulary, comprehension, and writing skills.
7. End every response with a question or a gentle next step to keep them engaged.''';

  // Build context called from UI
  String buildContext({
    required double readingLevel,
    required int lastAccuracyPct,
    required String inputMode,
  }) =>
      _systemPrompt(
          readingLevel: readingLevel,
          lastAccuracyPct: lastAccuracyPct,
          inputMode: inputMode);

  // Send message
  /// Saves the user message to Firestore, calls OpenAI, saves the response.
  Future<void> sendMessage({
    required String studentId,
    required String text,
    required String context, // system prompt string from buildContext()
  }) async {
    final col =
        db.collection('students').doc(studentId).collection('tutor_messages');

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Save user message immediately so UI updates
    await col.add({
      'role': 'user',
      'text': text,
      'createdAt': now,
    });

    // 2. Load recent history (last 10 messages) for context
    final history =
        await col.orderBy('createdAt', descending: true).limit(10).get();

    final messages = [
      {'role': 'system', 'content': context},
      // Reverse so oldest first
      ...history.docs.reversed.map((d) => {
            'role': d['role'] as String,
            'content': d['text'] as String,
          }),
    ];
    // 3. Call the secure SparkLearn AI Tutor backend.
    final functions = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    );

    final callable = functions.httpsCallable(
      'aiTutorReply',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 60),
      ),
    );

    final result = await callable.call<Map<String, dynamic>>({
      'messages': messages,
    });

    final data = result.data;
    final rawReply = data['reply'];

    if (data['ok'] != true || rawReply is! String || rawReply.trim().isEmpty) {
      throw StateError('AI Tutor returned an empty response.');
    }

    final reply = rawReply.trim();

    // 4. Save assistant response
    await col.add({
      'role': 'assistant',
      'text': reply.trim(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Message stream for UI
  Stream<QuerySnapshot<Map<String, dynamic>>> messageStream(String studentId) {
    return db
        .collection('students')
        .doc(studentId)
        .collection('tutor_messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // Clear chat history
  Future<void> clearHistory(String studentId) async {
    final col =
        db.collection('students').doc(studentId).collection('tutor_messages');
    final docs = await col.get();
    final batch = db.batch();
    for (final d in docs.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }
}
