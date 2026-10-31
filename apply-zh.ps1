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
$outDir = Join-Path $appDir 'out'
Write-Host "[*] Cursor 安装目录: $root"

function Backup-Once($f) {
    if ((Test-Path $f) -and -not (Test-Path "$f.zhorig")) { Copy-Item $f "$f.zhorig" }
}

# ---------- 1. workbench 内核层:替换 nls.messages.json ----------
# VS Code 1.128: locale=en 时直接回退内嵌英文,不读此文件;
# 但 locale=zh-cn 且无语言包时会回退读它 -> 替换保证无包用户也能汉化。
$nlsDst = Join-Path $outDir 'nls.messages.json'
$nlsSrc = Join-Path $pkg 'nls.messages.zh.json'
$cur = [IO.File]::ReadAllText($nlsDst, $utf8)
if ($cur.Contains('更多操作...') -and $cur.Contains('确定')) {
    Write-Host '[=] nls.messages.json 已是中文,跳过'
} else {
    Backup-Once $nlsDst
    Copy-Item $nlsSrc $nlsDst -Force
    Write-Host '[+] 已汉化 nls.messages.json (workbench 内核)'
}

# ---------- 2. 语言包体系:locale=zh-cn + 注入官方包 + 刷新 clp 缓存 ----------
# 2a. argv.json: locale -> zh-cn
$argv = "$env:USERPROFILE\.cursor\argv.json"
if (Test-Path $argv) {
    $a = [IO.File]::ReadAllText($argv, $utf8)
    if ($a -match '"locale"\s*:\s*"zh-cn"') {
        Write-Host '[=] argv.json locale 已是 zh-cn'
    } else {
        Backup-Once $argv
        if ($a -match '"locale"\s*:\s*"[^"]+"') {
            $a = $a -replace '"locale"\s*:\s*"[^"]+"', '"locale": "zh-cn"'
        } else {
            # 无 locale 字段:在最后一个 } 前追加新字段
            $a = $a -replace '\}\s*$', ",`n`t`"locale`": `"zh-cn`"`n}"
        }
        [IO.File]::WriteAllText($argv, $a, $utf8)
        Write-Host '[+] argv.json: locale -> zh-cn'
    }
} else { Write-Host '[=] argv.json 不存在,跳过 locale 设置' }

# 2b. 已安装的官方 zh-hans 语言包:把缺失键的翻译注入 main.i18n.json
$extGlob = "$env:USERPROFILE\.cursor\extensions\ms-ceintl.vscode-language-pack-zh-hans-*\translations\main.i18n.json"
foreach ($packFile in (Get-Item $extGlob -ErrorAction SilentlyContinue)) {
    $pf = $packFile.FullName
    $packed = [IO.File]::ReadAllText($pf, $utf8)
    if ($packed.Contains('"vs/code/electron-main/menus"') -and $packed.Contains('智能体宿主')) {
        Write-Host "[=] 语言包已含补译: $($packFile.Directory.Parent.Parent.Name),跳过"
        continue
    }
    Backup-Once $pf
    node -e @"
const fs=require('fs');
const keys=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));
const msgs=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const pack=JSON.parse(fs.readFileSync(process.argv[3],'utf8'));
const flat=[];for(const [mod,ks] of keys){for(const k of ks)flat.push([mod,typeof k==='string'?k:k.key]);}
let added=0;
for(let i=0;i<flat.length;i++){const[mod,k]=flat[i];
  if(pack.contents?.[mod]?.[k]!==undefined)continue;
  if(!pack.contents)pack.contents={};if(!pack.contents[mod])pack.contents[mod]={};
  pack.contents[mod][k]=msgs[i];added++;}
fs.writeFileSync(process.argv[3],JSON.stringify(pack,null,'\t'));
console.log('injected '+added);
"@ $outDir\nls.keys.json $nlsSrc $pf
    Write-Host "[+] 已注入补译到语言包: $($packFile.Directory.Parent.Parent.Name)"
}

# 2c. clp 语言包缓存:替换缓存的 nls.messages.json 为全量中文版
foreach ($clp in (Get-ChildItem "$env:APPDATA\Cursor\clp\*.zh-cn\*\nls.messages.json" -ErrorAction SilentlyContinue)) {
    Backup-Once $clp.FullName
    Copy-Item $nlsSrc $clp.FullName -Force
    Write-Host "[+] 已刷新 clp 缓存: $($clp.Name)"
}

# ---------- 3. molten AI 界面层:按字典替换带引号的 UI 字面量 ----------
Add-Type -AssemblyName System.Web.Extensions
$dict = (New-Object System.Web.Script.Serialization.JavaScriptSerializer).DeserializeObject(
          [IO.File]::ReadAllText((Join-Path $pkg 'molten-zh-map.json'), $utf8))
Write-Host "[*] molten 替换字典: $($dict.Count) 条"

$moltenDir = Join-Path $appDir 'molten\dist'
$patched = 0
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
        Backup-Once $f
        [IO.File]::WriteAllText($f, $s, $utf8)
        $patched++
    }
}
Write-Host "[+] molten AI 界面:已汉化 $patched 个 bundle"

# ---------- 4. 校验 ----------
$ok = $true
$chk = [IO.File]::ReadAllText($nlsDst, $utf8)
if (-not $chk.Contains('更多操作...')) { $ok = $false; Write-Host '[!] 校验失败: nls.messages.json 未汉化' }
if ($ok) {
    Write-Host ''
    Write-Host '==== 汉化完成 ===='
    Write-Host '完全退出并重启 Cursor(顶部菜单栏由主进程在启动时加载,'
    Write-Host 'Reload Window 只重载渲染进程,不会刷新菜单)。'
}
