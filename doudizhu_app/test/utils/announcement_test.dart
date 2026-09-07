import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu_app/models/round.dart';
import 'package:doudizhu_app/utils/announcement.dart';

void main() {
  const playerNames = {
    'p1': '吕布',
    'p2': '赵云',
    'p3': '司马懿',
  };
  const playerOrder = ['p1', 'p2', 'p3'];

  GameRound buildRound({
    int roundIndex = 3,
    String landlordId = 'p1',
    List<String> farmerIds = const ['p2', 'p3'],
    Map<String, int> scores = const {'p1': 40, 'p2': -20, 'p3': -20},
  }) {
    return GameRound(
      id: 'r1',
      sessionId: 's1',
      roundIndex: roundIndex,
      landlordId: landlordId,
      farmerIds: farmerIds,
      isLandlordWin: true,
      spring: false,
      blind: false,
      kickCount: 0,
      kickFarmerId: null,
      bombCount: 0,
      scores: scores,
    );
  }

  test('地主赢：播报角色、本局得分与累计总分', () {
    final text = buildRoundAnnouncement(
      round: buildRound(),
      playerNames: playerNames,
      totalScores: const {'p1': 60, 'p2': -30, 'p3': -30},
      playerOrder: playerOrder,
    );
    expect(text, '第3局，地主吕布赢40分，赵云输20分，司马懿输20分。总分：吕布正60，赵云负30，司马懿负30。');
  });

  test('地主输：农民读作赢', () {
    final text = buildRoundAnnouncement(
      round: buildRound(
        roundIndex: 2,
        scores: const {'p1': -20, 'p2': 10, 'p3': 10},
      ),
      playerNames: playerNames,
      totalScores: const {'p1': -20, 'p2': 10, 'p3': 10},
      playerOrder: playerOrder,
    );
    expect(text, '第2局，地主吕布输20分，赵云赢10分，司马懿赢10分。总分：吕布负20，赵云正10，司马懿正10。');
  });

  test('累计总分按场上玩家顺序读取', () {
    final text = buildRoundAnnouncement(
      round: buildRound(),
      playerNames: playerNames,
      totalScores: const {'p2': -30, 'p1': 60, 'p3': -30},
      playerOrder: const ['p3', 'p1', 'p2'],
    );
    expect(text, '第3局，地主吕布赢40分，赵云输20分，司马懿输20分。总分：司马懿负30，吕布正60，赵云负30。');
  });

  test('累计总分存在 0 时读作零', () {
    final text = buildRoundAnnouncement(
      round: buildRound(),
      playerNames: playerNames,
      totalScores: const {'p1': 0, 'p2': -10, 'p3': 10},
      playerOrder: playerOrder,
    );
    expect(text, '第3局，地主吕布赢40分，赵云输20分，司马懿输20分。总分：吕布零，赵云负10，司马懿正10。');
  });

  test('缺失玩家名回退为"玩家"', () {
    final text = buildRoundAnnouncement(
      round: buildRound(),
      playerNames: const {'p1': '吕布'},
      totalScores: const {'p1': 60, 'p2': -30, 'p3': -30},
      playerOrder: playerOrder,
    );
    expect(text, '第3局，地主吕布赢40分，玩家输20分，玩家输20分。总分：吕布正60，玩家负30，玩家负30。');
  });
}
