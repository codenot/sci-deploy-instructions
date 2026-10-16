# 本机 Windows 软件与终端配置记录

记录日期：2026-10-16（Asia/Shanghai）。根据本机 Scoop 清单、PowerShell profile 和 Windows Terminal settings.json 只读采集；版本是采集时的本机快照，不代表上游最新版本。

## 1. 环境与路径

- 系统：Windows，注册表 DisplayVersion 为 `26H2`，构建号 `26300.9711`。注册表 ProductName 返回 `Windows 10 Pro`，此处保留原始字段，不据此推断系统营销名称。
- 日常终端：Windows Terminal，默认配置为 `PowerShell 7`。
- Shell：Scoop 安装的 PowerShell `7.6.6`（Core）。
- Scoop 根目录：`%USERPROFILE%\scoop`；命令入口：`%USERPROFILE%\scoop\shims`。
- Scoop 配置：`%USERPROFILE%\.config\scoop\config.json`。
- Git 当前命令来源：`C:\Programs\Git\cmd\git.exe`。当前 Scoop 已安装清单不含 Git；persist 中残留目录不等于软件仍已安装。
- Windows Terminal 不在当前 Scoop 清单中；其具体安装渠道未核实。

## 2. Scoop 软件清单

共 30 项。下表来自 `scoop list`，包含依赖包和字体，不能据此区分哪些是手动安装、哪些是自动依赖。

| 软件 | 已安装版本 | Bucket | 用途 |
|---|---|---|---|
| 7zip | 26.02 | main | 压缩与解压 |
| aria2 | 1.37.0-1 | main | 下载工具 |
| bat | 0.26.1 | main | 带语法高亮的文件查看 |
| cacert | 2026-08-13 | main | CA 证书包 |
| CascadiaCode-NF | 3.5.1 | nerd-fonts | Nerd Font 字体 |
| CascadiaCode-NF-Mono | 3.5.1 | nerd-fonts | 等宽 Nerd Font 字体 |
| cloc | 2.10 | main | 代码行数统计 |
| curl | 8.21.0_7 | main | HTTP 等协议客户端 |
| delta | 0.19.2 | main | diff 显示工具 |
| eza | 0.23.5 | main | 目录列表 |
| fd | 10.5.0 | main | 文件查找 |
| ffmpeg | 9.0.1 | main | 音视频处理 |
| fzf | 0.74.3 | main | 模糊搜索 |
| gh | 2.98.0 | main | GitHub CLI |
| go | 1.27.0 | main | Go 工具链 |
| hyperfine | 1.20.0 | main | 命令性能测试 |
| innounp | 2.71.1 | main | Inno Setup 解包 |
| jq | 1.8.2 | main | JSON 处理 |
| microsoft-coreutils | 2026.6.16 | main | 常用 Unix 风格命令 |
| neovim | 0.12.5 | main | 编辑器 |
| nexttrace | 1.7.3 | extras | 路由追踪 |
| oh-my-posh | 30.9.0 | main | 提示符主题 |
| pwsh | 7.6.6 | main | PowerShell 7 |
| ripgrep | 15.2.0 | main | 文本搜索（rg） |
| tokei | 12.1.2 | main | 代码统计 |
| uv | 0.12.7 | main | Python 项目与环境工具 |
| vim | 9.2.1025 | main | 编辑器 |
| wget | 1.21.4 | main | 下载工具 |
| yq | 4.53.6 | main | YAML 等结构化数据处理 |
| zoxide | 0.10.0 | main | 按访问记录跳转目录 |

已添加 Bucket：

| 名称 | 本机记录的源 |
|---|---|
| main | https://github.com/ScoopInstaller/Main.git |
| extras | https://github.com/ScoopInstaller/Extras |
| nerd-fonts | https://github.com/matthewjberger/scoop-nerd-fonts |

Scoop 配置中设置了本机代理 `127.0.0.1:7890`，仓库为 `https://github.com/ScoopInstaller/Scoop`、分支为 `master`。代理只表示 Scoop 配置，不能推断其他程序都使用它；迁移时按新机器实际代理端口调整。

## 3. Windows Terminal 配置

配置文件：`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`。

| 配置项 | 当前值或行为 |
|---|---|
| 默认配置 | PowerShell 7 |
| 启动命令 | `%USERPROFILE%\scoop\apps\pwsh\current\pwsh.exe` |
| 起始目录 | `%USERPROFILE%` |
| 全局字体 | `Cascadia Mono` |
| 选中即复制 | `copyOnSelect: true` |
| 复制格式 | `copyFormatting: none`，复制纯文本 |
| Ctrl+C | `Terminal.CopyToClipboard` |
| Ctrl+V | `Terminal.PasteFromClipboard` |
| Alt+Shift+D | `Terminal.DuplicatePaneAuto` |
| 自定义配色/主题 | `schemes` 和 `themes` 均为空 |

其余可见配置项包括 Windows PowerShell、命令提示符、Azure Cloud Shell、Ubuntu-24.04、自动发现的 PowerShell、Ubuntu-26.04。这些是终端配置条目，本次没有验证对应 WSL 发行版或云服务是否可用。

已安装的 Nerd Font 与实际选中的字体是两回事：当前 settings.json 使用 `Cascadia Mono`，没有显式选择上述 Nerd Font。若提示符或 eza 图标显示异常，可先检查终端字体选择。

## 4. PowerShell 7 配置

配置文件：`%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`。

`%USERPROFILE%\Documents\PowerShell\powershell.config.json` 内容为：

```json
{"Microsoft.PowerShell:ExecutionPolicy":"RemoteSigned"}
```

这是配置文件中的策略值；最终有效执行策略还可能受组策略或其他作用域影响，本次没有采集 `Get-ExecutionPolicy -List`。

### 输入、补全与快捷键

使用 PSReadLine；PowerShell 7 模块目录中版本为 `2.4.5`。

- 编辑模式：Emacs。
- 历史记录不重复显示，关闭提示音。
- 输出未重定向时启用历史预测，并以 ListView 展示。
- Tab：菜单补全（MenuComplete）。
- 上/下方向键：按当前输入搜索前/后历史。
- Ctrl+R：反向搜索历史。

### 命令别名

profile 将以下命令优先指向 Scoop shims 下对应的 `.exe`，仅当目标文件存在时设置：

```text
cat cp echo find hostname ls mkdir mv pwd rm rmdir sleep sort tee
```

因此这些短命令可能采用外部程序参数规则，而非 PowerShell 原生 cmdlet 语义；需要 PowerShell 行为时可显式使用 `Get-ChildItem`、`Get-Content`、`Remove-Item` 等完整名称。

### 提示符与目录跳转

- Oh My Posh：使用 Scoop 安装目录内的 `themes\powerlevel10k_lean.omp.json`。
- 仅在可执行文件、主题均存在且 `TERM` 不为 `dumb` 时初始化提示符。
- zoxide：目标程序存在时执行 `zoxide init powershell`，提供目录跳转集成。
- eza：命令存在时定义下表中的函数。

| 函数 | 实际命令 |
|---|---|
| ll | `eza --long --all --header --git --group-directories-first --icons=auto @args` |
| la | `eza --all --group-directories-first --icons=auto @args` |
| lt | `eza --tree --level=2 --group-directories-first --icons=auto @args` |

当前 profile 未配置 fzf、bat、delta 的 Shell/Git 集成，不能仅凭安装清单认定已经启用这些集成。

### 当前 profile 完整内容

以下为采集时的 PowerShell 7 profile，保留使用 `$HOME` 的可迁移路径：

```powershell
Import-Module PSReadLine

Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -HistoryNoDuplicates
Set-PSReadLineOption -BellStyle None

if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
}

Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Chord Ctrl+r -Function ReverseSearchHistory

# PowerShell aliases/functions and Windows executables otherwise take precedence over Scoop shims.
& {
    $coreutilsShimDirectory = Join-Path $HOME 'scoop\shims'
    $coreutilsAliases = @(
        'cat', 'cp', 'echo', 'find', 'hostname', 'ls', 'mkdir',
        'mv', 'pwd', 'rm', 'rmdir', 'sleep', 'sort', 'tee'
    )

    foreach ($name in $coreutilsAliases) {
        $target = Join-Path $coreutilsShimDirectory "$name.exe"
        if (Test-Path -LiteralPath $target) {
            Set-Alias -Name $name -Value $target -Scope Global -Option AllScope -Force
        }
    }
}

$ohMyPoshExe = Join-Path $HOME 'scoop\apps\oh-my-posh\current\oh-my-posh.exe'
$ohMyPoshTheme = Join-Path $HOME 'scoop\apps\oh-my-posh\current\themes\powerlevel10k_lean.omp.json'
$zoxideExe = Join-Path $HOME 'scoop\apps\zoxide\current\zoxide.exe'

if ((Test-Path -LiteralPath $ohMyPoshExe) -and (Test-Path -LiteralPath $ohMyPoshTheme) -and $env:TERM -ne 'dumb') {
    Invoke-Expression (& $ohMyPoshExe init pwsh --config $ohMyPoshTheme | Out-String)
}

if (Test-Path -LiteralPath $zoxideExe) {
    Invoke-Expression (& { (& $zoxideExe init powershell | Out-String) })
}

if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ll { eza --long --all --header --git --group-directories-first --icons=auto @args }
    function la { eza --all --group-directories-first --icons=auto @args }
    function lt { eza --tree --level=2 --group-directories-first --icons=auto @args }
}
```

## 5. Windows PowerShell 兼容配置

配置文件：`%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`。

此文件只导入 PSReadLine、设置 Emacs 模式，并按相同条件加载 Oh My Posh 的 `powerlevel10k_lean` 主题，初始化命令使用 `init powershell`。它没有 PowerShell 7 profile 中的历史预测设置、coreutils 别名、zoxide 和 eza 函数。

系统模块目录另有 PSReadLine `2.0.0`；Windows PowerShell 实际加载的版本本次未单独启动核实。

## 6. 日后备份与复查

迁移前备份上述两个 profile、`powershell.config.json`、Windows Terminal `settings.json` 及 Scoop 配置。覆盖新机器配置前先备份目标文件；Scoop 配置中的代理应按环境调整。

可在本机交互式 PowerShell 中复查：

```powershell
scoop list
scoop bucket list
scoop export
$PSVersionTable
$PROFILE | Select-Object *
Get-Module PSReadLine
Get-ExecutionPolicy -List
Get-Command pwsh, oh-my-posh, zoxide, eza, git
Get-Command cat, ls, rm | Select-Object Name, CommandType, Definition
```

`scoop export` 可用于另外保存机器可读的软件清单；本记录未生成独立导出文件。重装软件通常取当时 Bucket 提供的版本，不能保证恢复到本表的历史版本。字体、终端设置和 profile 需另行恢复。

首次采集仅新增记录文档及仓库入口，未修改本机软件、终端、执行策略或服务配置。2026-10-16 后续校正：通过 `scoop config proxy 127.0.0.1:7890` 将 Scoop 代理从误配的 `127.0.0.1:7897` 改为 `127.0.0.1:7890`，并回读确认。
