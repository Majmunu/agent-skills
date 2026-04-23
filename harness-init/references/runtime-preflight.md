# Runtime Preflight & Degraded Mode

加载时机：**Step 0 / Step 1 / Step 4 / Step 8**。

---

## Purpose

在初始化前先判定运行时能力，避免：
- 依赖不可执行程序导致流程中断
- 将未执行验证误报为成功
- 在不支持 `bash/git/node/python` 的环境中硬跑模板命令

---

## Capability Matrix

建议在 dry-run 与 init report 都输出：

| Capability | Status | Check Command | Notes |
|---|---|---|---|
| shell: bash/sh | available / unavailable | `command -v bash` | POSIX gate scripts |
| shell: pwsh | available / unavailable | `pwsh -NoProfile -Command "$PSVersionTable.PSVersion"` | Windows fallback |
| git | available / unavailable | `git --version` | diff / plan gate context |
| node | available / unavailable | `node --version` | JS checks |
| python | available / unavailable | `python3 --version` or `python --version` | yaml/json helpers |
| ripgrep | available / unavailable | `rg --version` | fast scan |

---

## Preflight Commands

### POSIX

```bash
check_cmd() { command -v "$1" >/dev/null 2>&1 && echo "available" || echo "unavailable"; }
echo "bash: $(check_cmd bash)"
echo "git: $(check_cmd git)"
echo "node: $(check_cmd node)"
echo "python3: $(check_cmd python3)"
echo "rg: $(check_cmd rg)"
```

### PowerShell

```powershell
function Test-Cmd([string]$Name) {
  if (Get-Command $Name -ErrorAction SilentlyContinue) { 'available' } else { 'unavailable' }
}
"pwsh: available"
"git: $(Test-Cmd git)"
"bash: $(Test-Cmd bash)"
"node: $(Test-Cmd node)"
"python: $(if (Get-Command python -ErrorAction SilentlyContinue) { 'available' } elseif (Get-Command python3 -ErrorAction SilentlyContinue) { 'available' } else { 'unavailable' })"
"rg: $(Test-Cmd rg)"
```

---

## Degraded Mode Rules

触发条件：任一关键依赖不可用（例如 `git`、`bash`、`node`、`python`）。

行为要求：
1. 不阻塞文档和骨架初始化。
2. 优先使用等效命令（PowerShell 或内置命令）。
3. 所有验证结果必须标注状态：`pass|fail|warn|not-run`。
4. `not-run` 必须记录：
   - 未执行命令
   - 不可执行原因
   - 残余风险

禁止事项：
- 禁止把 `not-run` 写成 `pass`
- 禁止 silent fallback

---

## Shell Fallback Mapping

| Task | POSIX | PowerShell |
|---|---|---|
| run boundary gate | `bash .harness/scripts/check-boundaries.sh` | `pwsh -File .harness/scripts/check-boundaries.ps1` |
| run validate gate | `bash .harness/scripts/validate.sh` | `pwsh -File .harness/scripts/validate.ps1` |
| grep text | `grep -R` | `Select-String` |
| list files | `find` | `Get-ChildItem -Recurse` |
| command exists | `command -v` | `Get-Command` |

说明：
- 若仓库仅有 `.sh` 且 CI 运行在 Linux，可保留 `.sh` 作为 canonical。
- 若用户环境长期无 `bash`，建议补 `.ps1` wrapper 到同目录，并在导航文档写明双入口。
