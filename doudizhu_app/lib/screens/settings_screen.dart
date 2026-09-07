import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/voice_settings_provider.dart';
import '../services/tts_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer2<PlayerProvider, VoiceSettingsProvider>(
        builder: (context, provider, voice, _) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1C1410),
                      Color(0xFF2A1F18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8B6914), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.volume_up, color: Color(0xFFC4952A)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('语音播报', style: TextStyle(color: Color(0xFFF5E6C8), fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline, color: Color(0xFFFFD54F)),
                      tooltip: '试听',
                      onPressed: () => context.read<TtsService>().speak('斗地主记分，语音播报试听'),
                    ),
                    Switch(
                      value: voice.voiceEnabled,
                      onChanged: (v) => voice.setVoiceEnabled(v),
                    ),
                  ],
                ),
              ),
              ...provider.players.map((player) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1C1410),
                        Color(0xFF2A1F18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8B6914), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF8B6914), Color(0xFFC4952A)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parseColor(player.color),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFC4952A), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          player.name.characters.first,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: player.name,
                          style: const TextStyle(color: Color(0xFFF5E6C8)),
                          decoration: const InputDecoration(
                            border: UnderlineInputBorder(),
                            labelText: '名字',
                            labelStyle: TextStyle(color: Color(0xFF8B7355)),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF8B6914)),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFC4952A), width: 2),
                            ),
                          ),
                          onFieldSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              provider.updatePlayerName(player.id, value.trim());
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Color _parseColor(String hex) {
    final code = hex.replaceFirst('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}
