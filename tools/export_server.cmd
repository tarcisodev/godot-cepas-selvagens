@echo off
setlocal
set "PROJECT_DIR=%~dp0.."
pushd "%PROJECT_DIR%"

set "GODOT_EXE=C:\Users\Tarciso\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"

if not exist "%GODOT_EXE%" (
    echo [ERRO] Executavel do Godot nao encontrado em: %GODOT_EXE%
    pause
    exit /b 1
)

if not exist "build\linux" mkdir "build\linux"

echo ============================================================
echo [1/2] Executando bateria de testes antes do export...
echo ============================================================
"%GODOT_EXE%" --path . --headless -s res://tests/run_all.gd
if errorlevel 1 (
    echo [ERRO] Testes falharam! Export cancelado.
    popd
    pause
    exit /b 1
)

echo ============================================================
echo [2/2] Gerando pacote Linux Server Headless...
echo ============================================================
"%GODOT_EXE%" --path . --headless --export-pack "Linux Server" build\linux\cepas-server.pck

echo [SUCESSO] Pacote gerado em build/linux/cepas-server.pck
popd
endlocal
