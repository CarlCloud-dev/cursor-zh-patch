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

$roots = @()
$roots += (Join-Path (Find-Cursor) 'resources\app')          # 安装目录:nls + molten
$roots += "$env:APPDATA\Cursor\clp"                          # 语言包缓存
$roots += "$env:USERPROFILE\.cursor"                         # argv.json + extensions 语言包

$bak = @()
foreach ($r in $roots) {
    if (Test-Path $r) { $bak += @(Get-ChildItem $r -Recurse -Filter '*.zhorig' -ErrorAction SilentlyContinue) }
}
if (-not $bak) { Write-Host '没有找到 .zhorig 备份文件'; exit }
foreach ($f in $bak) {
    $orig = $f.FullName -replace '\.zhorig$', ''
    Copy-Item $f.FullName $orig -Force
    Remove-Item $f.FullName -Force
    Write-Host "已还原 $($f.FullName)"
}
Write-Host '还原完成,重启 Cursor 生效'
