# 斗地主记分网页 PWA（可安装 + 离线）设计

## 目标

把现有的单文件记分网页 `doudizhu_app/preview.html` 升级为标准可安装 PWA，满足：首次联网打开后，即使完全断网也能打开应用、记分、撤回和查看历史；恢复联网后能自动获取新版。整体策略为标准 PWA + 缓存优先。

本设计仅描述实现方案，不修改任何应用代码。

## 范围与现状基线

- 入口为 `doudizhu_app/preview.html`，单文件、零第三方依赖，所有逻辑在浏览器内完成。仓库内没有 `index.html`，因此应用启动入口固定为 `preview.html`，目录本身不作为启动依赖。
- 业务数据持久化在 `localStorage` 单命名空间键 `doudizhu_state`，结构为：
  - `schemaVersion`：数据格式版本（当前为 `1`）。
  - `players`：内置五名玩家，含 `id`、`name`、`color`。
  - `activeSession`：当前场次（`id`、`playerIds`、`totals`、`rounds`、`startedAt`，结束时补 `endedAt` 与玩家快照）。
  - `history`：已结束场次列表，含玩家姓名快照。
  - `draftRound`：尚未确认的记分面板草稿。
- 计分逻辑以 `doudizhu_app/lib/utils/score_calculator.dart` 为准，网页中的 `calcBaseScore` / `calcRoundScores` 必须与之保持一致，PWA 改造不得改动。
- 既有自动化测试在 `doudizhu_app/test/preview_interactions.test.mjs`，使用 `node:test` + 自带 DOM/localStorage 垫片，零依赖。

PWA 改造必须保留上述数据模型、计分逻辑和测试契约不变。

## 部署形态与路径兼容策略

应用需要同时兼容两种部署位置，因此所有资源引用一律使用相对路径，禁止绝对根路径：

- **本地预览**：直接双击或通过本地静态服务器打开 `preview.html`，基址为文件所在目录。
- **GitHub Pages 仓库子目录**：例如仓库部署为 `https://<user>.github.io/<repo>/doudizhu_app/`，基址为子目录。

路径处理规则：

1. 清单、图标、Service Worker 脚本均与 `preview.html` 同目录，引用为 `./manifest.webmanifest`、`./sw.js`、`./icons/...`。
2. 由于没有 `index.html`，`manifest.webmanifest` 的 `start_url` 固定为 `"./preview.html"`（指向真正的入口文档）；`scope` 使用相对值 `"./"`（应用作用域为清单所在目录）；`id` 使用相对值 `"./"`。三者均相对解析，避免绑定具体域名或子路径，本地与 GitHub Pages 子目录部署都正确。
3. Service Worker 用相对路径 `"./sw.js"` 注册，`scope` 设为 `"./"`，使其作用于清单同目录及其子路径。
4. HTML 中 `<link rel="manifest" href="./manifest.webmanifest">`、`<link rel="icon" ... href="./icons/icon-192.png">`、`<script>` 注册 `"./sw.js"` 全部相对。
5. 缓存的资源 URL 在 Service Worker 内部用相对字符串（如 `"./preview.html"`、`"./manifest.webmanifest"`）配合 `registration.scope` 拼接，绝不写死 `https://` 域名或 `/` 根路径。具体：用 `new URL(relativeUrl, registration.scope).href` 把相对串解析为当前作用域下的绝对 URL 再缓存，保证子目录部署缓存的是子目录下的资源。
6. 目录导航（请求作用域根 `"./"`）不作为启动入口依赖：`start_url` 明确指向 `./preview.html`，Service Worker 对目录请求的命中与否不影响安装与离线启动。

## 安装清单（manifest.webmanifest）

放在 `doudizhu_app/manifest.webmanifest`，与 `preview.html` 同目录。字段：

```json
{
  "name": "斗地主记分",
  "short_name": "斗地主",
  "description": "离线可用的斗地主三人记分工具",
  "id": "./",
  "start_url": "./preview.html",
  "scope": "./",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#151515",
  "theme_color": "#151515",
  "lang": "zh-CN",
  "icons": [
    { "src": "./icons/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
    { "src": "./icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" },
    { "src": "./icons/maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable" },
    { "src": "./icons/maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```

设计说明：

- `start_url: "./preview.html"` 明确指向真实入口文档（仓库无 `index.html`），`id` 与 `scope` 用 `"./"`。三者共同保证同一份清单在本地和 GitHub Pages 子目录都能被识别为同一应用，且不会绑定到某条绝对 URL。
- 同时提供 `any` 与 `maskable` 图标，满足 Chrome 安装清单可安装性检查（192/512）与 Android 自适应图标裁剪需求。
- `display: standalone` 让安装后以独立窗口形态运行，无浏览器地址栏。

## 图标

- 存放目录：`doudizhu_app/icons/`。
- 必需文件：`icon-192.png`、`icon-512.png`、`maskable-192.png`、`maskable-512.png`。
- 内容：以现有应用的扑克花色视觉（黑色背景 + 金色花色/字样）为基调，与页面深色主题一致，背景色 `#151515`。
- `any` 图标使用完整图形；`maskable` 图标把核心图形收紧到安全区（约中心 80% 区域），外围填充 `background_color`，避免被圆形/圆角矩形裁剪后丢失主体。
- favicon 复用 `icon-192.png`：HTML 中 `<link rel="icon" href="./icons/icon-192.png">`。
- 图标由矢量源生成 PNG，避免缩放模糊；后续实施任务负责产出实际位图，本设计只规定尺寸、用途与安全区约束。

## Service Worker

文件：`doudizhu_app/sw.js`，与 `preview.html` 同目录，scope 为 `"./"`。

### 注册

在 `preview.html` 现有 `<script>` 中、且仅当 `location.protocol === "https:" || location.hostname === "localhost" || location.hostname === "127.0.0.1"` 时注册（见下「错误与降级」对 `file://` 的处理）。注册代码用相对路径：

```js
if ("serviceWorker" in navigator) {
  window.addEventListener("load", function () {
    navigator.serviceWorker.register("./sw.js", { scope: "./" })
      .then(function (registration) {
        // 页面就绪后立即检查一次新版，并在恢复联网时再次检查（见「更新行为」）
        registration.update().catch(function () {});
        window.addEventListener("online", function () { registration.update().catch(function () {}); });
      })
      .catch(function () {
        // 注册失败不影响应用本身继续运行（降级策略见下文）
      });
  });
}
```

页面端还在 `registration` 上监听 `updatefound` 与 `navigator.serviceWorker` 的 `controllerchange`，用于驱动更新提示（见「更新行为」）。

### 缓存策略

应用外壳与静态资源采用**纯缓存优先**，并把资源缓存与业务数据彻底分离：

- **应用外壳与静态资源（纯缓存优先）**：`preview.html`、`manifest.webmanifest`、四个图标文件。命中缓存立即返回以保证离线可用；这些资源的更新一律由**新版 Service Worker 的 `install` 预缓存**完成，**活动中的 Service Worker 不在后台发起网络请求去改写已缓存的应用外壳 HTML**，避免运行中的页面与后台写入的新版 HTML 混用。
- **非 GET 请求与跨域请求**：直接放行到网络（记分应用无此类业务请求，规则仅作防御性兜底）。
- **不在预缓存清单中的同作用域 GET 请求**：先尝试网络，失败时回退缓存；都没有则返回离线占位响应，确保断网下不出现裸的浏览器错误页。

外壳的新版随 `sw.js` 的发布与缓存版本号一同下发：发布新版时递增 `sw.js` 中的缓存版本号字符串并更新预缓存清单内容，浏览器下载到字节变化的 `sw.js` 后安装新 SW，新 SW 在 `install` 时把新版外壳写入新版本缓存，旧版本外壳在旧 SW 仍活动期间保持不变。

### 预缓存清单

Service Worker 安装时缓存一组相对路径资源，解析为作用域内的绝对 URL：

- `"./preview.html"`
- `"./manifest.webmanifest"`
- `"./icons/icon-192.png"`
- `"./icons/icon-512.png"`
- `"./icons/maskable-192.png"`
- `"./icons/maskable-512.png"`

说明：清单不再把作用域根 `"./"` 作为缓存入口；`start_url` 指向 `./preview.html`，离线启动依赖的是被缓存的 `preview.html` 外壳，而非目录导航。

注意：`localStorage` 数据不属于缓存清单——它是业务数据，由页面 JS 读写，永不进入 Service Worker 的 Cache Storage。

### 生命周期事件

- `install`：预缓存上述清单。**不在 `install` 中无条件调用 `skipWaiting()`**。首次安装时没有旧 worker，新 SW 安装后自然进入激活并控制页面；升级安装时新 SW 安装完成后保持 `waiting` 状态，等待「用户点击立即更新发送 `SKIP_WAITING`」或「所有受控页面关闭后浏览器自然激活」两种路径之一，避免打断运行中的对局。
- `activate`：清理旧版本缓存（按缓存名白名单，删除非当前版本缓存条目），并调用 `clients.claim()`，让当前已打开的页面在新 SW 激活后受其控制。
- `fetch`：按上述缓存策略处理请求；导航请求优先命中被缓存的外壳 `preview.html`，保证离线启动。
- `message`：接收页面发来的 `SKIP_WAITING` 消息后调用 `self.skipWaiting()`，用于用户确认「立即更新」时让等待中的新 SW 接管。

## 更新行为

目标：恢复联网后自动获取新版，但不打断用户当前对局。

1. 页面 `load` 注册 SW 成功后立即调用 `registration.update()` 检查新版；浏览器恢复联网（`online` 事件）时再次调用 `registration.update()`。这两处触发实现「联网后自动获取新版」，`update()` 内部失败被静默吞掉，不影响页面。
2. 页面监听 `registration` 的 `updatefound` 与 `navigator.serviceWorker` 的 `controllerchange`。
3. 当检测到存在新的等待中 SW（`registration.waiting` 非空），在页面顶部或底部显示一条非阻塞提示（例如「发现新版本」），并提供一个「立即更新」按钮。
4. 用户点击「立即更新」时，向等待中的 SW 发送 `SKIP_WAITING` 消息，SW 在 `message` 中调用 `self.skipWaiting()`；待 `controllerchange` 触发后页面调用 `location.reload()` 加载新版。
5. 用户不点击时，当前版本继续运行；当所有受控页面关闭后，浏览器自然激活等待中的新 SW，下次完全冷启动即加载新版。
6. 不引入轮询；除上述 `load` 与 `online` 触发的 `registration.update()` 外，更新检查频率依赖浏览器自身的 SW 更新检查（页面打开、导航等时机）。

版本管理：缓存名带版本号，例如 `doudizhu-shell-v1`；每次发布新版时，实施计划中由构建/手动步骤递增版本号字符串，并更新 `sw.js` 预缓存清单中的外壳资源，`activate` 阶段据此淘汰旧缓存。

## 数据流

### 首次访问（在线）

1. 浏览器请求 `preview.html`，加载页面并注册 Service Worker。
2. 新 SW `install` 预缓存应用外壳与图标；首次安装无旧 worker，安装后自然激活并 `clients.claim()`。页面渲染后从 `localStorage` 读取 `doudizhu_state`，缺失则使用 `defaultState()`。
3. 注册成功后页面调用一次 `registration.update()`（首次通常无新版），随后在 `online` 时再次检查。
4. 用户记分操作照常通过既有 `persist()` 写入 `localStorage`，与 PWA 改造无关。

### 离线启动（已安装/已缓存）

1. 浏览器以 standalone 形态或浏览器标签打开应用（`start_url` 指向 `./preview.html`）。
2. Service Worker 拦截导航请求，从缓存返回被缓存的 `preview.html` 应用外壳，保证断网下可打开。
3. 页面脚本从 `localStorage` 读取业务数据（`localStorage` 不依赖网络）。
4. 记分、撤回、查看历史全部走本地逻辑，与在线一致；写入仍落到 `localStorage`。
5. 所有静态资源（清单、图标、脚本内联）已预缓存，无需联网。

### 在线更新

见上「更新行为」：页面在 `load` 与恢复 `online` 时调用 `registration.update()` 自动发现新版；新版 SW 安装后保持 `waiting`，通过非阻塞提示 + 用户点击 `SKIP_WAITING` 或关闭所有页面自然激活，随后刷新加载新版。活动 SW 不在后台改写已缓存外壳。

### localStorage 持久化

- 完全沿用现状：单键 `doudizhu_state`，`schemaVersion` + `players` + `activeSession` + `history` + `draftRound`。
- 载入时仍按既有 `loadState` 校验数据结构，损坏或不兼容时安全回退到 `defaultState()` 并提示。
- PWA 改造不引入 IndexedDB、不引入任何远端同步、不改变键名或结构，确保升级前后数据连续、用户历史不丢失。

## 错误与降级策略

- **`file://` 直开**：Service Worker 无法在 `file:` 协议注册。注册代码先判断协议/主机，仅在 `https:`、`localhost`、`127.0.0.1` 下注册；其余情况（含双击打开 `preview.html`）跳过注册，应用照常以「纯 localStorage + 无离线外壳」方式运行。即：PWA 离线能力需要一次在线安装（经 GitHub Pages 或本地静态服务器），与用户已确认的需求一致。
- **SW 注册失败**：`register().catch()` 静默吞错，页面主功能不受影响。
- **`registration.update()` 失败**：在 `load` 与 `online` 触发处用 `.catch()` 静默吞错；检查不到新版不影响当前版本运行。
- **预缓存失败**：逐个资源 `cache.add`，单个失败不中断整体安装；缺失资源在后续 `fetch` 阶段按「网络优先回退缓存」补取。
- **图标缺失**：清单仍可加载，仅影响可安装性判定与桌面图标外观；页面内功能不受影响。实施任务必须确保四个图标文件真实存在。
- **数据损坏**：沿用既有 `loadState` 回退逻辑，回到默认状态并提示「检测到损坏数据，已安全恢复默认状态」，不让页面白屏。
- **缓存清理**：`activate` 只删除不在白名单中的旧版本缓存，绝不触碰 `localStorage`。
- **不支持 Service Worker 的浏览器**：注册代码以 `"serviceWorker" in navigator` 守卫，缺失时跳过，应用作为普通网页继续可用。

## 自动化测试策略

沿用现有 `node:test` + 自带 DOM/localStorage 垫片、零依赖的方式，新增针对 PWA 资产与 SW 行为的测试。测试保持「先写失败再实现」节奏，可拆为独立任务：

1. **清单契约测试**（纯 JSON 解析，无 DOM 依赖）：
   - `manifest.webmanifest` 存在且可被 `JSON.parse`。
   - 必填字段齐全：`name`、`short_name`、`start_url`、`scope`、`display`、`icons`。
   - `start_url` 为 `"./preview.html"`，`scope` 为 `"./"`，`id` 为 `"./"`（相对路径断言）。
   - `icons` 同时包含 192 与 512、同时包含 `any` 与 `maskable` purpose。
2. **preview.html PWA 接入断言**（基于现有读取 + DOM 垫片）：
   - HTML 中存在 `<link rel="manifest" href="./manifest.webmanifest">`。
   - HTML 中存在 favicon `<link rel="icon">` 指向 `./icons/`。
   - HTML 内联脚本中存在 `navigator.serviceWorker.register("./sw.js"` 且带 `{ scope: "./" }`，且仅在 https/localhost/127.0.0.1 下注册（可断言出现协议/主机判断条件）。
   - 注册成功的 `then` 分支中存在 `registration.update()` 调用，且存在 `online` 事件监听中再次调用 `registration.update()`。
3. **Service Worker 单元测试**（在 Node 中用 `vm` 加载 `sw.js`，注入事件桩）：
   - `install` 事件触发后，预缓存清单中的相对资源（含 `"./preview.html"`，不含作用域根 `"./"`）被加入「Cache Storage」桩。
   - `install` 默认路径**不**调用 `skipWaiting` 等价行为；仅当收到 `message({type:"SKIP_WAITING"})` 时才调用。
   - `fetch` 对导航请求命中缓存外壳；对清单内静态资源命中缓存（纯缓存优先，活动 worker 不发起后台外壳更新）；对未知同作用域 GET 请求在网络可用时走网络、不可用时回退缓存或离线占位。
   - `activate` 删除非白名单缓存。
   - 测试不得让 `localStorage` 与 Cache Storage 产生交叉污染。
4. **既有功能回归**：保留并继续通过 `preview_interactions.test.mjs` 验证记分、撤回、结束场次、数据持久化与损坏回退不受 PWA 改造影响。

测试命令：`node --test "doudizhu_app/test/*.test.mjs"`（覆盖全部 Node 测试文件，零额外依赖）。

## 浏览器人工验收标准

- **安装**：在 Chrome/Edge 移动端或桌面端，访问部署地址（GitHub Pages 子目录或本地 localhost 静态服务），地址栏出现「安装」入口或菜单出现「安装应用」，可成功安装；安装后从图标启动直达 `preview.html` 入口。
- **离线打开**：安装后断网（飞行模式或 DevTools Offline），从桌面图标打开应用，能正常进入首页。
- **离线记分**：断网下新建场次、记一局、查看分数变化，全部正常。
- **离线撤回**：断网下撤回上一局，总分与局列表正确回退。
- **离线历史**：断网下查看历史场次与详情，姓名快照与分数正确。
- **持久化**：离线记分后彻底关闭应用再重新打开（仍离线），数据与上次一致。
- **在线更新**：恢复联网、发布新版后重新打开，应用通过 `load`/`online` 触发的 `registration.update()` 自动发现新版并出现「发现新版本」提示；点击「立即更新」后刷新即新版；不点击则关闭所有页面后下次冷启动为新版。
- **不打断对局**：发布新版时，运行中的对局在新 SW `waiting` 期间不会被切换，外壳与页面版本保持一致，直至用户确认更新或冷启动。
- **子目录兼容**：在 GitHub Pages 仓库子目录路径下重复上述安装、离线、更新验收，图标与作用域均正确，不出现 404 或作用域错误。
- **降级**：直接双击本地 `preview.html`（`file://`）仍可作为普通网页记分，仅无离线外壳。

## 明确非目标

- 不做跨设备同步、账户登录、服务器端数据库或后端 API。
- 不接入应用商店（App Store / Google Play）打包分发。
- 不引入 IndexedDB 或改变 `localStorage` 单键数据模型。
- 不修改计分规则，网页计分继续对齐 `score_calculator.dart`。
- 不引入构建工具链或第三方前端框架；保持单文件 + 零运行时依赖。
- 不做推送通知、后台同步（Background Sync）等额外 PWA 能力。
- 不为 `file://` 直开提供离线外壳（由平台限制决定）。
- 不新增 `index.html`，启动入口固定为 `preview.html`。
- 不由活动 Service Worker 在后台改写已缓存的应用外壳。
- 不在 `install` 阶段无条件 `skipWaiting()`。
- 不读取、打印、记录或提交任何 Key、密码或 Token。

## 实施任务拆分指引

本设计足够支持后续拆分为以下测试先行的独立实施任务（具体计划由后续编写）：

1. 生成图标资源（192/512，any/maskable）并放入 `doudizhu_app/icons/`。
2. 新增 `manifest.webmanifest`，`start_url` 为 `"./preview.html"`、`scope`/`id` 为 `"./"`（先写清单契约测试再实现）。
3. 在 `preview.html` 接入 manifest、favicon 与条件化 SW 注册，注册成功 `then` 中调用 `registration.update()` 并监听 `online` 再次调用（先写接入断言测试）。
4. 实现 `sw.js` 纯缓存优先外壳、预缓存清单（含 `./preview.html`，不含作用域根）、`install` 不无条件 skipWaiting、`message` 中 `SKIP_WAITING` 触发 `self.skipWaiting()`、`activate` 清旧缓存（先写 SW 单元测试）。
5. 实现页面端更新提示（`updatefound`/`controllerchange`/`registration.waiting`）与「立即更新」发送 `SKIP_WAITING` 交互（先写交互测试）。
6. 全量回归 `preview_interactions.test.mjs` + 浏览器人工验收清单。

每个任务都应保持「现有记分逻辑与 localStorage 数据模型不变」这一全局约束。
