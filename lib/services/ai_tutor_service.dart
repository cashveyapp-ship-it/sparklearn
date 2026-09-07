import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../providers/firebase_providers.dart';

// ------------------------------------------------------------
// Replace with your real OpenAI API key.
//    For production, load this from a Cloud Function or secure backend so the
//    key is never shipped inside the app binary.
// ------------------------------------------------------------
final String _kOpenAiApiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
const String _kModel =
    'gpt-4o-mini'; // fast + affordable; swap to gpt-4o for higher quality

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

    // 3. Call OpenAI

    if (_kOpenAiApiKey.isEmpty) {
      throw StateError(
          'Missing OPENAI_API_KEY. Run with: flutter run --dart-define=OPENAI_API_KEY=YOUR_KEY');
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_kOpenAiApiKey',
      },
      body: jsonEncode({
        'model': _kModel,
        'messages': messages,
        'max_tokens': 200,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode != 200) {
      // Save a graceful error message rather than crashing
      await col.add({
        'role': 'assistant',
        'text':
            'I had a little trouble thinking just now - could you ask me again?',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      return;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final reply =
        (body['choices'] as List).first['message']['content'] as String;

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
