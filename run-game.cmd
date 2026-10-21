@echo off
setlocal
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

set "GODOT_EXE=C:\Users\Tarciso\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

if not exist "%GODOT_EXE%" (
    echo Godot executable not found at: %GODOT_EXE%
    pause
    exit /b 1
)

"%GODOT_EXE%" --path "%PROJECT_DIR%" %*
endlocal
