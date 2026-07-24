# 斗地主记分 APP 设计文档

## 概述

三人斗地主线下记分工具，支持 Android 和 iOS 双平台，Flutter 开发，数据本地存储。

## 记分规则

### 基本规则

- 底分：5 分/局
- 每局 3 人参与：1 个地主 + 2 个农民
- 记录：选择地主 → 地主赢/输 → 选择触发的加倍项 → 自动算分

### 加倍项

每个加倍项使分数 ×2：

| 加倍项 | 类型 | 说明 |
|--------|------|------|
| 春天 | 开关 | 地主赢且农民一张没出，或农民赢且地主只出过一次牌 |
| 蒙牌 | 开关 | 地主不看点底牌直接打 |
| 踢 | 数量(0/1/2) + 指定农民 | 需指定是哪个农民踢的；数量0=无，1=踢，2=踢+反踢 |
| 炸弹 | 数量(0~8) | 4 张同点或王炸，每颗炸弹算一个加倍项 |

### 计分公式

N = 春天(0/1) + 蒙牌(0/1) + 踢(数量) + 炸弹数

- N ≤ 5：分数 = 5 × 2^N
- N > 5：分数 = 160 + (N-5) × 50

对照表：

| N | 分数 |
|---|------|
| 0 | 5 |
| 1 | 10 |
| 2 | 20 |
| 3 | 40 |
| 4 | 80 |
| 5 | 160（封顶）|
| 6 | 210 |
| 7 | 260 |
| 8 | 310 |

### 踢的特殊规则

踢的加倍只影响踢的那个农民和地主之间的分数结算，另一个农民不受踢的加倍影响。

#### 分数分配

**无踢的情况：**

- 地主赢总分 S：地主 +S，每个农民 -S/2
- 地主输总分 S：地主 -S，每个农民 +S/2

**有踢的情况（农民 A 踢了）：**

- N_base = 春天 + 蒙牌 + 炸弹数
- N_kick = 踢的数量
- 基础分 S_base = min(5 × 2^N_base, 160)，若 N_base > 5 则 = 160 + (N_base-5) × 50
- 踢分 S_kick = min(5 × 2^(N_base+N_kick), 160)，若 N_base+N_kick > 5 则 = 160 + (N_base+N_kick-5) × 50

- 地主赢：
  - 农民 A（踢了的）：-S_kick / 2
  - 农民 B（没踢的）：-S_base / 2
  - 地主：+S_kick/2 + S_base/2

- 地主输则反过来，负变正

## 数据模型

```
Player
  - id: String
  - name: String
  - color: String (头像色)

Session (场次)
  - id: String
  - createdAt: DateTime
  - playerIds: List<String> (3人，从预设5人中选)

Round (对局)
  - id: String
  - sessionId: String
  - roundIndex: int
  - landlordId: String
  - farmerIds: List<String> (2人)
  - isLandlordWin: bool
  - spring: bool
  - blind: bool
  - kickCount: int (0/1/2)
  - kickFarmerId: String? (踢的农民ID，null表示无踢)
  - bombCount: int
  - scores: Map<String, int> (每人本局得分变化，正=赢，负=输)
```

## 页面结构

### 1. 首页 / 记分页面（默认页面）

打开 APP 默认进入当前场次的记分页面。

**顶部区域**：3 个玩家的累计总分，以卡片形式展示，每人一张卡片（名字 + 总分）。

**中部区域**：最近 3 局的对局记录，每条显示：
- 第几局
- 地主是谁、赢/输
- 各人本局得分

**底部录入区域**：
- 选择地主：3 个头像按钮，点击选中
- 地主赢/输：两个按钮切换
- 加倍项面板：
  - 春天：Toggle 开关
  - 蒙牌：Toggle 开关
  - 踢：选择哪个农民（点选）+ 数量（0/1/2 按钮组）
  - 炸弹数：+/- 按钮，范围 0~8
- 分数预览：实时显示计算出的分数
- "确认记分"按钮

### 2. 设置页面

- 编辑 5 个玩家的名字（默认：吕布、赵云、司马懿、周瑜、张飞）
- 名字可随时修改

### 3. 历史场次页面

- 场次列表：日期、参与玩家、各自总分
- 点击进入场次详情：所有对局明细

### 4. 新建场次

- 从 5 个预设玩家中选 3 个上场
- 确认后开始新场次

## 技术架构

- **框架**：Flutter
- **状态管理**：Provider
- **本地存储**：SQLite（sqflite）
- **平台**：Android + iOS
- **最低版本**：Android 5.0+ / iOS 12.0+

## 项目结构

```
lib/
  main.dart
  models/
    player.dart
    session.dart
    round.dart
  services/
    database_service.dart
    scoring_service.dart
  screens/
    home_screen.dart        # 记分页面（首页）
    settings_screen.dart    # 设置页面
    history_screen.dart     # 历史场次
    session_detail_screen.dart  # 场次详情
    new_session_screen.dart     # 新建场次
  widgets/
    player_card.dart
    round_record.dart
    score_input_panel.dart
    score_preview.dart
  utils/
    score_calculator.dart
```

## 默认玩家

| 名字 | 身份 |
|------|------|
| 吕布 | 天下第一猛将 |
| 赵云 | 常山赵子龙 |
| 司马懿 | 冢虎，最终赢家 |
| 周瑜 | 儒将风流 |
| 张飞 | 万夫莫敌 |
