@echo off
setlocal enabledelayedexpansion
title Cepas Selvagens - Painel de Controle

:menu
cls
echo ========================================================
echo         CEPAS SELVAGENS - PAINEL DO DESENVOLVEDOR
echo ========================================================
echo.
echo   [1] Iniciar Jogo (Client)
echo   [2] Iniciar Launcher Oficial
echo   [3] Iniciar Servidor Dedicado Local (Porta 8787)
echo   [4] Rodar Testes Automatizados do Jogo (Headless)
echo   [5] Rodar Testes do Launcher (Headless)
echo   [6] Compilar / Exportar Builds (Client + Launcher)
echo   [0] Sair
echo.
echo ========================================================
set /p OPT="Escolha uma opcao [0-6]: "

if "%OPT%"=="1" (
    call run_game.bat
    goto :menu
)
if "%OPT%"=="2" (
    call run_launcher.bat
    goto :menu
)
if "%OPT%"=="3" (
    call run_server.bat
    goto :menu
)
if "%OPT%"=="4" (
    call run_tests.bat
    goto :menu
)
if "%OPT%"=="5" (
    echo.
    powershell -Command "$godot = (Get-ChildItem -Path \"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\" -Recurse -Filter \"*godot*console.exe\").FullName; & $godot --path launcher --headless -s res://tests/test_launcher.gd"
    pause
    goto :menu
)
if "%OPT%"=="6" (
    call build.bat
    goto :menu
)
if "%OPT%"=="0" exit /b 0

echo Opcao invalida!
timeout /t 2 >nul
goto :menu
