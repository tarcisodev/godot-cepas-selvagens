@echo off
setlocal enabledelayedexpansion
title Cepas Selvagens - Compilacao e Exportacao de Builds

echo ========================================================
echo   Exportador de Builds: Cepas Selvagens (Godot 4.7)
echo ========================================================

:: Procura Godot Console no WinGet
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-ChildItem -Path \"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\" -Recurse -Filter \"*godot*console.exe\" -ErrorAction SilentlyContinue).FullName | Select-Object -First 1"') do (
    set "GODOT_BIN=%%i"
    goto :start_build
)

:: Procura Godot no PATH
where godot >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('where godot') do (
        set "GODOT_BIN=%%i"
        goto :start_build
    )
)

echo [ERRO] Executavel do Godot nao encontrado para exportar!
pause
exit /b 1

:start_build
echo Criando diretorios de saida...
if not exist "build\windows" mkdir "build\windows"
if not exist "build\linux" mkdir "build\linux"

echo.
echo [1/3] Exportando Cliente Windows Desktop (CepaSelvagem.exe)...
"%GODOT_BIN%" --headless --path . --export-release "Windows Desktop" build\windows\CepaSelvagem.exe
if %errorlevel% neq 0 (
    echo [AVISO] Falha ou templates ausentes para Windows Desktop.
) else (
    echo [OK] Cliente Windows exportado em build\windows\CepaSelvagem.exe
)

echo.
echo [2/3] Exportando Launcher Oficial (CepaLauncher.exe)...
"%GODOT_BIN%" --headless --path launcher --export-release "Windows Desktop" build\windows\CepaLauncher.exe
if %errorlevel% neq 0 (
    echo [AVISO] Falha ou templates ausentes para Launcher Windows.
) else (
    echo [OK] Launcher exportado em build\windows\CepaLauncher.exe
)

echo.
echo [3/3] Exportando Servidor Linux Dedicado (cepas-server.x86_64)...
"%GODOT_BIN%" --headless --path . --export-release "Linux Server" build\linux\cepas-server.x86_64
if %errorlevel% neq 0 (
    echo [AVISO] Falha ou templates ausentes para Linux Server.
) else (
    echo [OK] Servidor Linux exportado em build\linux\cepas-server.x86_64
)

echo.
echo ========================================================
echo   Processo de build finalizado! Verifique a pasta build/
echo ========================================================
if "%1"=="" pause
