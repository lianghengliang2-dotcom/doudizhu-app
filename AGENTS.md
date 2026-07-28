<!-- create-glm-subagent:start -->
## GLM 子智能体任务中继

在启动任何使用 `model_provider = "zhipu"` 的自定义子智能体前：

1. 用新的唯一 ID 把完整明文任务写入 `.codex/glm-task.json`。
2. 任务必须包含目标、限制、允许修改的文件和验收标准。
3. 不得在中继文件中写入 Key、密码或 Token。
4. 等待子智能体完成，再由主智能体验证修改和测试结果。
5. 永不读取、打印、记录或提交 `ZHIPU_API_KEY` 的值。

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
