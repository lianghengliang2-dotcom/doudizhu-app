import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/game_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/round_record_tile.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('场次详情')),
      body: Consumer2<GameProvider, PlayerProvider>(
        builder: (context, game, players, _) {
          final session = game.currentSession;
          if (session == null) {
            return const Center(child: Text('场次不存在', style: TextStyle(color: Color(0xFF888888))));
          }

          final date = DateFormat('yyyy-MM-dd HH:mm').format(session.createdAt);
          final playerNames = {for (var p in players.players) p.id: p.name};
          final scores = game.totalScores;

          return Column(
            children: [
              // Gold header area
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1C1410), Color(0xFF0A0A0A)],
                  ),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF8B6914), width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    Text(date, style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: session.playerIds.map((id) {
                        final name = playerNames[id] ?? '?';
                        final score = scores[id] ?? 0;
                        return Column(
                          children: [
                            Text(name, style: const TextStyle(color: Color(0xFFF5E6C8), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '${score >= 0 ? '+' : ''}$score',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: score >= 0 ? const Color(0xFFFF6B35) : const Color(0xFF4CAF50),
                                height: 1,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: game.currentRounds.length,
                  itemBuilder: (context, index) {
                    return RoundRecordTile(
                      round: game.currentRounds[index],
                      playerNames: playerNames,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
