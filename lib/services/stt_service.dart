import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text service wrapping the speech_to_text package.
/// Call init() once (in initState).
/// listenOnce() starts listening and returns the recognised string (or null).
class SttService {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;

  Future<void> init() async {
    _available = await _stt.initialize(
      onError: (e) => print('STT error: $e'),
    );
  }

  bool get isAvailable => _available;
  bool get isListening => _stt.isListening;

  /// Listens for up to [listenFor] seconds and returns the transcribed text.
  /// Returns null if unavailable or nothing was heard.
  Future<String?> listenOnce({
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 2),
  }) async {
    if (!_available) return null;

    String result = '';

    await _stt.listen(
      onResult: (r) => result = r.recognizedWords,
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: false,
      localeId: 'en_US',
    );

    // Wait until listening stops
    while (_stt.isListening) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return result.trim().isEmpty ? null : result.trim();
  }

  Future<void> stop() async {
    if (_stt.isListening) await _stt.stop();
  }

  Future<void> dispose() async {
    await stop();
  }
}
