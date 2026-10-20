import 'package:flutter/material.dart';
import '../services/database_service.dart';

class VoiceSettingsProvider extends ChangeNotifier {
  static const _voiceKey = 'voice_enabled';
  final DatabaseService _db;
  bool _voiceEnabled = true;

  VoiceSettingsProvider(this._db);

  bool get voiceEnabled => _voiceEnabled;

  Future<void> load() async {
    final value = await _db.getSetting(_voiceKey);
    _voiceEnabled = value != 'false';
    notifyListeners();
  }

  Future<void> setVoiceEnabled(bool enabled) async {
    _voiceEnabled = enabled;
    notifyListeners();
    await _db.setSetting(_voiceKey, enabled.toString());
  }
}
