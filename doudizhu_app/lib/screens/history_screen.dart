import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/game_provider.dart';
import '../providers/player_provider.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GameProvider>().loadAllSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史场次')),
      body: Consumer2<GameProvider, PlayerProvider>(
        builder: (context, game, players, _) {
          if (game.allSessions.isEmpty) {
            return const Center(
              child: Text('暂无历史场次', style: TextStyle(color: Color(0xFF8B7355))),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: game.allSessions.length,
            itemBuilder: (context, index) {
              final session = game.allSessions[index];
              final date = DateFormat('yyyy-MM-dd HH:mm').format(session.createdAt);
              final playerNames = session.playerIds.map((id) {
                final p = players.players.where((p) => p.id == id).firstOrNull;
                return p?.name ?? '?';
              }).join('  ');

              return GestureDetector(
                onTap: () {
                  game.loadSessionDetail(session.id);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SessionDetailScreen()),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(date, style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(playerNames, style: const TextStyle(color: Color(0xFF8B7355), fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF8B6914)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
