@echo off
setlocal EnableDelayedExpansion
title Duix.Avatar - Environment Check

rem ============================================================
rem  Duix.Avatar 环境自检脚本
rem  用法: 双击运行。结果同时显示在屏幕并写入同目录 check-report.txt
rem  目的: 输出结构化结果，供 AI Agent 或人工判断本机是否满足要求
rem ============================================================

set "REPORT=%~dp0check-report.txt"
set "PASS=0"
set "FAIL=0"
set "WARN=0"

> "%REPORT%" echo Duix.Avatar Environment Check Report
>>"%REPORT%" echo Generated at: %date% %time%
>>"%REPORT%" echo ============================================================
>>"%REPORT%" echo.

echo ============================================================
echo   Duix.Avatar - Environment Check
echo ============================================================
echo   Report file: %REPORT%
echo ============================================================
echo.

call :say "============================================================"
call :say "  Duix.Avatar 环境自检报告"
call :say "  时间: %date% %time%"
call :say "============================================================"
call :say ""

rem ---------- [1] OS version ----------
call :say "[1/8] 操作系统 ..."
for /f "tokens=4-5 delims=. " %%i in ('ver') do set "OSVER=%%i.%%j"
for /f "tokens=*" %%i in ('wmic os get Caption /value 2^>nul ^| find "="') do set "OSNAME=%%i"
set "OSNAME=!OSNAME:Caption=!"
set "OSNAME=!OSNAME:~1!"
call :detail "系统名称" "!OSNAME!"
call :detail "系统版本号" "%OSVER%"
rem Windows 10 requires build 19042.1526+
echo !OSVER! | findstr /r "^10\.0" >nul
if not errorlevel 1 (
  call :note "Windows 10/11 - 满足最低版本要求"
) else (
  call :note "无法自动判定版本，请人工确认 Windows 10 19042.1526 或更高"
)
call :say ""

rem ---------- [2] CPU / RAM ----------
call :say "[2/8] CPU 与内存 ..."
set "CPUNAME="
for /f "tokens=2 delims==" %%i in ('wmic cpu get Name /value 2^>nul ^| find "="') do if not defined CPUNAME set "CPUNAME=%%i"
set "CPUCORE="
for /f "tokens=2 delims==" %%i in ('wmic cpu get NumberOfLogicalProcessors /value 2^>nul ^| find "="') do if not defined CPUCORE set "CPUCORE=%%i"
set "RAMGB="
for /f "tokens=2 delims==" %%i in ('wmic computersystem get TotalPhysicalMemory /value 2^>nul ^| find "="') do if not defined RAMGB set "RAMGB=%%i"
set /a RAMGB=%RAMGB%/1073741824
call :detail "CPU" "!CPUNAME!"
call :detail "逻辑核心数" "!CPUCORE!"
call :detail "物理内存" "!RAMGB! GB"
if !RAMGB! GEQ 32 (
  call :note "内存充足（推荐 32GB 及以上）"
) else if !RAMGB! GEQ 16 (
  call :warn "内存 16-31GB：可以运行，但 ASR 服务可能启动较慢或不稳"
) else (
  call :err "内存不足 16GB：无法可靠运行，请先升级内存"
)
call :say ""

rem ---------- [3] NVIDIA GPU + driver ----------
call :say "[3/8] NVIDIA 显卡与驱动 ..."
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader > "%TEMP%\duix_gpu.txt" 2>&1
if errorlevel 1 (
  call :err "未检测到 NVIDIA 显卡或驱动未安装"
  call :note "本项目所有算力都在本地，必须有 NVIDIA 显卡 + 正确驱动"
  call :note "驱动下载: https://www.nvidia.cn/drivers/lookup/"
  call :say ""
  set "GPUOK=0"
) else (
  set "GPUOK=1"
  set "GPUINFO="
  set /p GPUINFO=<"%TEMP%\duix_gpu.txt"
  call :detail "显卡信息" "!GPUINFO!"
  call :note "格式: 显卡型号, 显存总量, 驱动版本"
  rem parse VRAM (second field, MiB)
  for /f "tokens=1,2,3 delims=," %%a in ("!GPUINFO!") do (
    set "GPUMODEL=%%a"
    set "VRAMRAW=%%b"
  )
  set "VRAMRAW=!VRAMRAW:MiB=!"
  set "VRAMRAW=!VRAMRAW: =!"
  set /a VRAMGB=!VRAMRAW!/1024
  call :detail "显存换算" "约 !VRAMGB! GB"
  if !VRAMGB! GEQ 12 (
    call :note "显存充足（12GB+，可跑完整三服务方案）"
  ) else if !VRAMGB! GEQ 8 (
    call :warn "显存 8-11GB：可用，但建议改用 lite 方案（仅 gen-video 服务）"
  ) else (
    call :err "显存不足 8GB：无法运行，建议更换显卡"
  )
  call :say ""
)

rem ---------- [4] Disk space ----------
call :say "[4/8] 磁盘空间 ..."
set "DOK=0"
set "FREED="
for /f "tokens=1,2,3" %%a in ('dir /-c 2^>nul ^| find "可用字节"') do set "FREED=%%c"
rem reliable way: use wmic logicaldisk
set "C_FREE="
set "D_FREE="
for /f "tokens=1,2 delims==" %%a in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /value 2^>nul ^| find "="') do set "C_FREEB=%%b"
for /f "tokens=1,2 delims==" %%a in ('wmic logicaldisk where "DeviceID='D:'" get FreeSpace /value 2^>nul ^| find "="') do set "D_FREEB=%%b"
if defined C_FREEB set /a C_FREE=!C_FREEB!/1073741824
if not defined C_FREE set "C_FREE=0"
call :detail "C 盘可用空间" "!C_FREE! GB"
if !C_FREE! GEQ 150 (
  call :note "C 盘空间充足（镜像需约 110GB + 余量）"
) else if !C_FREE! GEQ 110 (
  call :note "C 盘空间刚好够用（约 110GB），建议清理后继续"
) else (
  call :warn "C 盘不足 110GB：Docker 镜像会占满，需迁移镜像目录或其他盘"
)
if defined D_FREEB (
  set /a D_FREE=!D_FREEB!/1073741824
  set "DOK=1"
  call :detail "D 盘可用空间" "!D_FREE! GB"
  if !D_FREE! GEQ 40 (
    call :note "D 盘空间充足（数据目录需 30GB+）"
  ) else (
    call :warn "D 盘不足 40GB，数据目录建议预留 30GB 以上"
  )
) else (
  call :err "未检测到 D 盘：Duix.Avatar 强制要求 D 盘存放数据"
  call :note "解决方案二选一："
  call :note "  a) 新建 D 分区"
  call :note "  b) 用 subst 把某个盘映射为 D: （需设为开机自启）"
  call :note "     命令示例: subst D: F:\\DuixData"
)
call :say ""

rem ---------- [5] WSL ----------
call :say "[5/8] WSL2 ..."
wsl --status >nul 2>&1
if not errorlevel 1 (
  call :note "WSL 已安装"
  for /f "tokens=*" %%i in ('wsl --list --verbose 2^>nul') do (
    echo %%i | findstr /i "Ubuntu docker" >nul
    if not errorlevel 1 call :detail "WSL 发行版" "%%i"
  )
) else (
  call :warn "WSL 未安装或未启用"
  call :note "安装命令（管理员 PowerShell）: wsl --install"
  call :note "安装后需重启，并设置用户名和密码"
)
call :say ""

rem ---------- [6] Docker ----------
call :say "[6/8] Docker Desktop ..."
set "DOCKER_HOME="
if exist "%LOCALAPPDATA%\Programs\DockerDesktop\Docker Desktop.exe" set "DOCKER_HOME=%LOCALAPPDATA%\Programs\DockerDesktop"
if not defined DOCKER_HOME if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" set "DOCKER_HOME=%ProgramFiles%\Docker\Docker"
if not defined DOCKER_HOME if exist "%ProgramFiles%\Docker\Docker Desktop.exe" set "DOCKER_HOME=%ProgramFiles%\Docker"
if defined DOCKER_HOME (
  call :note "Docker Desktop 已安装: !DOCKER_HOME!"
) else (
  call :warn "未找到 Docker Desktop 安装"
  call :note "下载: https://www.docker.com/"
)
docker version >nul 2>&1
if not errorlevel 1 (
  set "DVER="
  for /f "tokens=*" %%i in ('docker version --format "{{.Server.Version}}" 2^>nul') do set "DVER=%%i"
  call :note "Docker 引擎正在运行 (Server !DVER!)"
) else (
  call :warn "Docker 引擎未运行"
  call :note "请先启动 Docker Desktop，并确保左下角状态为绿色/Engine running"
)
rem check nvidia runtime for docker
docker info 2>nul | findstr /i "nvidia" >nul
if not errorlevel 1 (
  call :note "Docker 已识别 NVIDIA runtime"
) else (
  docker info >nul 2>&1
  if not errorlevel 1 call :warn "Docker 未识别 NVIDIA runtime，GPU 容器可能起不来"
)
call :say ""

rem ---------- [7] Images ----------
call :say "[7/8] 数字人镜像 ..."
docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}" 2>nul | findstr /i "guiji2025" >nul
if not errorlevel 1 (
  call :note "已包含部分/全部数字人镜像:"
  for /f "tokens=*" %%i in ('docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}" 2^>nul ^| findstr /i "guiji2025"') do call :detail "  镜像" "%%i"
) else (
  call :warn "尚未拉取数字人镜像（共约 110GB，首次需下载）"
  call :note "所需镜像:"
  call :note "  guiji2025/duix.avatar        (约 15GB)"
  call :note "  guiji2025/fun-asr            (约 42GB)"
  call :note "  guiji2025/fish-speech-ziming (约 52GB)"
)
call :say ""

rem ---------- [8] Ports ----------
call :say "[8/8] 端口占用检查 ..."
set "PORTOK=1"
for %%p in (8383 10095 18180) do (
  netstat -ano 2>nul | findstr ":%%p " | findstr "LISTENING" >nul
  if not errorlevel 1 (
    call :warn "端口 %%p 已被占用 - 若已有数字人容器在跑则为正常"
    set "PORTOK=0"
  ) else (
    call :detail "端口 %%p" "空闲"
  )
)
call :say ""

rem ---------- Summary ----------
call :say "============================================================"
call :say "  自检结果汇总"
call :say "============================================================"
call :detail "[ERROR] 致命问题" "!FAIL!"
call :detail "[WARN]  警告项" "!WARN!"
call :detail "[INFO]  通过项" "!PASS!"
call :say ""
if !FAIL! GTR 0 (
  call :say "结论: 环境不满足要求，请先解决 ERROR 项后再安装。"
) else if !WARN! GTR 0 (
  call :say "结论: 基本满足要求，存在需要注意的警告项，建议按提示优化。"
) else (
  call :say "结论: 环境完全满足要求，可以开始安装。"
)
call :say ""
call :say "完整报告已写入: %REPORT%"
call :say "请把该文件内容提供给 AI Agent 以继续安装流程。"
call :say ""
>>"%REPORT%" echo.
>>"%REPORT%" echo ============================================================
>>"%REPORT%" echo SUMMARY: ERROR=%FAIL%  WARN=%WARN%  INFO=%PASS%
>>"%REPORT%" echo ============================================================
echo.
echo 按任意键退出 ...
pause >nul
exit /b 0

rem ============================================================
rem  helper routines
rem ============================================================
:detail
call :say "    %~1 : %~2"
>>"%REPORT%" echo   %~1 : %~2
exit /b 0

:note
call :say "        -> %~1"
>>"%REPORT%" echo          %~1
set /a PASS+=1
exit /b 0

:warn
call :say "        !! %~1"
>>"%REPORT%" echo          [WARN] %~1
set /a WARN+=1
exit /b 0

:err
call :say "        XX %~1"
>>"%REPORT%" echo          [ERROR] %~1
set /a FAIL+=1
exit /b 0

:say
echo %~1
>>"%REPORT%" echo %~1
exit /b 0
