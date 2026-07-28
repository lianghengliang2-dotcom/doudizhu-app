# GLM 通用开发子智能体设计

## 目标

为斗地主 Flutter 项目创建一个由 Codex 主智能体调度的 `developer` 子智能体。该子智能体使用 GLM-5.2，能够读取和修改当前项目代码、运行 Flutter 分析与测试、定位并修复问题，同时保持权限和凭据边界清晰。

## 方案

采用受限开发型配置：

- Agent 名称：`developer`
- 模型：`glm-5.2`
- Provider：`zhipu`
- 推理强度：`high`
- 沙箱：`workspace-write`
- 工作范围：当前 Git 项目
- 主要职责：理解项目、修改代码、运行测试、修复缺陷和报告验证结果

不采用只读方案，因为它无法完成修复；不采用完全权限方案，因为当前任务不需要访问项目外文件或修改系统。

## 架构与数据流

1. Codex 主智能体把完整明文任务写入项目级任务中继文件。
2. 主智能体启动项目级 `developer` Agent。
3. Agent 通过用户级 `zhipu` Provider 调用本机 Responses 适配器。
4. 适配器仅监听 `127.0.0.1:8787`，把 Responses 请求转换为智谱 Coding Plan Chat Completions 请求。
5. 智谱 API Key 只从 `ZHIPU_API_KEY` 环境变量读取，不写入项目、Agent TOML、技能文件或日志。
6. Agent 在当前项目的 `workspace-write` 沙箱中使用文件和命令工具完成任务。

## 配置边界

项目级配置：

- `.codex/agents/developer.toml`：角色、模型、Provider、上下文和沙箱设置
- `AGENTS.md`：任务中继和安全规则
- `.codex` 下的任务中继状态：每次委派前写入完整任务，完成后标记 `done`

用户级配置：

- `~/.codex/config.toml`：只增加 `model_providers.zhipu`
- `ZHIPU_API_KEY`：由用户设置为系统环境变量

现有主 Agent 的 OpenAI/ChatGPT Provider 保持不变。

## 安全与错误处理

- 不读取、回显、记录或提交 API Key。
- 不覆盖已有同名 Agent；若出现同名配置，停止并报告。
- 适配器只绑定环回地址，避免暴露到局域网。
- 若 Provider、Key、`encrypted_content` 或工具名转换失败，依据技能故障排查说明定位，不绕过沙箱或扩大权限。
- 每次委派使用新的任务 ID，并在任务正文中明确目标、限制、允许修改的文件和验收标准。

## 验收

按以下顺序验证：

1. 配置检查脚本确认 Agent TOML、Provider 和任务中继完整。
2. `http://127.0.0.1:8787/health` 返回 `status: ok`。
3. 只读冒烟任务仅列出项目文件，Git 工作区无新增改动。
4. 检查适配器日志，确认实际路由模型为 `glm-5.2`。
5. 最小写入任务只在 `.codex` 下创建临时验证文件；核对内容后删除该文件。
6. Agent 运行现有 Flutter 分析或测试，主智能体复核输出和 Git diff。

如果环境变量尚未配置，则先完成所有静态配置检查，并明确把联网冒烟验证标记为等待用户设置 Key，而不伪报成功。
