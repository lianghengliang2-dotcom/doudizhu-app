# 语音播报设计

## 目标

在 Android/iOS 手机 App 中，每局确认记分后自动用语音朗读本局结果与当前累计总分，并在设置页提供"语音播报"开关。播报文案简短、语速快、清晰，不依赖任何服务器。

## 范围

- 新增 `flutter_tts` 依赖，封装 `TtsService`。
- 新增纯函数 `buildRoundAnnouncement` 生成播报文案。
- 新增 `VoiceSettingsProvider` 持久化"语音播报"开关（sqflite 新增 `settings` 表，DB 版本 1→2）。
- 设置页新增"语音播报"开关与"试听"按钮。
- HomeScreen 记分提交后自动播报。
- 补充文案生成的单元测试。

不修改计分公式、撤回逻辑、玩家数据、场次/局数据结构、网页版 `preview.html` 或 PWA 行为。

## 播报文案格式

以第 3 局、地主吕布赢 40 分、农民赵云 -20 分、司马懿 -20 分、累计吕布 +60/赵云 -30/司马懿 -30 为例：

```
第3局，地主吕布赢40分，赵云输20分，司马懿输20分。总分：吕布正60，赵云负30，司马懿负30。
```

规则：

- 本局部分：地主先说，再按 `farmerIds` 顺序读两位农民；玩家名前不读"农民"，地主保留"地主"前缀。
- "赢/输"由该玩家本局得分正负决定：正分读"赢"，负分读"输"（地主输时农民自动变"赢"）。
- 累计部分：按场上玩家顺序读"总分："，正分读"正 X"，负分读"负 X"，不读"分"单位。
- 数字使用阿拉伯数字（如"第3局""40分"），中文 TTS 引擎自然读成"第三局""四十分"。

## 架构与组件

### 新增文件

1. **`lib/services/tts_service.dart`** — `TtsService`
   - 初始化：`setLanguage('zh-CN')`，语速约 `0.65`（偏快），音量默认。
   - `speak(String text)`：先 `stop()` 再朗读；内部 try/catch，引擎不可用或朗读失败时静默忽略，不抛错。
   - 在 `main.dart` 通过 `Provider` 注入，供 HomeScreen 读取。

2. **`lib/utils/announcement.dart`** — 纯函数
   - `buildRoundAnnouncement({required GameRound round, required Map<String, String> playerNames, required Map<String, int> totalScores, required List<String> playerOrder}) → String`
   - `playerOrder` 为场上玩家顺序（`session.playerIds`），保证累计总分按规格顺序朗读。
   - 只做文本拼装，不触碰音频，便于单元测试。

3. **`lib/providers/voice_settings_provider.dart`** — `VoiceSettingsProvider extends ChangeNotifier`
   - `bool get voiceEnabled`，默认开启。
   - `load()`：启动时从数据库读取 `voice_enabled`。
   - `setVoiceEnabled(bool)`：写入数据库并 `notifyListeners`。

### 修改文件

4. **`pubspec.yaml`** — 新增 `flutter_tts` 依赖。
5. **`lib/main.dart`** — 注册 `VoiceSettingsProvider`（加载开关）与 `TtsService`（注入）。
6. **`lib/services/database_service.dart`** — DB 版本 1→2。
   - `onCreate`（全新安装）与 `onUpgrade`（老用户升级）都创建 `settings` 表：
     `key TEXT PRIMARY KEY, value TEXT NOT NULL`。
   - 新增 `getSetting(String key) → Future<String?>`、`setSetting(String key, String value) → Future<void>`。
7. **`lib/screens/settings_screen.dart`** — 顶部新增"语音播报"`Switch` 与"试听"按钮（试听朗读示例文案）。
8. **`lib/screens/home_screen.dart`** — `ScoreInputPanel.onSubmit` 改为 async，`await game.addRound(...)` 完成后，若 `voiceEnabled` 开启，则用 `currentRounds.last`、玩家名与 `game.totalScores` 构建文案并调用 `TtsService.speak`。

## 数据流与触发时机

记分提交 → `game.addRound` 保存本局 → 读取最新一局与累计总分 → 构建播报文案 → 开关开启时朗读。

## 错误处理

- `TtsService.speak` 全程 try/catch，失败静默跳过。
- 每次朗读前先 `stop()`，避免连续记分时语音重叠。
- 播报失败不影响记分与界面。

## 测试

- 单元测试 `buildRoundAnnouncement`（对齐现有 `score_calculator_test.dart` 风格）：
  - 地主赢：文案含角色、各玩家本局得分与累计总分，顺序正确。
  - 地主输：农民读作"赢"。
  - 多局累计总分正确。
- `TtsService` 依赖平台引擎，不做单测，只保留薄封装。
- 完成后运行 `flutter analyze` 与 `flutter test` 验证。

## 验收标准

- 每局"确认记分"后自动朗读本局结果与累计总分，语速偏快、文案简短。
- 设置页"语音播报"开关默认开启，关闭后不再播报，重启仍生效。
- 试听按钮可朗读示例文案。
- 老用户升级数据库（v1→v2）后设置表正常创建，不丢失已有场次与局数据。
- 播报失败不崩溃、不影响记分。
