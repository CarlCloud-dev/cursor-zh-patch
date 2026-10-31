# Cursor 界面简体中文汉化补丁
# 用法:双击"一键汉化.bat",或 powershell -File apply-zh.ps1 [-InstallDir <Cursor安装目录>]
# 幂等:已打补丁则跳过/重放,可重复执行;Cursor 更新后重跑一次即可恢复中文。
param([string]$InstallDir = "")
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$pkg = $PSScriptRoot

function Find-Cursor {
    if ($InstallDir -and (Test-Path (Join-Path $InstallDir 'resources\app\out\nls.messages.json'))) {
        return (Resolve-Path $InstallDir).Path
    }
    foreach ($c in @(
        'E:\Cursor',
        "$env:LOCALAPPDATA\Programs\cursor",
        "$env:LOCALAPPDATA\Programs\Cursor",
        "$env:ProgramFiles\Cursor",
        "$env:ProgramFiles\cursor",
        'D:\Cursor','C:\Cursor'
    )) { if (Test-Path (Join-Path $c 'resources\app\out\nls.messages.json')) { return $c } }
    # 兜底1:从正在运行的 Cursor.exe 进程反推安装目录
    $proc = Get-CimInstance Win32_Process -Filter "Name='Cursor.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.ExecutablePath -like '*\Cursor.exe' } | Select-Object -First 1
    if ($proc) {
        $cand = Join-Path (Split-Path $proc.ExecutablePath) 'resources\app'
        if (Test-Path (Join-Path $cand 'out\nls.messages.json')) { return (Split-Path $proc.ExecutablePath) }
    }
    # 兜底2:注册表卸载条目
    foreach ($rk in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        foreach ($h in (Get-ItemProperty $rk -ErrorAction SilentlyContinue |
                 Where-Object { $_.DisplayName -match 'Cursor' })) {
            $base = $h.InstallLocation
            if (-not $base -and $h.DisplayIcon) { $base = Split-Path ($h.DisplayIcon -replace '"','') }
            if ($base -and (Test-Path (Join-Path $base 'resources\app\out\nls.messages.json'))) { return $base }
        }
    }
    throw "找不到 Cursor 安装目录,请用 -InstallDir 参数指定"
}

$root = Find-Cursor
$appDir = Join-Path $root 'resources\app'
Write-Host "[*] Cursor 安装目录: $root"

# ---------- 1. workbench 内核层:替换 nls.messages.json ----------
$nlsDst = Join-Path $appDir 'out\nls.messages.json'
$nlsSrc = Join-Path $pkg 'nls.messages.zh.json'
$cur = [IO.File]::ReadAllText($nlsDst, $utf8)
if ($cur.Contains('更多操作...') -and $cur.Contains('确定')) {
    Write-Host '[=] nls.messages.json 已是中文,跳过'
} else {
    if (-not (Test-Path "$nlsDst.zhorig")) { Copy-Item $nlsDst "$nlsDst.zhorig" }
    Copy-Item $nlsSrc $nlsDst -Force
    Write-Host '[+] 已汉化 nls.messages.json (workbench 内核)'
}

# ---------- 2. molten AI 界面层:按字典替换带引号的 UI 字面量 ----------
Add-Type -AssemblyName System.Web.Extensions
$dict = (New-Object System.Web.Script.Serialization.JavaScriptSerializer).DeserializeObject(
          [IO.File]::ReadAllText((Join-Path $pkg 'molten-zh-map.json'), $utf8))
Write-Host "[*] molten 替换字典: $($dict.Count) 条"

$moltenDir = Join-Path $appDir 'molten\dist'
$totalRepl = 0; $patched = 0
Get-ChildItem $moltenDir -Recurse -Filter '*.js' | ForEach-Object {
    $f = $_.FullName
    $bak = "$f.zhorig"
    if (Test-Path $bak) { Copy-Item $bak $f -Force }   # 已打过:先还原再重放(字典可能更新)
    $s = [IO.File]::ReadAllText($f, $utf8)
    $orig = $s
    foreach ($en in $dict.Keys) {
        $zh = $dict[$en]
        foreach ($q in '"', "'", '`') {
            $old = "$q$en$q"; $new = "$q$zh$q"
            if ($s.Contains($old)) { $s = $s.Replace($old, $new) }
        }
    }
    if ($s -ne $orig) {
        if (-not (Test-Path $bak)) { Copy-Item $f $bak }
        [IO.File]::WriteAllText($f, $s, $utf8)
        $patched++
    }
}
Write-Host "[+] molten AI 界面:已汉化 $patched 个 bundle"

# ---------- 3. 校验 ----------
$ok = $true
$chk = [IO.File]::ReadAllText($nlsDst, $utf8)
if (-not $chk.Contains('更多操作...')) { $ok = $false; Write-Host '[!] 校验失败: nls.messages.json 未汉化' }
if ($ok) {
    Write-Host ''
    Write-Host '==== 汉化完成 ===='
    Write-Host '完全退出并重启 Cursor(顶部菜单栏由主进程在启动时加载,'
    Write-Host 'Reload Window 只重载渲染进程,不会刷新菜单)。'
}
