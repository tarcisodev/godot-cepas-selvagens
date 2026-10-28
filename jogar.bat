@echo off
setlocal enabledelayedexpansion
title Cepas Selvagens

echo ========================================================
echo   Iniciando Cepas Selvagens
echo ========================================================

:: 1. Tenta executavel exato do Godot 4.7
for /f "tokens=*" %%i in ('where Godot_v4.7.2-stable_win64.exe 2^>nul') do (
    set "GODOT_BIN=%%i"
    goto :run_game
)

:: 2. Tenta comando generico godot
for /f "tokens=*" %%i in ('where godot 2^>nul') do (
    set "GODOT_BIN=%%i"
    goto :run_game
)

:: 3. Procura no WinGet Packages
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-ChildItem -Path \"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\" -Recurse -Filter \"*win64.exe\" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike \"*console*\" }).FullName | Select-Object -First 1"') do (
    set "GODOT_BIN=%%i"
    goto :run_game
)

echo [ERRO] Executavel do Godot nao foi encontrado no sistema!
pause
exit /b 1

:run_game
echo Executando com: "!GODOT_BIN!"
echo.
start "" "!GODOT_BIN!" --path "%~dp0." %*
