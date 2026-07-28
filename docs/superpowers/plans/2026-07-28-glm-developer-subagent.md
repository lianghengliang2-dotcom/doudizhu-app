# GLM Developer Subagent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create and verify a project-scoped `developer` subagent that uses GLM-5.2 to edit this Flutter project, run tests, and fix defects.

**Architecture:** A project-level Agent TOML selects the user-level `zhipu` Provider. Codex sends Responses requests to a localhost adapter, which injects a plaintext task relay and converts requests to the Zhipu Coding Plan Chat Completions API. The API key remains in the Windows user environment and never enters repository files.

**Tech Stack:** Codex custom Agents, TOML, Python 3, Node.js, Zhipu GLM-5.2, PowerShell, Flutter/Dart

## Global Constraints

- Agent name is exactly `developer`.
- Model is exactly `glm-5.2` through Provider `zhipu`.
- Sandbox mode is exactly `workspace-write`.
- The adapter binds only to `127.0.0.1:8787`.
- Never read, print, log, or commit the value of `ZHIPU_API_KEY`.
- Preserve the main Agent's existing OpenAI/ChatGPT Provider.
- Do not overwrite an existing `.codex/agents/developer.toml`.
- Each delegated task must state its goal, constraints, allowed files, and acceptance criteria.

---

### Task 1: Generate the project-level Agent configuration

**Files:**
- Create: `.codex/agents/developer.toml`
- Create: `AGENTS.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `create_agent.py --project-root --name --description --model --provider --reasoning --sandbox`
- Produces: a registered `developer` Agent and managed task-relay rules in `AGENTS.md`

- [ ] **Step 1: Verify the expected files do not already exist**

Run:

```powershell
Test-Path -LiteralPath '.codex\agents\developer.toml'
Test-Path -LiteralPath 'AGENTS.md'
```

Expected: both commands return `False`. If the Agent file returns `True`, stop without using `--overwrite`.

- [ ] **Step 2: Run the skill's Agent generator**

Run:

```powershell
python 'C:\Users\YANG\.codex\skills\create-glm-subagent\scripts\create_agent.py' `
  --project-root 'J:\claude\开发项目\斗地主APP' `
  --name developer `
  --description '读取和修改当前项目代码、运行 Flutter 分析与测试、定位并修复问题' `
  --model glm-5.2 `
  --provider zhipu `
  --reasoning high `
  --sandbox workspace-write
```

Expected: the script prints the absolute path to `.codex\agents\developer.toml`.

- [ ] **Step 3: Verify the generated fields and managed rules**

Run:

```powershell
Get-Content -LiteralPath '.codex\agents\developer.toml' -Raw
Select-String -LiteralPath 'AGENTS.md' -SimpleMatch '<!-- create-glm-subagent:start -->'
Select-String -LiteralPath '.gitignore' -SimpleMatch '.codex/glm-task.json'
```

Expected: TOML contains `model = "glm-5.2"`, `model_provider = "zhipu"`, and `sandbox_mode = "workspace-write"`; both searches return one match.

- [ ] **Step 4: Review the project diff**

Run:

```powershell
git diff --check
git diff -- '.codex/agents/developer.toml' 'AGENTS.md' '.gitignore'
```

Expected: no whitespace errors and no unrelated changes.

### Task 2: Configure the user-level Zhipu Provider

**Files:**
- Modify: `C:\Users\YANG\.codex\config.toml`

**Interfaces:**
- Consumes: local adapter endpoint `http://127.0.0.1:8787/v1`
- Produces: Provider ID `zhipu` using Responses wire format and environment variable authentication

- [ ] **Step 1: Back up and inspect only Provider section names**

Run:

```powershell
Copy-Item -LiteralPath 'C:\Users\YANG\.codex\config.toml' -Destination 'C:\Users\YANG\.codex\config.toml.pre-glm-backup'
Select-String -LiteralPath 'C:\Users\YANG\.codex\config.toml' -Pattern '^\[model_providers\.' | ForEach-Object Line
```

Expected: backup succeeds; the output does not include `[model_providers.zhipu]`.

- [ ] **Step 2: Add the Provider without changing the main model**

Append this exact TOML block once:

```toml
[model_providers.zhipu]
name = "Zhipu GLM through local Responses adapter"
base_url = "http://127.0.0.1:8787/v1"
wire_api = "responses"
env_key = "ZHIPU_API_KEY"
env_key_instructions = "Set ZHIPU_API_KEY and restart the ChatGPT/Codex desktop app"
```

Expected: no model or Provider setting outside this new table changes.

- [ ] **Step 3: Verify configuration markers without reading credentials**

Run:

```powershell
$configText = Get-Content -LiteralPath 'C:\Users\YANG\.codex\config.toml' -Raw
if ($configText -notmatch '\[model_providers\.zhipu\]') { exit 1 }
if ($configText -notmatch 'env_key = "ZHIPU_API_KEY"') { exit 1 }
Write-Output 'zhipu provider configured'
```

Expected: `zhipu provider configured`.

### Task 3: Set the API key securely and start the adapter

**Files:**
- Read: `C:\Users\YANG\.codex\skills\create-glm-subagent\scripts\adapter\server.mjs`

**Interfaces:**
- Consumes: Windows user environment variable `ZHIPU_API_KEY`
- Produces: healthy local Responses endpoint at `http://127.0.0.1:8787/v1`

- [ ] **Step 1: Have the user set the key without echoing it**

The user runs this in PowerShell:

```powershell
$secureKey = Read-Host '粘贴智谱 API Key' -AsSecureString
$keyPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
try {
  $plainKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPtr)
  [Environment]::SetEnvironmentVariable('ZHIPU_API_KEY', $plainKey, 'User')
} finally {
  if ($keyPtr -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPtr)
  }
  Remove-Variable plainKey -ErrorAction SilentlyContinue
  Remove-Variable secureKey -ErrorAction SilentlyContinue
}
```

Expected: no key value is printed. The user completely exits and reopens Codex so it inherits the new environment.

- [ ] **Step 2: Verify only that the key exists**

Run:

```powershell
$configured = [Environment]::GetEnvironmentVariable('ZHIPU_API_KEY', 'User')
if ([string]::IsNullOrWhiteSpace($configured)) { exit 1 }
Remove-Variable configured
Write-Output 'Key configured'
```

Expected: `Key configured`; no secret value appears.

- [ ] **Step 3: Start the adapter from the project root**

Run the adapter in a hidden background process with working directory `J:\claude\开发项目\斗地主APP`:

```powershell
$nodePath = (Get-Command node -ErrorAction Stop).Source
$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $nodePath
$startInfo.Arguments = '"C:\Users\YANG\.codex\skills\create-glm-subagent\scripts\adapter\server.mjs"'
$startInfo.WorkingDirectory = 'J:\claude\开发项目\斗地主APP'
$startInfo.UseShellExecute = $true
$startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
$adapterProcess = [System.Diagnostics.Process]::Start($startInfo)
Write-Output "Adapter PID: $($adapterProcess.Id)"
```

Expected: a numeric PID is printed and the process remains running.

- [ ] **Step 4: Verify adapter health without exposing the key**

Run:

```powershell
$health = Invoke-RestMethod -Uri 'http://127.0.0.1:8787/health'
if ($health.status -ne 'ok') { exit 1 }
if (-not $health.key_configured) { exit 1 }
Write-Output 'Adapter healthy'
```

Expected: `Adapter healthy`.

### Task 4: Create and execute the read-only smoke task

**Files:**
- Create, ignored: `.codex/glm-task.json`
- Create temporarily: `C:\tmp\glm-readonly-smoke-task.txt`

**Interfaces:**
- Consumes: `set_task.py --project-root --task-file`
- Produces: a pending plaintext relay task consumed by the registered `developer` Agent

- [ ] **Step 1: Create the exact smoke-task body**

Create `C:\tmp\glm-readonly-smoke-task.txt` with:

```text
目标：只读检查斗地主项目并列出 lib 与 test 下的文件。
限制：不得创建、修改、移动或删除任何文件；不得安装依赖；不得提交或推送。
允许修改的文件：无。
验收标准：报告 lib 与 test 下的文件清单，并明确说明没有产生文件改动。
```

- [ ] **Step 2: Write a new relay task**

Run:

```powershell
python 'C:\Users\YANG\.codex\skills\create-glm-subagent\scripts\set_task.py' `
  --project-root 'J:\claude\开发项目\斗地主APP' `
  --task-file 'C:\tmp\glm-readonly-smoke-task.txt'
```

Expected: JSON output contains a new `task-...` ID and `.codex\glm-task.json`.

- [ ] **Step 3: Dispatch the registered `developer` custom Agent**

From a Codex task opened after the configuration reload, dispatch the project Agent named `developer` and instruct it to execute the authoritative `[GLM_TASK_RELAY ...]` task.

Expected: the Agent reports the `lib` and `test` file list and makes no edits. If `developer` is not selectable, stop and restart Codex rather than dispatching a generic Agent.

- [ ] **Step 4: Verify no smoke-task edits**

Run:

```powershell
git status --short
```

Expected: only the intended Agent configuration and planning files appear; no application source or test file changed.

- [ ] **Step 5: Verify routing from adapter debug metadata**

Restart the adapter with `GLM_ADAPTER_DEBUG=1`, repeat the smoke dispatch, and inspect only the request summary.

Expected: the summary contains `"model":"glm-5.2"` and does not print the API key or task body.

### Task 5: Verify write access and Flutter testing

**Files:**
- Create temporarily: `.codex/glm-write-smoke.txt`
- Modify: `.codex/glm-task.json`

**Interfaces:**
- Consumes: the verified `developer` Agent and task relay
- Produces: evidence that workspace writes and project test commands work

- [ ] **Step 1: Relay the exact minimal-write task**

Task body:

```text
目标：验证当前项目的受限写入权限与测试执行能力。
限制：除指定临时文件外不得修改任何文件；不得安装依赖；不得提交或推送。
允许修改的文件：.codex/glm-write-smoke.txt。
验收标准：创建该文件且内容精确为 GLM workspace write verified；随后在 doudizhu_app 目录运行 flutter test，并报告命令、退出码和测试摘要。
```

Write it with `set_task.py`, using a new generated task ID, then dispatch the registered `developer` Agent.

Expected: `.codex/glm-write-smoke.txt` exists with the exact content and the Agent reports the Flutter test result.

- [ ] **Step 2: Independently verify the file and tests**

Run:

```powershell
$content = Get-Content -LiteralPath '.codex\glm-write-smoke.txt' -Raw
if ($content.Trim() -ne 'GLM workspace write verified') { exit 1 }
Push-Location 'doudizhu_app'
try {
  flutter test
} finally {
  Pop-Location
}
```

Expected: content check passes and `flutter test` exits `0`.

- [ ] **Step 3: Remove only the approved temporary artifacts**

Delete:

```text
.codex/glm-write-smoke.txt
C:\tmp\glm-readonly-smoke-task.txt
```

Then mark `.codex/glm-task.json` status as `done`.

Expected: neither temporary file remains; the ignored relay records `status: "done"`.

- [ ] **Step 4: Run the setup checker**

Run:

```powershell
python 'C:\Users\YANG\.codex\skills\create-glm-subagent\scripts\check_setup.py' `
  --project-root 'J:\claude\开发项目\斗地主APP' `
  --name developer
```

Expected: all five JSON values are `true` and the command exits `0`.

### Task 6: Review and commit project configuration

**Files:**
- Commit: `.codex/agents/developer.toml`
- Commit: `AGENTS.md`
- Commit: `.gitignore`
- Do not commit: `.codex/glm-task.json`
- Do not commit: `C:\Users\YANG\.codex\config.toml`

**Interfaces:**
- Consumes: passing setup checks, smoke checks, and Flutter tests
- Produces: a reviewable project commit containing only durable Agent configuration

- [ ] **Step 1: Review final status and diff**

Run:

```powershell
git status --short
git diff --check
git diff -- '.codex/agents/developer.toml' 'AGENTS.md' '.gitignore'
```

Expected: no application source changes, no task relay, no secret, and no whitespace errors.

- [ ] **Step 2: Scan staged candidates for secret-like content**

Run:

```powershell
rg -n 'ZHIPU_API_KEY\s*=|Bearer\s+[A-Za-z0-9_-]{16,}|api[_-]?key\s*=' '.codex\agents\developer.toml' 'AGENTS.md' '.gitignore'
```

Expected: no output. The literal environment-variable name may appear only as documentation, never with a value.

- [ ] **Step 3: Commit the durable project configuration**

Run:

```powershell
git add -- '.codex/agents/developer.toml' 'AGENTS.md' '.gitignore'
git commit -m 'chore: add GLM developer subagent'
```

Expected: one commit containing exactly the three durable project files.
