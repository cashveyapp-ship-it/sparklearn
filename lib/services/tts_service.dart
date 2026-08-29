import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech service wrapping flutter_tts.
/// Call init() once (in initState), speak() to read text aloud,
/// stop() to interrupt, dispose() on widget dispose.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45); // gentle, slightly slow for learners
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);
    _ready = true;
  }

  Future<void> speak(String text) async {
    if (!_ready || text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
