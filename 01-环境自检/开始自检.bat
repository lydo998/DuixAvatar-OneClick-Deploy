@echo off
rem ============================================================
rem  Duix.Avatar 环境自检 - 启动器
rem  双击本文件即可运行 PowerShell 版自检脚本
rem  自动处理执行策略与中文路径问题
rem ============================================================
setlocal
cd /d "%~dp0"
set "PSEXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

echo Running environment check ...
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0环境自检.ps1"

if errorlevel 1 (
    echo.
    echo [INFO] PowerShell version failed, falling back to BAT version ...
    call "%~dp0环境自检.bat"
)
endlocal
