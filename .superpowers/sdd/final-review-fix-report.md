# PWA 最终审查修复报告

- 任务中继：`task-pwa-final-review-fix-20260728-01`
- 日期：2026-07-28
- 修改范围：`doudizhu_app/sw.js`、`doudizhu_app/preview.html`、两份聚焦测试、`doudizhu_app/运行指南.md`

## 修复内容

1. 安装阶段改为一次调用 `cache.addAll(shellUrls())`。任一必需壳资源失败都会使 `install` 的 `waitUntil` Promise 拒绝，不会激活不完整的新 worker。
2. 缓存前缀纳入规范化后的 `registration.scope` 路径。同源不同子目录只清理各自命名空间中的旧版本；壳资源与离线回退均使用当前 `CACHE_NAME` 对应缓存实例的 `match`，不再使用全局 `caches.match`。
3. 页面增加 `visibilitychange` 检查，仅在 `document.visibilityState === 'visible'` 时调用 `registration.update()`；保留加载时及 `online` 时检查。
4. 保留显式 `SKIP_WAITING`、用户确认后安全单次刷新、相对 Service Worker 路径和现有离线回退语义，并同步更新运行指南。

## RED 证据

在只修改测试后运行：

```text
node --test doudizhu_app/test/service_worker.test.mjs doudizhu_app/test/preview_interactions.test.mjs
exit code: 1
tests: 39
pass: 34
fail: 5
```

预期失败覆盖：

- 页面从隐藏恢复为可见时未检查更新（期望 3 次，实际 2 次）。
- 安装未调用原子 `addAll`。
- 必需资源失败未向 `install` 传播拒绝。
- 激活阶段误删同源其他 scope 的缓存。
- 已知壳资源使用了全局缓存命中，而不是当前 scope 的缓存实例。

## GREEN 与回归证据

实现后聚焦测试：

```text
node --test doudizhu_app/test/service_worker.test.mjs doudizhu_app/test/preview_interactions.test.mjs
exit code: 0
tests: 39
pass: 39
fail: 0
```

全量测试：

```text
node --test "doudizhu_app/test/*.test.mjs"
exit code: 0
tests: 44
pass: 44
fail: 0
```

## 独立审查修复循环

只读独立审查发现，最初使用尾随 `-` 分隔 scope 与版本时存在前缀碰撞：例如 `/repo/doudizhu_app/` 会误匹配 `/repo/doudizhu_app-v2/`。先加入碰撞缓存测试并运行：

```text
node --test doudizhu_app/test/service_worker.test.mjs
exit code: 1
tests: 6
pass: 5
fail: 1
```

失败输出显示 sibling scope 缓存被错误加入删除列表。随后把边界改为 scope 编码不可能产生的 `::`，并强化未知资源离线回退测试，使当前缓存和全局缓存返回不同内容且断言全局查询次数为零。修复后：

```text
node --test doudizhu_app/test/service_worker.test.mjs
exit code: 0
tests: 6
pass: 6
fail: 0
```

提交前最终复验再次得到全量测试 44/44 通过（退出码 0），`git diff --check` 通过（退出码 0）。
