import 'dart:convert';

class Session {
  final String id;
  final DateTime createdAt;
  final List<String> playerIds;

  const Session({
    required this.id,
    required this.createdAt,
    required this.playerIds,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'created_at': createdAt.millisecondsSinceEpoch,
    'player_ids': jsonEncode(playerIds),
  };

  factory Session.fromMap(Map<String, dynamic> map) => Session(
    id: map['id'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    playerIds: List<String>.from(jsonDecode(map['player_ids'] as String)),
  );
}
