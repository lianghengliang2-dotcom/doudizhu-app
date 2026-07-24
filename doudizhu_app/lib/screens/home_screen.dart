import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/game_provider.dart';
import '../widgets/player_score_card.dart';
import '../widgets/round_record_tile.dart';
import '../widgets/score_input_panel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('斗地主记分'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).pushNamed('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Consumer2<GameProvider, PlayerProvider>(
        builder: (context, game, players, _) {
          if (game.currentSession == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('开战', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFD54F))),
                  const SizedBox(height: 8),
                  const Text('选择三位玩家开始记分', style: TextStyle(color: Color(0xFF8B7355))),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushNamed('/new-session'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC41E1E),
                      foregroundColor: const Color(0xFFF5E6C8),
                    ),
                    child: const Text('新建场次'),
                  ),
                ],
              ),
            );
          }

          final sessionPlayerIds = game.currentSession!.playerIds;
          final sessionPlayers = players.players
              .where((p) => sessionPlayerIds.contains(p.id))
              .toList();
          final playerNames = {for (var p in players.players) p.id: p.name};
          final scores = game.totalScores;
          final recent = game.recentRounds;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 总分区域
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    children: sessionPlayers.map((p) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: PlayerScoreCard(
                            name: p.name,
                            colorHex: p.color,
                            score: scores[p.id] ?? 0,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // 新建场次
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pushNamed('/new-session'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF5E6C8),
                        side: const BorderSide(color: Color(0xFF8B6914)),
                      ),
                      child: const Text('新建场次'),
                    ),
                  ),
                ),

                // Decorative divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0xFF8B6914), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 最近记录
                if (recent.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B6914), Color(0xFFC4952A)],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '最近 ${recent.length} 局',
                          style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...recent.reversed.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: RoundRecordTile(round: r, playerNames: playerNames),
                  )),
                  // Decorative divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      height: 1,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Color(0xFF8B6914), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],

                // 录入面板
                ScoreInputPanel(
                  sessionPlayers: sessionPlayers,
                  onSubmit: ({
                    required landlordId,
                    required farmerIds,
                    required isLandlordWin,
                    required spring,
                    required blind,
                    required kickCount,
                    required kickFarmerId,
                    required bombCount,
                  }) {
                    game.addRound(
                      landlordId: landlordId,
                      farmerIds: farmerIds,
                      isLandlordWin: isLandlordWin,
                      spring: spring,
                      blind: blind,
                      kickCount: kickCount,
                      kickFarmerId: kickFarmerId,
                      bombCount: bombCount,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
