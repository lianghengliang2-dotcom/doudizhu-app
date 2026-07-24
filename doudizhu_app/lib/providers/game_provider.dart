import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../models/round.dart';
import '../services/database_service.dart';
import '../utils/score_calculator.dart';

class GameProvider extends ChangeNotifier {
  final DatabaseService _db;
  final _uuid = const Uuid();

  Session? _currentSession;
  List<GameRound> _currentRounds = [];
  List<Session> _allSessions = [];

  GameProvider(this._db);

  Session? get currentSession => _currentSession;
  List<GameRound> get currentRounds => _currentRounds;
  List<Session> get allSessions => _allSessions;

  List<GameRound> get recentRounds {
    if (_currentRounds.length <= 3) return _currentRounds;
    return _currentRounds.sublist(_currentRounds.length - 3);
  }

  Map<String, int> get totalScores {
    final scores = <String, int>{};
    for (final round in _currentRounds) {
      for (final entry in round.scores.entries) {
        scores[entry.key] = (scores[entry.key] ?? 0) + entry.value;
      }
    }
    return scores;
  }

  Future<void> loadLatestSession() async {
    _currentSession = await _db.getLatestSession();
    if (_currentSession != null) {
      _currentRounds = await _db.getRoundsForSession(_currentSession!.id);
    }
    notifyListeners();
  }

  Future<void> loadAllSessions() async {
    _allSessions = await _db.getAllSessions();
    notifyListeners();
  }

  Future<void> createNewSession(List<String> playerIds) async {
    final session = Session(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      playerIds: playerIds,
    );
    await _db.createSession(session);
    _currentSession = session;
    _currentRounds = [];
    notifyListeners();
  }

  Future<void> addRound({
    required String landlordId,
    required List<String> farmerIds,
    required bool isLandlordWin,
    required bool spring,
    required bool blind,
    required int kickCount,
    required String? kickFarmerId,
    required int bombCount,
  }) async {
    if (_currentSession == null) return;

    final result = calculateRoundScores(
      isLandlordWin: isLandlordWin,
      spring: spring,
      blind: blind,
      kickCount: kickCount,
      bombCount: bombCount,
    );

    final scores = <String, int>{};
    final String farmerA;
    final String farmerB;

    if (kickCount > 0 && kickFarmerId != null) {
      farmerA = kickFarmerId;
      farmerB = farmerIds.firstWhere((id) => id != kickFarmerId);
    } else {
      farmerA = farmerIds[0];
      farmerB = farmerIds[1];
    }

    scores[landlordId] = result.landlordScore;
    scores[farmerA] = result.farmerAScore;
    scores[farmerB] = result.farmerBScore;

    final round = GameRound(
      id: _uuid.v4(),
      sessionId: _currentSession!.id,
      roundIndex: _currentRounds.length + 1,
      landlordId: landlordId,
      farmerIds: farmerIds,
      isLandlordWin: isLandlordWin,
      spring: spring,
      blind: blind,
      kickCount: kickCount,
      kickFarmerId: kickFarmerId,
      bombCount: bombCount,
      scores: scores,
    );

    await _db.createRound(round);
    _currentRounds.add(round);
    notifyListeners();
  }

  Future<void> loadSessionDetail(String sessionId) async {
    final sessions = await _db.getAllSessions();
    _currentSession = sessions.firstWhere((s) => s.id == sessionId);
    _currentRounds = await _db.getRoundsForSession(sessionId);
    notifyListeners();
  }
}
