import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/player.dart';
import '../models/session.dart';
import '../models/round.dart';

class DatabaseService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'doudizhu.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE players (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            created_at INTEGER NOT NULL,
            player_ids TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE rounds (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            round_index INTEGER NOT NULL,
            landlord_id TEXT NOT NULL,
            farmer_ids TEXT NOT NULL,
            is_landlord_win INTEGER NOT NULL,
            spring INTEGER NOT NULL,
            blind INTEGER NOT NULL,
            kick_count INTEGER NOT NULL,
            kick_farmer_id TEXT,
            bomb_count INTEGER NOT NULL,
            scores TEXT NOT NULL
          )
        ''');
        for (final p in defaultPlayers) {
          await db.insert('players', p.toMap());
        }
      },
    );
  }

  Future<List<Player>> getPlayers() async {
    final db = await database;
    final maps = await db.query('players');
    return maps.map((m) => Player.fromMap(m)).toList();
  }

  Future<void> updatePlayer(Player player) async {
    final db = await database;
    await db.update(
      'players',
      player.toMap(),
      where: 'id = ?',
      whereArgs: [player.id],
    );
  }

  Future<Session> createSession(Session session) async {
    final db = await database;
    await db.insert('sessions', session.toMap());
    return session;
  }

  Future<List<Session>> getAllSessions() async {
    final db = await database;
    final maps = await db.query('sessions', orderBy: 'created_at DESC');
    return maps.map((m) => Session.fromMap(m)).toList();
  }

  Future<Session?> getLatestSession() async {
    final db = await database;
    final maps = await db.query('sessions', orderBy: 'created_at DESC', limit: 1);
    if (maps.isEmpty) return null;
    return Session.fromMap(maps.first);
  }

  Future<GameRound> createRound(GameRound round) async {
    final db = await database;
    await db.insert('rounds', round.toMap());
    return round;
  }

  Future<List<GameRound>> getRoundsForSession(String sessionId) async {
    final db = await database;
    final maps = await db.query(
      'rounds',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'round_index ASC',
    );
    return maps.map((m) => GameRound.fromMap(m)).toList();
  }
}
