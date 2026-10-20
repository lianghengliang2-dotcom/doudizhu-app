import '../models/round.dart';

String buildRoundAnnouncement({
  required GameRound round,
  required Map<String, String> playerNames,
  required Map<String, int> totalScores,
  required List<String> playerOrder,
}) {
  final name = (String id) => playerNames[id] ?? '玩家';

  final buffer = StringBuffer()
    ..write('第${round.roundIndex}局，地主${name(round.landlordId)}')
    ..write(_roundResult(round.scores[round.landlordId] ?? 0));

  for (final farmerId in round.farmerIds) {
    buffer
      ..write('，${name(farmerId)}')
      ..write(_roundResult(round.scores[farmerId] ?? 0));
  }

  buffer.write('。总分：');
  buffer.write(
    playerOrder.map((id) => '${name(id)}${_totalResult(totalScores[id] ?? 0)}').join('，'),
  );
  buffer.write('。');

  return buffer.toString();
}

String _roundResult(int score) {
  if (score > 0) return '赢$score分';
  if (score < 0) return '输${-score}分';
  return '平0分';
}

String _totalResult(int score) {
  if (score > 0) return '正$score';
  if (score < 0) return '负${-score}';
  return '零';
}
