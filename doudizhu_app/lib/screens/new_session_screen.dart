import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/game_provider.dart';

class NewSessionScreen extends StatefulWidget {
  const NewSessionScreen({super.key});

  @override
  State<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends State<NewSessionScreen> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建场次')),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '选择 3 位上场玩家（已选 ${_selected.length}/3）',
                  style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: provider.players.length,
                  itemBuilder: (context, index) {
                    final player = provider.players[index];
                    final isSelected = _selected.contains(player.id);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(player.id);
                          } else if (_selected.length < 3) {
                            _selected.add(player.id);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: isSelected ? LinearGradient(
                            colors: [const Color(0xFFC41E1E).withOpacity(0.2), const Color(0xFFE53935).withOpacity(0.1)],
                          ) : const LinearGradient(
                            colors: [Color(0xFF1C1410), Color(0xFF2A1F18)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFC4952A) : const Color(0xFF8B6914),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _parseColor(player.color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFC4952A) : const Color(0xFF8B6914),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                player.name.characters.first,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(player.name, style: const TextStyle(color: Color(0xFFF5E6C8), fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              color: isSelected ? const Color(0xFFC4952A) : const Color(0xFF8B7355),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected.length == 3 ? _startSession : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC41E1E),
                      foregroundColor: const Color(0xFFF5E6C8),
                    ),
                    child: const Text('开始'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _startSession() async {
    final gameProvider = context.read<GameProvider>();
    await gameProvider.createNewSession(_selected.toList());
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Color _parseColor(String hex) {
    final code = hex.replaceFirst('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}
