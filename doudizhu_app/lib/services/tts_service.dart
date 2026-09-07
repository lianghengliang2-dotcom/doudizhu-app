import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.59);
      await _tts.setVolume(1.0);
      _initialized = true;
    } catch (_) {
      // 引擎不可用时静默跳过，不抛出
    }
  }

  Future<void> speak(String text) async {
    await _ensureInitialized();
    if (!_initialized) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // 朗读失败静默忽略，不打断记分
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
