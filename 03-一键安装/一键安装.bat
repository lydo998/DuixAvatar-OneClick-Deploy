@echo off
setlocal EnableDelayedExpansion
chcp 936 >nul 2>&1
title Duix.Avatar - One Click Install

rem ============================================================
rem  Duix.Avatar 一键安装脚本
rem  自动完成: D盘检查 -> Docker检查 -> 建数据目录 -> 拉镜像并启动
rem  日志: 同目录 install.log
rem ============================================================

cd /d "%~dp0"
set "LOG=%~dp0install.log"
set "REPO=%~dp0"
set "DATA=D:\duix_avatar_data"
set "COMPOSE=%REPO%docker-compose.yml"

> "%LOG%" echo Duix.Avatar install log
>>"%LOG%" echo Start: %date% %time%

echo ============================================================
echo   Duix.Avatar - 一键安装
echo ============================================================
echo.
echo 本脚本将自动:
echo   1. 检查 D 盘
echo   2. 检查 Docker 引擎
echo   3. 创建数据目录
echo   4. 拉取并启动 3 个数字人服务 (约 110GB, 需较长时间)
echo.
echo 按 Ctrl+C 可中止。
echo.
pause

rem ---------- [1/5] D drive ----------
echo.
echo [1/5] 检查 D 盘 ...
call :log "[1/5] D drive check"

set "DOK=0"
if exist "D:\" (
    set "DOK=1"
    echo       D 盘存在
    call :log "  D: exists"
) else (
    echo       X 未检测到 D 盘
    call :log "  D: NOT FOUND"

    rem try subst from F: if present
    if exist "F:\" (
        echo       尝试用 F 盘映射 D: ...
        subst D: "F:\DuixData" >nul 2>&1
        if exist "D:\" (
            set "DOK=1"
            echo       D: 已映射到 F:\DuixData
            call :log "  subst D: F:\DuixData  (OK)"
            call :warn_subst
        )
    )
    if "!DOK!"=="0" (
        echo.
        echo   X 无法自动解决 D 盘问题。
        echo.
        echo   请选择一种方式后重新运行:
        echo     a^) 用磁盘管理新建一个 D 分区
        echo     b^) 手动映射:  subst D: ^<某个空间充足的目录^>
        echo        并把它加入开机自启 ^(见说明书第 5 节^)
        echo.
        call :log "  FAILED: no D: drive"
        goto :fail
    )
)

rem ---------- [2/5] Docker engine ----------
echo.
echo [2/5] 检查 Docker 引擎 ...
call :log "[2/5] Docker engine"

set "DHOME="
if exist "%LOCALAPPDATA%\Programs\DockerDesktop\Docker Desktop.exe" set "DHOME=%LOCALAPPDATA%\Programs\DockerDesktop"
if not defined DHOME if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" set "DHOME=%ProgramFiles%\Docker\Docker"
if not defined DHOME if exist "%ProgramFiles%\Docker\Docker Desktop.exe" set "DHOME=%ProgramFiles%\Docker"

docker version >nul 2>&1
if not errorlevel 1 goto :docker_ok

if not defined DHOME (
    echo       X 未找到 Docker Desktop
    echo       请先安装: https://www.docker.com/products/docker-desktop/
    call :log "  FAILED: Docker Desktop not installed"
    goto :fail
)

echo       Docker 未运行，正在启动 ...
call :log "  starting Docker Desktop"
start "" "!DHOME!\Docker Desktop.exe"
set /a dw=0
:dw
ping -n 6 127.0.0.1 >nul 2>&1
docker version >nul 2>&1
if not errorlevel 1 goto :docker_ok
set /a dw+=5
if !dw! lss 240 goto dw
echo       X Docker 引擎 240 秒内未就绪
echo         请手动打开 Docker Desktop，等左下角变绿后重新运行本脚本
call :log "  FAILED: Docker engine timeout"
goto :fail

:docker_ok
echo       Docker 引擎正常
call :log "  Docker engine OK"

rem ---------- [3/5] data dirs ----------
echo.
echo [3/5] 创建数据目录 ...
call :log "[3/5] data dirs"
if not exist "%DATA%\face2face" mkdir "%DATA%\face2face" 2>nul
if not exist "%DATA%\voice\data" mkdir "%DATA%\voice\data" 2>nul
if not exist "%DATA%\face2face" (
    echo       X 无法创建 %DATA%
    echo         请确认 D 盘空间充足 ^(建议 30GB+^)
    call :log "  FAILED: cannot create %DATA%"
    goto :fail
)
echo       已就绪: %DATA%
call :log "  OK %DATA%"

rem ---------- [4/5] compose file ----------
echo.
echo [4/5] 检查 docker-compose ...
call :log "[4/5] compose file"
if not exist "%COMPOSE%" (
    echo       X 找不到 %COMPOSE%
    echo         请确认本脚本与 docker-compose.yml 在同一目录
    call :log "  FAILED: compose not found"
    goto :fail
)
echo       找到 docker-compose.yml
call :log "  OK compose"

rem check if images already present
docker images --format "{{.Repository}}" 2>nul | findstr /i "guiji2025" >nul
if not errorlevel 1 (
    echo       检测到已有数字人镜像，将跳过重复下载
    call :log "  existing guiji2025 images found"
) else (
    echo.
    echo       ! 首次安装需下载约 110GB 镜像，视网速需半小时到数小时
    echo       ! 请连接 WiFi 并保持电脑开机
    echo.
)

rem ---------- [5/5] up ----------
echo.
echo [5/5] 启动服务 ^(docker compose up -d^) ...
call :log "[5/5] docker compose up -d"
cd /d "%REPO%"
docker compose -f "docker-compose.yml" up -d >>"%LOG%" 2>&1
if errorlevel 1 (
    echo.
    echo       X 启动失败
    echo         常见原因: 网络无法访问 Docker Hub
    echo         解决: 在 Docker Desktop 设置里配置国内镜像源
    echo         或开启代理后重新运行本脚本
    call :log "  FAILED: compose up"
    echo.
    echo         详细日志: %LOG%
    goto :fail
)

echo       启动命令已执行，等待服务就绪 ...
call :log "  compose up issued"

rem wait for containers
set /a sw=0
:sw
ping -n 6 127.0.0.1 >nul 2>&1
curl -s -o nul --max-time 3 http://127.0.0.1:18180/ >nul 2>&1
if not errorlevel 1 goto :ready
set /a sw+=5
if !sw! lss 300 goto sw
echo       ! 服务响应较慢，容器可能仍在初始化
echo         可运行 docker ps 查看状态，或稍后重试
call :log "  WARN: services not ready in 300s"
goto :done

:ready
echo       服务已就绪
call :log "  services ready"

:done
echo.
echo ============================================================
echo   安装流程执行完毕
echo ============================================================
echo.
echo 当前容器状态:
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo.
echo ------------------------------------------------------------
echo  下一步:
echo   1. 确认上面 3 个容器都是 Up 状态
echo   2. 下载并安装客户端:
echo      https://github.com/duixcom/Duix.Avatar/releases
echo   3. 启动客户端，新建任务，用「文本」标签输入文案
echo ------------------------------------------------------------
echo.
echo 日志: %LOG%
echo.
echo 按任意键退出 ...
pause >nul
exit /b 0

rem ============================================================
:log
>>"%LOG%" echo %~1
exit /b 0

:warn_subst
echo.
echo       ! 已使用 subst 映射 D 盘，重启后会失效
echo       ! 请务必按说明书第 5 节配置开机自启
call :log "  WARNING: subst mapping is not persistent across reboot"
exit /b 0

:fail
echo.
echo ============================================================
echo   安装中止，请按上面的提示处理后重新运行
echo ============================================================
echo 日志: %LOG%
echo.
echo 按任意键退出 ...
pause >nul
exit /b 1
