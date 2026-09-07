# 语音播报实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在斗地主记分 App 每局确认记分后，用手机系统 TTS 自动朗读本局结果与累计总分，并在设置页提供可持久化的"语音播报"开关。

**Architecture:** 新增 `flutter_tts` 依赖。用一个纯函数 `buildRoundAnnouncement` 生成播报文案（可单测）；`TtsService` 薄封装 FlutterTts（中文、快语速、失败静默）；`VoiceSettingsProvider` 持久化开关到 sqflite 新增的 `settings` 表（DB 版本 1→2）；HomeScreen 记分提交后异步朗读。全程不依赖服务器。

**Tech Stack:** Flutter (Dart SDK ^3.5.4)、provider、sqflite、flutter_tts ^4.2.5。

> **重要环境说明：** 当前开发目录 **未安装 Flutter**（`flutter`/`dart` 命令不存在），且**不是 git 仓库**。因此本计划中的所有 `flutter pub get`、`flutter analyze`、`flutter test` 及 `git commit` 步骤需在用户装有 Flutter 的机器上执行；代码可在此目录直接编写，提交与最终验证由用户本机完成。单元测试代码已给出，无法在此环境运行确认。

---

### Task 1: 添加 flutter_tts 依赖

**Files:**
- Modify: `doudizhu_app/pubspec.yaml:16`

- [ ] **Step 1: 在 pubspec.yaml 的 dependencies 中新增 flutter_tts**

在 `intl: ^0.19.0` 之后追加：

```yaml
  flutter_tts: ^4.2.5
```

- [ ] **Step 2: 更新依赖锁定（用户本机执行）**

Run: `cd doudizhu_app && flutter pub get`
Expected: `pubspec.lock` 中新增 `flutter_tts` 条目，无错误。

---

### Task 2: 播报文案生成纯函数（TDD）

**Files:**
- Create: `doudizhu_app/lib/utils/announcement.dart`
- Test: `doudizhu_app/test/utils/announcement_test.dart`

- [ ] **Step 1: 编写失败测试**

创建 `doudizhu_app/test/utils/announcement_test.dart`：

```dart
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
```

- [ ] **Step 2: 运行测试确认失败（用户本机执行）**

Run: `cd doudizhu_app && flutter test test/utils/announcement_test.dart`
Expected: 失败，错误为 `announcement.dart` 不存在（`URI doesn't exist`）。

- [ ] **Step 3: 实现纯函数**

创建 `doudizhu_app/lib/utils/announcement.dart`：

```dart
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
```

- [ ] **Step 4: 运行测试确认通过（用户本机执行）**

Run: `cd doudizhu_app && flutter test test/utils/announcement_test.dart`
Expected: 5 个测试全部通过。

- [ ] **Step 5: 提交（用户本机，若有 git）**

```bash
git add doudizhu_app/lib/utils/announcement.dart doudizhu_app/test/utils/announcement_test.dart
git commit -m "feat: 新增语音播报文案生成纯函数"
```

---

### Task 3: 数据库新增 settings 表与读写方法

**Files:**
- Modify: `doudizhu_app/lib/services/database_service.dart`

- [ ] **Step 1: 数据库版本升级并新增表**

修改 `database_service.dart`：

1. 版本 `version: 1` → `version: 2`。
2. 在 `onCreate` 的 rounds 建表之后追加：

```dart
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
```

3. 在 `openDatabase` 调用中新增 `onUpgrade`：

```dart
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
      },
```

- [ ] **Step 2: 新增读写方法**

在 `database_service.dart` 末尾（`getRoundsForSession` 之后）追加：

```dart
  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
```

- [ ] **Step 3: 提交（用户本机，若有 git）**

```bash
git add doudizhu_app/lib/services/database_service.dart
git commit -m "feat: 数据库升级 v2 新增 settings 表"
```

---

### Task 4: 封装 TtsService

**Files:**
- Create: `doudizhu_app/lib/services/tts_service.dart`

- [ ] **Step 1: 创建 TtsService**

创建 `doudizhu_app/lib/services/tts_service.dart`：

```dart
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.65);
      await _tts.setVolume(1.0);
      _initialized = true;
    } catch (_) {
      // 引擎不可用时静默跳过，不抛出
    }
  }

  Future<void> speak(String text) async {
    await _ensureInitialized();
    if (!_initialized) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // 朗读失败静默忽略，不打断记分
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
```

- [ ] **Step 2: 提交（用户本机，若有 git）**

```bash
git add doudizhu_app/lib/services/tts_service.dart
git commit -m "feat: 新增 TTS 语音服务封装"
```

---

### Task 5: 语音设置 Provider

**Files:**
- Create: `doudizhu_app/lib/providers/voice_settings_provider.dart`

- [ ] **Step 1: 创建 VoiceSettingsProvider**

创建 `doudizhu_app/lib/providers/voice_settings_provider.dart`：

```dart
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class VoiceSettingsProvider extends ChangeNotifier {
  static const _voiceKey = 'voice_enabled';
  final DatabaseService _db;
  bool _voiceEnabled = true;

  VoiceSettingsProvider(this._db);

  bool get voiceEnabled => _voiceEnabled;

  Future<void> load() async {
    final value = await _db.getSetting(_voiceKey);
    _voiceEnabled = value != 'false';
    notifyListeners();
  }

  Future<void> setVoiceEnabled(bool enabled) async {
    _voiceEnabled = enabled;
    notifyListeners();
    await _db.setSetting(_voiceKey, enabled.toString());
  }
}
```

- [ ] **Step 2: 提交（用户本机，若有 git）**

```bash
git add doudizhu_app/lib/providers/voice_settings_provider.dart
git commit -m "feat: 新增语音播报设置 Provider"
```

---

### Task 6: 在 main.dart 注册服务与 Provider

**Files:**
- Modify: `doudizhu_app/lib/main.dart:2-10`（import 区）与 `:26-33`（providers 区）

- [ ] **Step 1: 新增 import**

在 `doudizhu_app/lib/main.dart` 的 import 区追加：

```dart
import 'providers/voice_settings_provider.dart';
import 'services/tts_service.dart';
```

- [ ] **Step 2: 注册 Provider**

把 `providers: [...]` 列表改为：

```dart
      providers: [
        Provider(create: (_) => TtsService()),
        ChangeNotifierProvider(create: (_) => PlayerProvider(db)..loadPlayers()),
        ChangeNotifierProvider(create: (_) => GameProvider(db)..loadLatestSession()),
        ChangeNotifierProvider(create: (_) => VoiceSettingsProvider(db)..load()),
      ],
```

- [ ] **Step 3: 提交（用户本机，若有 git）**

```bash
git add doudizhu_app/lib/main.dart
git commit -m "feat: 注册 TTS 服务与语音设置 Provider"
```

---

### Task 7: 设置页新增语音播报开关与试听

**Files:**
- Modify: `doudizhu_app/lib/screens/settings_screen.dart`

- [ ] **Step 1: 新增 import**

在 `settings_screen.dart` 顶部追加：

```dart
import '../providers/voice_settings_provider.dart';
import '../services/tts_service.dart';
```

- [ ] **Step 2: 改造 body 为 Consumer2 并在顶部加设置卡片**

把 `body: Consumer<PlayerProvider>(...)` 整体替换为：

```dart
      body: Consumer2<PlayerProvider, VoiceSettingsProvider>(
        builder: (context, provider, voice, _) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1C1410),
                      Color(0xFF2A1F18),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8B6914), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.volume_up, color: Color(0xFFC4952A)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('语音播报', style: TextStyle(color: Color(0xFFF5E6C8), fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline, color: Color(0xFFFFD54F)),
                      tooltip: '试听',
                      onPressed: () => context.read<TtsService>().speak('斗地主记分，语音播报试听'),
                    ),
                    Switch(
                      value: voice.voiceEnabled,
                      onChanged: (v) => voice.setVoiceEnabled(v),
                    ),
                  ],
                ),
              ),
              ...provider.players.map((player) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1C1410),
                        Color(0xFF2A1F18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF8B6914), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF8B6914), Color(0xFFC4952A)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parseColor(player.color),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFC4952A), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          player.name.characters.first,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: player.name,
                          style: const TextStyle(color: Color(0xFFF5E6C8)),
                          decoration: const InputDecoration(
                            border: UnderlineInputBorder(),
                            labelText: '名字',
                            labelStyle: TextStyle(color: Color(0xFF8B7355)),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF8B6914)),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFC4952A), width: 2),
                            ),
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
                );
              }),
            ],
          );
        },
      ),
```

- [ ] **Step 3: 提交（用户本机，若有 git）**

```bash
git add doudizhu_app/lib/screens/settings_screen.dart
git commit -m "feat: 设置页新增语音播报开关与试听"
```

---

### Task 8: 记分后自动播报

**Files:**
- Modify: `doudizhu_app/lib/screens/home_screen.dart`

- [ ] **Step 1: 新增 import**

在 `home_screen.dart` 顶部追加：

```dart
import '../providers/voice_settings_provider.dart';
import '../services/tts_service.dart';
import '../utils/announcement.dart';
```

- [ ] **Step 2: onSubmit 改为异步并在记分后播报**

把 `ScoreInputPanel` 的 `onSubmit` 回调整体替换为：

```dart
                  onSubmit: ({
                    required landlordId,
                    required farmerIds,
                    required isLandlordWin,
                    required spring,
                    required blind,
                    required kickCount,
                    required kickFarmerId,
                    required bombCount,
                  }) async {
                    await game.addRound(
                      landlordId: landlordId,
                      farmerIds: farmerIds,
                      isLandlordWin: isLandlordWin,
                      spring: spring,
                      blind: blind,
                      kickCount: kickCount,
                      kickFarmerId: kickFarmerId,
                      bombCount: bombCount,
                    );
                    final voice = context.read<VoiceSettingsProvider>();
                    if (!voice.voiceEnabled) return;
                    if (game.currentRounds.isEmpty) return;
                    final latest = game.currentRounds.last;
                    final text = buildRoundAnnouncement(
                      round: latest,
                      playerNames: playerNames,
                      totalScores: game.totalScores,
                      playerOrder: sessionPlayerIds,
                    );
                    await context.read<TtsService>().speak(text);
                  },
```

- [ ] **Step 3: 提交（用户本机，若有 git）**

```bash
git add doudizhu_app/lib/screens/home_screen.dart
git commit -m "feat: 每局记分后自动语音播报"
```

---

### Task 9: 整体验证

- [ ] **Step 1: 静态分析与全部测试（用户本机执行）**

Run: `cd doudizhu_app && flutter pub get && flutter analyze && flutter test`
Expected:
- `flutter analyze` 无 error（可能提示 `TtsService` 中 await 的返回值未使用等 lints，若 `flutter_lints` 有意见则补充 `// ignore:` 或按要求处理）。
- `flutter test` 全部通过（新增 announcement 测试 5 个 + 既有测试）。

- [ ] **Step 2: 真机手动验收**

在 Android/iOS 真机运行 `flutter run`，验证：

1. 新建场次、选三位玩家、开始。
2. 录入一局（选地主、结果、加倍项），点"确认记分"→ 手机语音朗读本局结果与累计总分，语速偏快、文案简短。
3. 连续录入第二局，语音不重叠，文案中的局数与累计总分正确。
4. 进设置页关闭"语音播报"开关 → 回到首页再记一局，不再播报。
5. 关闭 App 重开 → 开关仍为关闭（持久化生效）；重新开启 → 恢复播报。
6. 点"试听"按钮能朗读示例文案。
7. 老版本升级数据库后历史场次与局数据完整保留，设置表正常创建。

- [ ] **Step 3: 提交（用户本机，若有 git）**

```bash
git add -A
git commit -m "feat: 语音播报功能（flutter_tts + 设置开关 + 自动播报）"
```

---

## 自审结论

- **Spec 覆盖：** 播报文案格式（Task 2）、TtsService（Task 4）、开关持久化/DB 迁移（Task 3/5/6）、设置页开关与试听（Task 7）、记分后自动播报（Task 8）、错误处理（TtsService 内 try/catch + 开关门控）、测试与验收（Task 2/9）均已覆盖。
- **占位符：** 无 TODO/TBD；每步含完整代码与命令。
- **类型一致性：** `buildRoundAnnouncement` 签名（round/playerNames/totalScores/playerOrder）在 Task 2 定义、Task 8 调用一致；`getSetting`/`setSetting` 在 Task 3 定义、Task 5 调用一致；`TtsService.speak` 在 Task 4 定义、Task 7/8 调用一致。
- **说明：** `ScoreInputPanel.onSubmit` 类型为 `void Function(...)`，异步闭包（返回 `Future<void>`）可正常赋给 `void Function` 返回类型，无需改面板组件签名。
