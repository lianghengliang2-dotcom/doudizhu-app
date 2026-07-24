import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/database_service.dart';

class PlayerProvider extends ChangeNotifier {
  final DatabaseService _db;
  List<Player> _players = [];

  PlayerProvider(this._db);

  List<Player> get players => _players;

  Future<void> loadPlayers() async {
    _players = await _db.getPlayers();
    notifyListeners();
  }

  Future<void> updatePlayerName(String playerId, String newName) async {
    final player = _players.firstWhere((p) => p.id == playerId);
    final updated = player.copyWith(name: newName);
    await _db.updatePlayer(updated);
    final idx = _players.indexWhere((p) => p.id == playerId);
    _players[idx] = updated;
    notifyListeners();
  }
}
