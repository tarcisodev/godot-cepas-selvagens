@echo off
setlocal enabledelayedexpansion
title Cepas Selvagens - Servidor Dedicado Local (Porta 8787)

echo ========================================================
echo   Iniciando Servidor Dedicado: Cepas Selvagens (Porta 8787)
echo ========================================================

:: Procura Godot Console no WinGet
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-ChildItem -Path \"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\" -Recurse -Filter \"*godot*console.exe\" -ErrorAction SilentlyContinue).FullName | Select-Object -First 1"') do (
    set "GODOT_BIN=%%i"
    goto :run_server
)

:: Procura Godot no PATH
where godot >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('where godot') do (
        set "GODOT_BIN=%%i"
        goto :run_server
    )
)

echo [ERRO] Executavel do Godot nao encontrado!
pause
exit /b 1

:run_server
echo Servidor iniciado em modo headless. Pressione Ctrl+C para encerrar.
echo.
"%GODOT_BIN%" --headless --path . -- --server --port 8787 %*
