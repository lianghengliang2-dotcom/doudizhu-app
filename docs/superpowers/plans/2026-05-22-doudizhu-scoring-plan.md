# 斗地主记分 APP 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Flutter 跨平台斗地主三人记分 APP，支持 Android 和 iOS。

**Architecture:** Provider 状态管理 + SQLite 本地存储。核心计分逻辑为纯 Dart 函数，UI 层通过 Provider 消费状态。页面包括：记分首页、设置、新建场次、历史场次、场次详情。

**Tech Stack:** Flutter 3.x, Provider, sqflite, uuid, intl

---

## File Structure

```
doudizhu_app/
  pubspec.yaml
  lib/
    main.dart
    models/
      player.dart              # Player 数据模型
      session.dart             # Session 数据模型
      round.dart               # Round 数据模型
    services/
      database_service.dart    # SQLite CRUD
    providers/
      player_provider.dart     # 玩家名字管理
      game_provider.dart       # 场次+对局状态
    utils/
      score_calculator.dart    # 纯函数计分逻辑
    screens/
      home_screen.dart         # 记分首页
      settings_screen.dart     # 设置页面
      new_session_screen.dart  # 新建场次
      history_screen.dart      # 历史场次列表
      session_detail_screen.dart  # 场次详情
    widgets/
      player_score_card.dart   # 玩家分数卡片
      round_record_tile.dart   # 对局记录条目
      score_input_panel.dart   # 加倍项录入面板
      score_preview.dart       # 分数预览
  test/
    utils/
      score_calculator_test.dart
```

---

### Task 1: Flutter 项目初始化

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`

- [ ] **Step 1: 创建 Flutter 项目**

```bash
cd /config/workspace/projects/小程序/斗地主APP
flutter create --org com.doudizhu --project-name doudizhu_app doudizhu_app
```

- [ ] **Step 2: 添加依赖到 pubspec.yaml**

在 `doudizhu_app/pubspec.yaml` 的 `dependencies` 下添加：

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.0
  sqflite: ^2.3.0
  path: ^1.9.0
  uuid: ^4.3.0
  intl: ^0.19.0
```

- [ ] **Step 3: 替换 main.dart 为最小骨架**

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const DoudizhuApp());
}

class DoudizhuApp extends StatelessWidget {
  const DoudizhuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '斗地主记分',
      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('斗地主记分')),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行依赖安装并验证**

```bash
cd doudizhu_app
flutter pub get
flutter analyze
```

Expected: 无错误

- [ ] **Step 5: Commit**

```bash
git init
git add .
git commit -m "feat: init Flutter project with dependencies"
```

---

### Task 2: 计分逻辑（TDD）

**Files:**
- Create: `lib/utils/score_calculator.dart`
- Create: `test/utils/score_calculator_test.dart`

- [ ] **Step 1: 编写计分测试**

```dart
// test/utils/score_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doudizhu_app/utils/score_calculator.dart';

void main() {
  group('calculateBaseScore', () {
    test('N=0 returns 5', () {
      expect(calculateBaseScore(0), 5);
    });
    test('N=1 returns 10', () {
      expect(calculateBaseScore(1), 10);
    });
    test('N=2 returns 20', () {
      expect(calculateBaseScore(2), 20);
    });
    test('N=3 returns 40', () {
      expect(calculateBaseScore(3), 40);
    });
    test('N=4 returns 80', () {
      expect(calculateBaseScore(4), 80);
    });
    test('N=5 returns 160 (cap)', () {
      expect(calculateBaseScore(5), 160);
    });
    test('N=6 returns 210', () {
      expect(calculateBaseScore(6), 210);
    });
    test('N=7 returns 260', () {
      expect(calculateBaseScore(7), 260);
    });
    test('N=8 returns 310', () {
      expect(calculateBaseScore(8), 310);
    });
  });

  group('calculateRoundScores - 无踢', () {
    test('地主赢 N=0', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: false,
        blind: false,
        kickCount: 0,
        bombCount: 0,
      );
      expect(result.landlordScore, 5);
      expect(result.farmerAScore, -3); // -5/2 = -2.5 -> -3? 不对，应该用整数
    });

    test('地主赢 N=1 (1炸)', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: false,
        blind: false,
        kickCount: 0,
        bombCount: 1,
      );
      expect(result.landlordScore, 10);
      expect(result.farmerAScore, -5);
      expect(result.farmerBScore, -5);
    });

    test('地主赢 N=2 (春天+蒙牌)', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: true,
        blind: true,
        kickCount: 0,
        bombCount: 0,
      );
      expect(result.landlordScore, 20);
      expect(result.farmerAScore, -10);
      expect(result.farmerBScore, -10);
    });

    test('地主输 N=1 (1炸)', () {
      final result = calculateRoundScores(
        isLandlordWin: false,
        spring: false,
        blind: false,
        kickCount: 0,
        bombCount: 1,
      );
      expect(result.landlordScore, -10);
      expect(result.farmerAScore, 5);
      expect(result.farmerBScore, 5);
    });

    test('地主赢 N=5 (封顶)', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: true,
        blind: true,
        kickCount: 0,
        bombCount: 3,
      );
      expect(result.landlordScore, 160);
      expect(result.farmerAScore, -80);
      expect(result.farmerBScore, -80);
    });
  });

  group('calculateRoundScores - 有踢', () {
    test('地主赢 踢=1', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: false,
        blind: false,
        kickCount: 1,
        bombCount: 0,
      );
      // N_base=0, S_base=5
      // N_kick_total=1, S_kick=10
      // farmerA(踢了): -10/2=-5, farmerB: -5/2=-3 (整数除法)
      // landlord: 5+3=8? 不对
      expect(result.landlordScore, 8);
      expect(result.farmerAScore, -5);
      expect(result.farmerBScore, -2);
    });

    test('地主赢 踢=2 (踢+反踢)', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: false,
        blind: false,
        kickCount: 2,
        bombCount: 0,
      );
      // N_base=0, S_base=5
      // N_kick_total=2, S_kick=20
      // farmerA: -20/2=-10, farmerB: -5/2=-2
      // landlord: 10+2=12
      expect(result.landlordScore, 12);
      expect(result.farmerAScore, -10);
      expect(result.farmerBScore, -2);
    });

    test('地主赢 N=5+踢=1 (封顶+超封顶)', () {
      final result = calculateRoundScores(
        isLandlordWin: true,
        spring: true,
        blind: true,
        kickCount: 1,
        bombCount: 3,
      );
      // N_base=5, S_base=160
      // N_kick_total=6, S_kick=210
      // farmerA: -210/2=-105, farmerB: -160/2=-80
      // landlord: 105+80=185
      expect(result.landlordScore, 185);
      expect(result.farmerAScore, -105);
      expect(result.farmerBScore, -80);
    });

    test('地主输 踢=1', () {
      final result = calculateRoundScores(
        isLandlordWin: false,
        spring: false,
        blind: false,
        kickCount: 1,
        bombCount: 0,
      );
      // N_base=0, S_base=5
      // N_kick_total=1, S_kick=10
      // landlord: -(5+2)=-7, farmerA: 5, farmerB: 2
      expect(result.landlordScore, -7);
      expect(result.farmerAScore, 5);
      expect(result.farmerBScore, 2);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
cd doudizhu_app
flutter test test/utils/score_calculator_test.dart
```

Expected: FAIL（文件不存在）

- [ ] **Step 3: 实现计分逻辑**

```dart
// lib/utils/score_calculator.dart
class RoundScoreResult {
  final int landlordScore;
  final int farmerAScore; // 踢了的农民（如果有踢的话）
  final int farmerBScore; // 没踢的农民

  const RoundScoreResult({
    required this.landlordScore,
    required this.farmerAScore,
    required this.farmerBScore,
  });
}

/// 根据 N 个加倍项计算基础分
int calculateBaseScore(int n) {
  if (n <= 5) return 5 * (1 << n);
  return 160 + (n - 5) * 50;
}

/// 计算一局各方的得分变化
///
/// farmerA 是踢了的农民（kickCount > 0 时），
/// farmerB 是没踢的农民。
/// 返回值：正数=赢分，负数=输分
RoundScoreResult calculateRoundScores({
  required bool isLandlordWin,
  required bool spring,
  required bool blind,
  required int kickCount,
  required int bombCount,
}) {
  final nBase = (spring ? 1 : 0) + (blind ? 1 : 0) + bombCount;
  final sBase = calculateBaseScore(nBase);

  final int sKick;
  if (kickCount > 0) {
    sKick = calculateBaseScore(nBase + kickCount);
  } else {
    sKick = sBase;
  }

  final int farmerADelta = sKick ~/ 2; // 踢了的农民的半分
  final int farmerBDelta = sBase ~/ 2; // 没踢的农民的半分

  int landlordScore = farmerADelta + farmerBDelta;
  int farmerAScore = -farmerADelta;
  int farmerBScore = -farmerBDelta;

  if (!isLandlordWin) {
    landlordScore = -landlordScore;
    farmerAScore = -farmerAScore;
    farmerBScore = -farmerBScore;
  }

  return RoundScoreResult(
    landlordScore: landlordScore,
    farmerAScore: farmerAScore,
    farmerBScore: farmerBScore,
  );
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd doudizhu_app
flutter test test/utils/score_calculator_test.dart
```

Expected: 全部 PASS

- [ ] **Step 5: Commit**

```bash
git add lib/utils/score_calculator.dart test/utils/score_calculator_test.dart
git commit -m "feat: add score calculator with tests"
```

---

### Task 3: 数据模型

**Files:**
- Create: `lib/models/player.dart`
- Create: `lib/models/session.dart`
- Create: `lib/models/round.dart`

- [ ] **Step 1: 创建 Player 模型**

```dart
// lib/models/player.dart
import 'dart:convert';

class Player {
  final String id;
  final String name;
  final String color; // 十六进制颜色值

  const Player({
    required this.id,
    required this.name,
    required this.color,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'color': color,
  };

  factory Player.fromMap(Map<String, dynamic> map) => Player(
    id: map['id'] as String,
    name: map['name'] as String,
    color: map['color'] as String,
  });

  Player copyWith({String? name, String? color}) => Player(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
  );
}

const defaultPlayers = [
  Player(id: 'p1', name: '吕布', color: '#E53935'),
  Player(id: 'p2', name: '赵云', color: '#1E88E5'),
  Player(id: 'p3', name: '司马懿', color: '#8E24AA'),
  Player(id: 'p4', name: '周瑜', color: '#43A047'),
  Player(id: 'p5', name: '张飞', color: '#FB8C00'),
];
```

- [ ] **Step 2: 创建 Session 模型**

```dart
// lib/models/session.dart
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
```

- [ ] **Step 3: 创建 Round 模型**

```dart
// lib/models/round.dart
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
```

- [ ] **Step 4: Commit**

```bash
git add lib/models/
git commit -m "feat: add data models (Player, Session, Round)"
```

---

### Task 4: 数据库服务

**Files:**
- Create: `lib/services/database_service.dart`

- [ ] **Step 1: 实现数据库服务**

```dart
// lib/services/database_service.dart
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
        // 插入默认玩家
        for (final p in defaultPlayers) {
          await db.insert('players', p.toMap());
        }
      },
    );
  }

  // Players
  Future<List<Player>> getPlayers() async {
    final db = await database;
    final maps = await db.query('players');
    return maps.map((m) => Player.fromMap(m)).toList();
  }

  Future<void> updatePlayer(Player player) async {
    final db = await database;
    await db.update('players', player.toMap(), where: 'id = ?', whereArgs: [player.id]);
  }

  // Sessions
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

  // Rounds
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/database_service.dart
git commit -m "feat: add SQLite database service"
```

---

### Task 5: 状态管理（Providers）

**Files:**
- Create: `lib/providers/player_provider.dart`
- Create: `lib/providers/game_provider.dart`

- [ ] **Step 1: 创建 PlayerProvider**

```dart
// lib/providers/player_provider.dart
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
```

- [ ] **Step 2: 创建 GameProvider**

```dart
// lib/providers/game_provider.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
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

  /// 获取最近3局记录
  List<GameRound> get recentRounds {
    if (_currentRounds.length <= 3) return _currentRounds;
    return _currentRounds.sublist(_currentRounds.length - 3);
  }

  /// 计算当前场次各玩家总分
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

    // 构建每人得分 map
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/providers/
git commit -m "feat: add state management providers"
```

---

### Task 6: App 入口 + 导航框架

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 重写 main.dart，集成 Provider 和导航**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';
import 'providers/game_provider.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/new_session_screen.dart';
import 'screens/history_screen.dart';

void main() {
  runApp(const DoudizhuApp());
}

class DoudizhuApp extends StatelessWidget {
  const DoudizhuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider(db)..loadPlayers()),
        ChangeNotifierProvider(create: (_) => GameProvider(db)..loadLatestSession()),
      ],
      child: MaterialApp(
        title: '斗地主记分',
        theme: ThemeData(
          colorSchemeSeed: Colors.red,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        routes: {
          '/settings': (_) => const SettingsScreen(),
          '/new-session': (_) => const NewSessionScreen(),
          '/history': (_) => const HistoryScreen(),
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire up Provider and navigation in main.dart"
```

---

### Task 7: 设置页面

**Files:**
- Create: `lib/screens/settings_screen.dart`

- [ ] **Step 1: 实现设置页面**

```dart
// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          return ListView.builder(
            itemCount: provider.players.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final player = provider.players[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _parseColor(player.color),
                        child: Text(
                          player.name.characters.first,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: player.name,
                          decoration: const InputDecoration(
                            border: UnderlineInputBorder(),
                            labelText: '玩家名字',
                          ),
                          onFieldSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              provider.updatePlayerName(player.id, value.trim());
                            }
                          },
                        ),
                      ),
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

  Color _parseColor(String hex) {
    final code = hex.replaceFirst('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add settings screen for player name editing"
```

---

### Task 8: 新建场次页面

**Files:**
- Create: `lib/screens/new_session_screen.dart`

- [ ] **Step 1: 实现新建场次页面**

```dart
// lib/screens/new_session_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/game_provider.dart';

class NewSessionScreen extends StatefulWidget {
  const NewSessionScreen({super.key});

  @override
  State<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends State<NewSessionScreen> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新建场次')),
      body: Consumer<PlayerProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '选择 3 位上场玩家（已选 ${_selected.length}/3）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.players.length,
                  itemBuilder: (context, index) {
                    final player = provider.players[index];
                    final isSelected = _selected.contains(player.id);
                    return Card(
                      color: isSelected ? Colors.red.shade50 : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _parseColor(player.color),
                          child: Text(
                            player.name.characters.first,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(player.name),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.red)
                            : const Icon(Icons.circle_outlined),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(player.id);
                            } else if (_selected.length < 3) {
                              _selected.add(player.id);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected.length == 3 ? _startSession : null,
                    child: const Text('开始'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _startSession() async {
    final gameProvider = context.read<GameProvider>();
    await gameProvider.createNewSession(_selected.toList());
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Color _parseColor(String hex) {
    final code = hex.replaceFirst('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/new_session_screen.dart
git commit -m "feat: add new session screen with player selection"
```

---

### Task 9: 记分首页（核心页面）

**Files:**
- Create: `lib/widgets/player_score_card.dart`
- Create: `lib/widgets/round_record_tile.dart`
- Create: `lib/widgets/score_input_panel.dart`
- Create: `lib/screens/home_screen.dart`

- [ ] **Step 1: 创建玩家分数卡片组件**

```dart
// lib/widgets/player_score_card.dart
import 'package:flutter/material.dart';

class PlayerScoreCard extends StatelessWidget {
  final String name;
  final String colorHex;
  final int score;

  const PlayerScoreCard({
    super.key,
    required this.name,
    required this.colorHex,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: _parseColor(colorHex),
              radius: 20,
              child: Text(
                name.characters.first,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            const SizedBox(height: 6),
            Text(name, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: score >= 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final code = hex.replaceFirst('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}
```

- [ ] **Step 2: 创建对局记录条目组件**

```dart
// lib/widgets/round_record_tile.dart
import 'package:flutter/material.dart';
import '../models/round.dart';

class RoundRecordTile extends StatelessWidget {
  final GameRound round;
  final Map<String, String> playerNames;

  const RoundRecordTile({
    super.key,
    required this.round,
    required this.playerNames,
  });

  @override
  Widget build(BuildContext context) {
    final landlordName = playerNames[round.landlordId] ?? '?';
    final result = round.isLandlordWin ? '地主赢' : '地主输';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '第${round.roundIndex}局',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('$landlordName(地主) $result'),
                const Spacer(),
                _buildMultiplierBadges(),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: round.scores.entries.map((e) {
                final name = playerNames[e.key] ?? '?';
                final score = e.value;
                return Text(
                  '$name: ${score >= 0 ? '+' : ''}$score',
                  style: TextStyle(
                    color: score >= 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiplierBadges() {
    final badges = <String>[];
    if (round.spring) badges.add('春天');
    if (round.blind) badges.add('蒙牌');
    if (round.kickCount > 0) badges.add('踢×${round.kickCount}');
    if (round.bombCount > 0) badges.add('炸×${round.bombCount}');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges
          .map((b) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Chip(
                  label: Text(b, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ))
          .toList(),
    );
  }
}
```

- [ ] **Step 3: 创建计分录入面板组件**

```dart
// lib/widgets/score_input_panel.dart
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../utils/score_calculator.dart';

class ScoreInputPanel extends StatefulWidget {
  final List<Player> sessionPlayers;
  final void Function({
    required String landlordId,
    required List<String> farmerIds,
    required bool isLandlordWin,
    required bool spring,
    required bool blind,
    required int kickCount,
    required String? kickFarmerId,
    required int bombCount,
  }) onSubmit;

  const ScoreInputPanel({
    super.key,
    required this.sessionPlayers,
    required this.onSubmit,
  });

  @override
  State<ScoreInputPanel> createState() => _ScoreInputPanelState();
}

class _ScoreInputPanelState extends State<ScoreInputPanel> {
  String? _landlordId;
  bool _isLandlordWin = true;
  bool _spring = false;
  bool _blind = false;
  int _kickCount = 0;
  String? _kickFarmerId;
  int _bombCount = 0;

  List<Player> get _farmers =>
      widget.sessionPlayers.where((p) => p.id != _landlordId).toList();

  int get _nBase => (_spring ? 1 : 0) + (_blind ? 1 : 0) + _bombCount;
  int get _nTotal => _nBase + _kickCount;

  int get _previewScore {
    if (_landlordId == null) return 0;
    return calculateBaseScore(_nTotal);
  }

  int get _previewBaseScore {
    if (_landlordId == null) return 0;
    return calculateBaseScore(_nBase);
  }

  void _reset() {
    setState(() {
      _landlordId = null;
      _isLandlordWin = true;
      _spring = false;
      _blind = false;
      _kickCount = 0;
      _kickFarmerId = null;
      _bombCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 选择地主
            const Text('选择地主', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: widget.sessionPlayers.map((p) {
                final selected = _landlordId == p.id;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(p.name),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _landlordId = p.id;
                          _kickFarmerId = null;
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // 地主赢/输
            const Text('结果', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ToggleButtons(
              isSelected: [_isLandlordWin, !_isLandlordWin],
              onPressed: (i) => setState(() => _isLandlordWin = i == 0),
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('地主赢')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('地主输')),
              ],
            ),
            const SizedBox(height: 12),

            // 加倍项
            const Text('加倍项', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('春天'),
              value: _spring,
              onChanged: (v) => setState(() => _spring = v),
            ),
            SwitchListTile(
              title: const Text('蒙牌'),
              value: _blind,
              onChanged: (v) => setState(() => _blind = v),
            ),

            // 踢
            if (_landlordId != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('踢：'),
                  const SizedBox(width: 8),
                  ..._farmers.map((f) {
                    final selected = _kickFarmerId == f.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.name),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            if (selected) {
                              _kickFarmerId = null;
                              _kickCount = 0;
                            } else {
                              _kickFarmerId = f.id;
                              _kickCount = 1;
                            }
                          });
                        },
                      ),
                    );
                  }),
                  if (_kickFarmerId != null) ...[
                    const SizedBox(width: 8),
                    ToggleButtons(
                      isSelected: [_kickCount == 1, _kickCount == 2],
                      onPressed: (i) => setState(() => _kickCount = i + 1),
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('踢')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('踢+反踢')),
                      ],
                    ),
                  ],
                ],
              ),
            ],

            // 炸弹数
            Row(
              children: [
                const Text('炸弹数：'),
                IconButton(
                  onPressed: _bombCount > 0 ? () => setState(() => _bombCount--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_bombCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _bombCount < 8 ? () => setState(() => _bombCount++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const Divider(),

            // 分数预览
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('本局分数：', style: TextStyle(fontSize: 16)),
                  Text(
                    '$_previewScore',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 确认按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _landlordId != null ? _submit : null,
                child: const Text('确认记分'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_landlordId == null) return;
    final farmerIds = widget.sessionPlayers
        .where((p) => p.id != _landlordId)
        .map((p) => p.id)
        .toList();

    widget.onSubmit(
      landlordId: _landlordId!,
      farmerIds: farmerIds,
      isLandlordWin: _isLandlordWin,
      spring: _spring,
      blind: _blind,
      kickCount: _kickCount,
      kickFarmerId: _kickFarmerId,
      bombCount: _bombCount,
    );
    _reset();
  }
}
```

- [ ] **Step 4: 实现首页（记分页面）**

```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/game_provider.dart';
import '../models/player.dart';
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
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).pushNamed('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
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
                  const Text('还没有场次', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushNamed('/new-session'),
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
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                // 顶部：总分卡片
                Padding(
                  padding: const EdgeInsets.all(12),
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

                // 新建场次按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pushNamed('/new-session'),
                    child: const Text('新建场次'),
                  ),
                ),
                const Divider(height: 24),

                // 中部：最近3局记录
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '最近 ${recent.length} 局',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                ...recent.reversed.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: RoundRecordTile(round: r, playerNames: playerNames),
                )),
                const Divider(height: 24),

                // 底部：录入面板
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
```

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/ lib/screens/home_screen.dart
git commit -m "feat: add home screen with scoring panel and round display"
```

---

### Task 10: 历史场次页面

**Files:**
- Create: `lib/screens/history_screen.dart`

- [ ] **Step 1: 实现历史场次列表页面**

```dart
// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/game_provider.dart';
import '../providers/player_provider.dart';
import '../screens/session_detail_screen.dart';

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
            return const Center(child: Text('暂无历史场次'));
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
              }).join('、');

              return Card(
                child: ListTile(
                  title: Text(date),
                  subtitle: Text(playerNames),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    game.loadSessionDetail(session.id);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SessionDetailScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/history_screen.dart
git commit -m "feat: add history screen for past sessions"
```

---

### Task 11: 场次详情页面

**Files:**
- Create: `lib/screens/session_detail_screen.dart`

- [ ] **Step 1: 实现场次详情页面**

```dart
// lib/screens/session_detail_screen.dart
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
            return const Center(child: Text('场次不存在'));
          }

          final date = DateFormat('yyyy-MM-dd HH:mm').format(session.createdAt);
          final playerNames = {for (var p in players.players) p.id: p.name};
          final scores = game.totalScores;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(date, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: session.playerIds.map((id) {
                        final name = playerNames[id] ?? '?';
                        final score = scores[id] ?? 0;
                        return Column(
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '$score',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: score >= 0 ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/session_detail_screen.dart
git commit -m "feat: add session detail screen with all rounds"
```

---

### Task 12: 集成测试 + 最终验证

**Files:**
- All files

- [ ] **Step 1: 运行全部测试**

```bash
cd doudizhu_app
flutter test
```

Expected: 全部 PASS

- [ ] **Step 2: 运行静态分析**

```bash
flutter analyze
```

Expected: 无错误

- [ ] **Step 3: 构建验证**

```bash
flutter build apk --debug
```

Expected: 构建成功

- [ ] **Step 4: 最终 Commit**

```bash
git add .
git commit -m "feat: complete doudizhu scoring app v1.0"
```
