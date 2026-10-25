# setup_project.ps1 - Inicialização e importação do Godot para novos colaboradores / IAs
param(
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [Cepas Selvagens] Setup e Inicialização do Godot Engine" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Localiza executável do Godot
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $found = Get-Command godot -ErrorAction SilentlyContinue
    if ($found) {
        $GodotPath = $found.Source
    } else {
        $wingetGodot = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "*godot*console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if (-not $wingetGodot) {
            $wingetGodot = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "*godot*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        }
        if ($wingetGodot) {
            $GodotPath = $wingetGodot
        }
    }
}

if (-not $GodotPath -or -not (Test-Path $GodotPath)) {
    Write-Host "[ERRO] Godot executavel nao encontrado automaticamente." -ForegroundColor Red
    Write-Host "Instale via 'winget install GodotEngine.GodotEngine' ou passe -GodotPath 'C:\caminho\godot.exe'" -ForegroundColor Yellow
    exit 1
}

Write-Host "Usando Godot: $GodotPath" -ForegroundColor Green

# 2. Reimportação completa e geração do cache de classes (.godot/imported e .godot/global_script_class_cache.cfg)
Write-Host "`n[1/2] Importando modelos .gltf, texturas e indexando classes..." -ForegroundColor Yellow
& $GodotPath --headless --editor --quit

if ($LASTEXITCODE -ne 0) {
    Write-Host "[AVISO] Importador finalizou com retorno $LASTEXITCODE. Verifique se ha erros criticos." -ForegroundColor Yellow
} else {
    Write-Host "[OK] Cache de importacao (.godot/imported) e classes gerados com sucesso." -ForegroundColor Green
}

# 3. Rodar suíte de testes para validação
Write-Host "`n[2/2] Rodando suite de validacao (tests/run_all.gd)..." -ForegroundColor Yellow
& $GodotPath --path . --headless -s res://tests/run_all.gd

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host " PROJETO PRONTO PARA CODAR! Todos os testes passaram." -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    Write-Host "`n[ERRO] Alguns testes falharam. Verifique os logs acima." -ForegroundColor Red
    exit $LASTEXITCODE
}
