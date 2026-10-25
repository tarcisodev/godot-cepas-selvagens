#!/usr/bin/env bash
set -e

echo "=========================================================="
echo " [Cepas Selvagens] Setup e Inicialização do Godot Engine"
echo "=========================================================="

GODOT_BIN="${1:-godot}"

if ! command -v "$GODOT_BIN" &> /dev/null; then
    echo "[ERRO] Godot executável não encontrado no PATH ($GODOT_BIN)."
    echo "Passe o binário como argumento: ./setup_project.sh /path/to/godot"
    exit 1
fi

echo "Usando Godot: $(command -v "$GODOT_BIN")"

echo ""
echo "[1/2] Importando modelos .gltf, texturas e indexando classes..."
"$GODOT_BIN" --headless --editor --quit || true

echo ""
echo "[2/2] Rodando suite de validação (tests/run_all.gd)..."
"$GODOT_BIN" --path . --headless -s res://tests/run_all.gd

echo ""
echo "=========================================================="
echo " PROJETO PRONTO PARA CODAR! Todos os testes passaram."
echo "=========================================================="
