@echo off
setlocal enabledelayedexpansion
title Cepas Selvagens - Executar Jogo

echo ========================================================
echo   Iniciando Cliente: Cepas Selvagens (Godot 4.7)
echo ========================================================

:: Procura Godot GUI no WinGet
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-ChildItem -Path \"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\" -Recurse -Filter \"*win64.exe\" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike \"*console*\" }).FullName | Select-Object -First 1"') do (
    set "GODOT_BIN=%%i"
    goto :run_game
)

:: Procura Godot no PATH
where godot >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('where godot') do (
        set "GODOT_BIN=%%i"
        goto :run_game
    )
)

:: Fallback Console
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-ChildItem -Path \"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\" -Recurse -Filter \"*godot*.exe\" -ErrorAction SilentlyContinue).FullName | Select-Object -First 1"') do (
    set "GODOT_BIN=%%i"
    goto :run_game
)

echo [ERRO] Executavel do Godot nao encontrado!
pause
exit /b 1

:run_game
echo Executando com: "%GODOT_BIN%"
echo.
"%GODOT_BIN%" --path . %*
