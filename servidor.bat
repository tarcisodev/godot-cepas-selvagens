@echo off
setlocal enabledelayedexpansion
title Cepas Selvagens - Servidor Dedicado Local (Porta 8787)

echo ========================================================
echo   CEPAS SELVAGENS - SERVIDOR DEDICADO HEADLESS
echo ========================================================
echo.

:: 1. Tenta executavel exato do Godot Console
for /f "tokens=*" %%i in ('where Godot_v4.7.2-stable_win64_console.exe 2^>nul') do (
    set "GODOT_BIN=%%i"
    goto :run_server
)

:: 2. Procura Godot Console no WinGet Packages
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-ChildItem -Path \"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\" -Recurse -Filter \"*godot*console.exe\" -ErrorAction SilentlyContinue).FullName | Select-Object -First 1"') do (
    set "GODOT_BIN=%%i"
    goto :run_server
)

:: 3. Procura no PATH
where godot >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('where godot') do (
        set "GODOT_BIN=%%i"
        goto :run_server
    )
)

echo [ERRO] Executavel do Godot nao foi encontrado no sistema!
pause
exit /b 1

:run_server
echo Executavel: "!GODOT_BIN!"
echo.
echo ========================================================
echo [STATUS] Servidor Dedicado Ativo na Porta 8787 (UDP/ENet)
echo.
echo Como conectar:
echo  - Neste mesmo PC:
echo      1. Abra jogar.bat
echo      2. Clique em 'Jogar Online (Entrar)'
echo      3. Abra 'Servidor Avancado (Dev)' e clique em 'Local (127.0.0.1)'
echo.
echo  - Em computadores da rede local (LAN / Wi-Fi):
echo      Use o IP local deste PC na porta 8787
echo.
echo Pressione Ctrl+C a qualquer momento para encerrar.
echo ========================================================
echo.
"!GODOT_BIN!" --headless --path "%~dp0." -- --server --port 8787 %*
