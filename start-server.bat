@echo off
title 🔮 Tarot Website Server
echo.
echo 🔮 ============================================
echo    命运之轮 · Wheel of Fortune
echo ============================================
echo.
echo Starting server...
echo.

REM Check if running as admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARNING] Not running as Administrator!
    echo.
    echo The server can only be accessed from THIS computer.
    echo To allow OTHER DEVICES to connect, right-click this file
    echo and select "Run as Administrator".
    echo.
    echo Starting in local-only mode...
    echo.
    powershell -ExecutionPolicy Bypass -File "%~dp0server.ps1" -LocalOnly
) else (
    echo Running with Administrator privileges - network access ENABLED.
    echo.
    powershell -ExecutionPolicy Bypass -File "%~dp0server.ps1"
)

pause
