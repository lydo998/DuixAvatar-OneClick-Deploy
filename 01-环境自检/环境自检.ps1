﻿# ============================================================
#  Duix.Avatar 环境自检脚本 (PowerShell 版)
#  用法: 右键"使用 PowerShell 运行"，或
#        powershell -ExecutionPolicy Bypass -File 环境自检.ps1
#  输出: 屏幕 + 同目录 check-report.txt
# ============================================================

$ErrorActionPreference = "SilentlyContinue"
$OutFile = Join-Path $PSScriptRoot "check-report.txt"
$script:Pass = 0
$script:Warn = 0
$script:Fail = 0

function Write-Out {
    param([string]$Text, [string]$Color = "Gray")
    Write-Host $Text -ForegroundColor $Color
    Add-Content -Path $OutFile -Value $Text -Encoding UTF8
}
function Add-Pass { param([string]$m) Write-Out "        [OK] $m" "Green";  $script:Pass++ }
function Add-Warn { param([string]$m) Write-Out "        [WARN] $m" "Yellow"; $script:Warn++ }
function Add-Fail { param([string]$m) Write-Out "        [ERROR] $m" "Red";   $script:Fail++ }
function Add-Detail { param([string]$k, [string]$v) Write-Out "    $k : $v" "White" }

"Duix.Avatar Environment Check Report" | Set-Content -Path $OutFile -Encoding UTF8
Add-Content -Path $OutFile -Value ("Generated at: " + (Get-Date)) -Encoding UTF8
Add-Content -Path $OutFile -Value ("Host: " + $env:COMPUTERNAME + "  User: " + $env:USERNAME) -Encoding UTF8
Add-Content -Path $OutFile -Value "============================================================" -Encoding UTF8

Write-Out ""
Write-Out "============================================================" "Cyan"
Write-Out "  Duix.Avatar - Environment Check (PowerShell)" "Cyan"
Write-Out "  Report: $OutFile" "Cyan"
Write-Out "============================================================" "Cyan"
Write-Out ""

# ---------- [1] OS ----------
Write-Out "[1/8] 操作系统 ..." "Cyan"
$os = Get-CimInstance Win32_OperatingSystem
Add-Detail "系统名称" $os.Caption
Add-Detail "版本" ($os.Version + "  Build " + $os.BuildNumber)
if ([int]$os.BuildNumber -ge 19042) { Add-Pass "系统版本满足要求 (Win10 19042+ / Win11)" }
else { Add-Fail "系统版本过低，需要 Windows 10 Build 19042.1526 或更高" }
$arch = $os.OSArchitecture
Add-Detail "架构" $arch
Write-Out ""

# ---------- [2] CPU / RAM ----------
Write-Out "[2/8] CPU 与内存 ..." "Cyan"
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
Add-Detail "CPU" $cpu.Name
Add-Detail "物理核心 / 逻辑核心" ("$($cpu.NumberOfCores) / $($cpu.NumberOfLogicalProcessors)")
$ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 0)
Add-Detail "物理内存" "$ramGB GB"
if ($ramGB -ge 32) { Add-Pass "内存充足（推荐 32GB+）" }
elseif ($ramGB -ge 16) { Add-Warn "内存 $ramGB GB：可运行，但 ASR 服务可能启动慢或不稳" }
else { Add-Fail "内存 $ramGB GB 不足 16GB，无法可靠运行" }
Write-Out ""

# ---------- [3] GPU ----------
Write-Out "[3/8] NVIDIA 显卡与驱动 ..." "Cyan"
$smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if (-not $smi) {
    Add-Fail "未找到 nvidia-smi：未安装 NVIDIA 驱动或无 N 卡"
    Add-Warn "本项目算力全在本地，必须有 NVIDIA 显卡且驱动正确"
    Add-Warn "驱动下载: https://www.nvidia.cn/drivers/lookup/"
} else {
    $gpuCsv = & nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv,noheader 2>$null
    if ($LASTEXITCODE -eq 0 -and $gpuCsv) {
        $i = 0
        foreach ($line in $gpuCsv) {
            $i++
            $parts = $line -split ","
            $name   = $parts[0].Trim()
            $vramMi = ($parts[1] -replace "[^\d]", "")
            $drv    = $parts[2].Trim()
            $cc     = if ($parts.Count -gt 3) { $parts[3].Trim() } else { "?" }
            $vramGB = [math]::Round([int]$vramMi / 1024, 0)
            Add-Detail "GPU #$i" $name
            Add-Detail "  显存" "$vramGB GB"
            Add-Detail "  驱动" $drv
            Add-Detail "  算力(CUDA Capability)" $cc
            if ($vramGB -ge 12) { Add-Pass "GPU #$i 显存充足（$vramGB GB），可跑完整三服务方案" }
            elseif ($vramGB -ge 8) { Add-Warn "GPU #$i 显存 $vramGB GB 偏小，建议用 lite 方案（仅 gen-video）" }
            else { Add-Fail "GPU #$i 显存仅 $vramGB GB，不足 8GB，无法运行" }
            if ($cc -match "^(\d+)\.") {
                $major = [int]$Matches[1]
                if ($major -ge 12) { Add-Detail "  备注" "50 系/新架构，服务端请用 docker-compose-5090.yml" }
            }
        }
    } else {
        Add-Fail "nvidia-smi 无法获取显卡信息，驱动可能异常"
    }
}
Write-Out ""

# ---------- [4] Disk ----------
Write-Out "[4/8] 磁盘空间 ..." "Cyan"
$vols = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
$cFreeGB = 0; $dFreeGB = -1
foreach ($v in $vols) {
    $freeGB = [math]::Round($v.FreeSpace / 1GB, 0)
    $totGB  = [math]::Round($v.Size / 1GB, 0)
    $letter = $v.DeviceID
    Add-Detail "$letter 可用/总计" "$freeGB GB / $totGB GB"
    if ($letter -eq "C:") { $cFreeGB = $freeGB }
    if ($letter -eq "D:") { $dFreeGB = $freeGB }
}
if ($cFreeGB -ge 150) { Add-Pass "C 盘空间充足（$cFreeGB GB）" }
elseif ($cFreeGB -ge 110) { Add-Warn "C 盘约 $cFreeGB GB，刚够镜像（110GB），建议清理" }
else { Add-Fail "C 盘仅 $cFreeGB GB，不足 110GB，Docker 镜像会占满" }
if ($dFreeGB -ge 0) {
    if ($dFreeGB -ge 40) { Add-Pass "D 盘空间充足（$dFreeGB GB）" }
    else { Add-Warn "D 盘仅 $dFreeGB GB，建议预留 30GB+" }
} else {
    Add-Fail "未检测到 D 盘：Duix.Avatar 强制要求 D 盘存数据"
    Add-Warn "解决: 新建 D 分区，或用 subst 映射（需开机自启）"
    Add-Warn "  示例: subst D: F:\DuixData"
}
Write-Out ""

# ---------- [5] WSL ----------
Write-Out "[5/8] WSL2 ..." "Cyan"
$wslExe = Join-Path $env:SystemRoot "System32\wsl.exe"
if (Test-Path $wslExe) {
    # 通过文件版本判断是否真正安装（避免直接调用可能被安全策略拦截）
    $wslVer = (Get-Item $wslExe).VersionInfo.FileVersion
    if (-not $wslVer) { $wslVer = "版本未知" }
    Add-Pass "WSL 已安装 (wsl.exe $wslVer)"
    # 检查 WSL 发行版：优先看注册表 LXSS 根路径，其次看 Packages 目录
    $distroFound = $false
    $lxssRoot = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss" -ErrorAction SilentlyContinue
    if ($lxssRoot) {
        $keys = Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss" -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -match "^\{.*\}$" }
        foreach ($k in $keys) {
            $nm = (Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue).DistributionName
            if ($nm) { Add-Detail "  已装发行版" $nm; $distroFound = $true }
        }
    }
    if (-not $distroFound) {
        $lxss = Join-Path $env:LOCALAPPDATA "Packages"
        $distros = Get-ChildItem $lxss -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -match "CanonicalGroupLimited|SUSE|Debian|Ubuntu|kali" }
        if ($distros) {
            foreach ($d in $distros) { Add-Detail "  已装发行版" $d.Name; $distroFound = $true }
        }
    }
    if (-not $distroFound) {
        # 若 Docker 已装且有 WSL2 后端，通常说明发行版存在但未登记
        Add-Warn "未发现已安装的 WSL 发行版（若 Docker Desktop 正常可用可忽略此项）"
        Add-Warn "如需初始化: wsl --install  然后重启"
    }
} else {
    Add-Warn "WSL 未安装或未启用"
    Add-Warn "安装（管理员 PowerShell）: wsl --install  然后重启"
}
Write-Out ""

# ---------- [6] Docker ----------
Write-Out "[6/8] Docker Desktop ..." "Cyan"
$candidates = @(
    "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe",
    "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
    "$env:ProgramFiles\Docker\Docker Desktop.exe"
)
$dockerExe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($dockerExe) {
    Add-Pass "Docker Desktop 已安装"
    Add-Detail "  路径" $dockerExe
} else {
    Add-Warn "未找到 Docker Desktop 安装"
    Add-Warn "下载: https://www.docker.com/"
}
$dv = & docker version --format "{{.Server.Version}}" 2>$null
if ($LASTEXITCODE -eq 0 -and $dv) {
    Add-Pass "Docker 引擎运行中 (Server $dv)"
    $info = & docker info 2>$null | Out-String
    if ($info -match "nvidia") { Add-Pass "Docker 已识别 NVIDIA runtime" }
    else { Add-Warn "Docker 未识别 NVIDIA runtime，GPU 容器可能无法启动" }
} else {
    Add-Warn "Docker 引擎未运行（启动 Docker Desktop 后再复检）"
}
Write-Out ""

# ---------- [7] Images ----------
Write-Out "[7/8] 数字人镜像 ..." "Cyan"
$imgs = & docker images --format "{{.Repository}}:{{.Tag}}|{{.Size}}" 2>$null | Where-Object { $_ -match "guiji2025" }
if ($imgs) {
    foreach ($i in $imgs) {
        $p = $i -split "\|"
        Add-Pass ("已有镜像 " + $p[0] + "  (" + $p[1] + ")")
    }
} else {
    Add-Warn "尚未拉取数字人镜像（共约 110GB，首次需下载）"
    Add-Warn "所需: guiji2025/duix.avatar (15GB) / fun-asr (42GB) / fish-speech-ziming (52GB)"
}
Write-Out ""

# ---------- [8] Ports ----------
Write-Out "[8/8] 端口占用 ..." "Cyan"
foreach ($p in 8383, 10095, 18180) {
    $inUse = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
    if ($inUse) {
        Add-Warn "端口 $p 已监听（若已有数字人容器运行则属正常）"
    } else {
        Add-Detail "端口 $p" "空闲"
    }
}
Write-Out ""

# ---------- Summary ----------
Write-Out "============================================================" "Cyan"
Write-Out "  自检结果汇总" "Cyan"
Write-Out "============================================================" "Cyan"
Add-Detail "[ERROR] 致命问题" $script:Fail
Add-Detail "[WARN]  警告项"  $script:Warn
Add-Detail "[INFO]  通过项"  $script:Pass
Write-Out ""
if ($script:Fail -gt 0) {
    Write-Out "结论: 环境不满足要求，请先解决 ERROR 项。" "Red"
} elseif ($script:Warn -gt 0) {
    Write-Out "结论: 基本满足要求，请注意 WARN 项并酌情优化。" "Yellow"
} else {
    Write-Out "结论: 环境完全满足要求，可以开始安装。" "Green"
}
Write-Out ""
Write-Out "完整报告: $OutFile" "Cyan"
Write-Out "请把该文件内容提供给 AI Agent 以继续安装。" "Cyan"
Write-Out ""

Add-Content -Path $OutFile -Value "============================================================" -Encoding UTF8
Add-Content -Path $OutFile -Value "SUMMARY: ERROR=$($script:Fail)  WARN=$($script:Warn)  INFO=$($script:Pass)" -Encoding UTF8

Write-Host "按回车键退出 ..." -ForegroundColor DarkGray
Read-Host
