# 还原:把 .zhorig 备份盖回原文件(覆盖安装目录+用户目录所有补丁点)
param([string]$InstallDir = "")
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}
$ErrorActionPreference = 'Stop'

function Find-Cursor {
    if ($InstallDir -and (Test-Path (Join-Path $InstallDir 'resources\app'))) {
        return (Resolve-Path $InstallDir).Path
    }
    foreach ($c in @(
        'E:\Cursor',
        "$env:LOCALAPPDATA\Programs\cursor",
        "$env:LOCALAPPDATA\Programs\Cursor",
        "$env:ProgramFiles\Cursor",
        "$env:ProgramFiles\cursor",
        'D:\Cursor','C:\Cursor'
    )) { if (Test-Path (Join-Path $c 'resources\app')) { return $c } }
    $proc = Get-CimInstance Win32_Process -Filter "Name='Cursor.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.ExecutablePath -like '*\Cursor.exe' } | Select-Object -First 1
    if ($proc) { return (Split-Path $proc.ExecutablePath) }
    foreach ($rk in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        foreach ($h in (Get-ItemProperty $rk -ErrorAction SilentlyContinue |
                 Where-Object { $_.DisplayName -match 'Cursor' })) {
            $base = $h.InstallLocation
            if (-not $base -and $h.DisplayIcon) { $base = Split-Path ($h.DisplayIcon -replace '"','') }
            if ($base -and (Test-Path (Join-Path $base 'resources\app'))) { return $base }
        }
    }
    throw '找不到 Cursor 安装目录'
}

$appDir = Join-Path (Find-Cursor) 'resources\app'
$roots = @()
$roots += $appDir                                             # 安装目录:nls + molten
$roots += "$env:APPDATA\Cursor\clp"                          # 语言包缓存
$roots += "$env:USERPROFILE\.cursor"                         # argv.json + extensions 语言包

# 版本保护:若 Cursor 在备份之后已更新,.zhorig 里是旧版本代码,恢复会新旧混用导致白屏。
# 版本不匹配时跳过安装目录内的备份(用户目录的 argv.json/clp 备份不受版本影响,仍可恢复)。
$verMarker = Join-Path $appDir '.zhpatch-version'
$curVer = ''
foreach ($vf in @((Join-Path $appDir 'product.json'), (Join-Path $appDir 'package.json'))) {
    if (Test-Path $vf) {
        try { $curVer = (Get-Content $vf -Raw | ConvertFrom-Json).version; if ($curVer) { break } } catch {}
    }
}
$prevVer = if (Test-Path $verMarker) { ([IO.File]::ReadAllText($verMarker)).Trim() } else { '' }
$verMismatch = ($curVer -and $prevVer -and $curVer -ne $prevVer)
if ($verMismatch) {
    Write-Host "[!] 检测到 Cursor 已更新 ($prevVer -> $curVer)"
    Write-Host '    旧版本备份已失效,跳过安装目录还原(当前文件已是新版英文原版,无需还原)'
}

$bak = @()
foreach ($r in $roots) {
    if (Test-Path $r) { $bak += @(Get-ChildItem $r -Recurse -Filter '*.zhorig' -ErrorAction SilentlyContinue) }
}
if ($verMismatch) { $bak = @($bak | Where-Object { -not $_.FullName.StartsWith($appDir) }) }
if (-not $bak) { Write-Host '没有需要还原的 .zhorig 备份文件'; exit }
foreach ($f in $bak) {
    $orig = $f.FullName -replace '\.zhorig$', ''
    Copy-Item $f.FullName $orig -Force
    Remove-Item $f.FullName -Force
    Write-Host "已还原 $($f.FullName)"
}
Write-Host '还原完成,重启 Cursor 生效'
