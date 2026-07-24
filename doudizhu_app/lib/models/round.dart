import 'dart:convert';

class GameRound {
  final String id;
  final String sessionId;
  final int roundIndex;
  final String landlordId;
  final List<String> farmerIds;
  final bool isLandlordWin;
  final bool spring;
  final bool blind;
  final int kickCount;
  final String? kickFarmerId;
  final int bombCount;
  final Map<String, int> scores;

  const GameRound({
    required this.id,
    required this.sessionId,
    required this.roundIndex,
    required this.landlordId,
    required this.farmerIds,
    required this.isLandlordWin,
    required this.spring,
    required this.blind,
    required this.kickCount,
    this.kickFarmerId,
    required this.bombCount,
    required this.scores,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'round_index': roundIndex,
    'landlord_id': landlordId,
    'farmer_ids': jsonEncode(farmerIds),
    'is_landlord_win': isLandlordWin ? 1 : 0,
    'spring': spring ? 1 : 0,
    'blind': blind ? 1 : 0,
    'kick_count': kickCount,
    'kick_farmer_id': kickFarmerId,
    'bomb_count': bombCount,
    'scores': jsonEncode(scores),
  };

  factory GameRound.fromMap(Map<String, dynamic> map) => GameRound(
    id: map['id'] as String,
    sessionId: map['session_id'] as String,
    roundIndex: map['round_index'] as int,
    landlordId: map['landlord_id'] as String,
    farmerIds: List<String>.from(jsonDecode(map['farmer_ids'] as String)),
    isLandlordWin: (map['is_landlord_win'] as int) == 1,
    spring: (map['spring'] as int) == 1,
    blind: (map['blind'] as int) == 1,
    kickCount: map['kick_count'] as int,
    kickFarmerId: map['kick_farmer_id'] as String?,
    bombCount: map['bomb_count'] as int,
    scores: Map<String, int>.from(jsonDecode(map['scores'] as String)),
  );
}
