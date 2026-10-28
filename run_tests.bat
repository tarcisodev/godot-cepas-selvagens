@echo off
setlocal enabledelayedexpansion
title Cepas Selvagens - Testes Automatizados

echo ========================================================
echo   Testes Automatizados: Cepas Selvagens (Godot 4.7)
echo ========================================================

:: 1. Procura Godot no PATH
where godot >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('where godot') do (
        set "GODOT_BIN=%%i"
        goto :run_tests
    )
)

:: 2. Procura Godot Console no WinGet
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-ChildItem -Path \"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\" -Recurse -Filter \"*godot*console.exe\" -ErrorAction SilentlyContinue).FullName | Select-Object -First 1"') do (
    set "GODOT_BIN=%%i"
    goto :run_tests
)

:: 3. Procura qualquer executável Godot no WinGet
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-ChildItem -Path \"$env:LOCALAPPDATA\Microsoft\WinGet\Packages\" -Recurse -Filter \"*godot*.exe\" -ErrorAction SilentlyContinue).FullName | Select-Object -First 1"') do (
    set "GODOT_BIN=%%i"
    goto :run_tests
)

echo [ERRO] Executavel do Godot nao encontrado no PATH nem no WinGet!
echo Instale o Godot 4.7 ou adicione o executavel ao PATH do sistema.
pause
exit /b 1

:run_tests
echo Utilizando Godot: "%GODOT_BIN%"
echo.
"%GODOT_BIN%" --path . --headless -s res://tests/run_all.gd
set TEST_STATUS=%errorlevel%

echo.
if %TEST_STATUS% equ 0 (
    echo [SUCESSO] Todos os testes passaram sem erros!
) else (
    echo [FALHA] Um ou mais testes falharam. Verifique a saida acima.
)

if "%1"=="" pause
exit /b %TEST_STATUS%
