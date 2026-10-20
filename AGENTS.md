<!-- create-glm-subagent:start -->
## GLM 子智能体任务中继

在启动任何使用 `model_provider = "zhipu"` 的自定义子智能体前：

1. 用新的唯一 ID 把完整明文任务写入 `.codex/glm-task.json`。
2. 任务必须包含目标、限制、允许修改的文件和验收标准。
3. 不得在中继文件中写入 Key、密码或 Token。
4. 等待子智能体完成，再由主智能体独立验证修改和测试结果。
5. 只有在主智能体验证成功后，才由主智能体立即把同一个中继的 `status` 从 `"pending"` 更新为 `"done"`；适配器会忽略非 pending 中继，避免已验证任务被重放。
6. 如果子智能体失败、验证未通过或仍需重试，保持 `status` 为 `"pending"`，不要提前标记 done；任务内容发生变化时使用新的唯一 ID。
7. 永不读取、打印、记录或提交 `ZHIPU_API_KEY` 的值。

中继格式：

```json
{
  "version": 1,
  "id": "unique-task-id",
  "status": "pending",
  "project_root": "/absolute/project/path",
  "task": "完整任务正文"
}
```
<!-- create-glm-subagent:end -->

<!-- QWEN_RELAY_PROJECT_START -->
## Qwen / Luna 接力

- 本项目编码默认使用用户级 `$qwen-relay` Skill；Codex 规划，Sol 审查，按项目 mode 选择本地 Qwen 或 Codex Luna 执行。
- 先读取 `.qwen-relay.json`；mode 为 qwen 或 luna，旧配置缺省为 qwen；`enabled: false` 或用户明确停用时遵循其选择。
- 复用 `J:\claude\开发项目\claude-qwen-relay`，通过现有 `relay.py` 实际启动任务。
- 项目重要规则由 Codex整理到任务要求；执行端安全模式不保证自动加载项目指令。
- 任务文件和证据按 Skill 约定保存；验收失败最多回修两次，不跳过失败、不悄悄改用 Codex 编码。
- 本地提交按项目配置及用户授权执行；不自动推送、部署或改全局/模型服务配置。
<!-- QWEN_RELAY_PROJECT_END -->
