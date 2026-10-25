#!/bin/bash
# ==============================================================================
# Deploy Script: Cepas Selvagens Dedicated Server (TarcisoDevServer)
# Alvo: VPS 187.77.22.250 | Usuário: cepas | Porta: 8787 (UDP/TCP)
# NOTA: Docker Swarm e Traefik NÃO são alterados por este script.
# ==============================================================================

set -e

SERVER_DIR="/home/cepas/cepas-server"
SAVES_DIR="/home/cepas/.local/share/godot/app_userdata/Cepas Selvagens/server_saves"
BACKUP_DIR="/home/cepas/backups"
SERVICE_FILE="/etc/systemd/system/cepas-server.service"

echo "=== [1/6] Verificando Usuário e Diretórios ==="
if ! id "cepas" &>/dev/null; then
    echo "Criando usuário dedicado 'cepas'..."
    useradd -m -s /bin/bash cepas
fi

mkdir -p "$SERVER_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$SAVES_DIR/accounts"
mkdir -p "$SAVES_DIR/players"
mkdir -p "$SAVES_DIR/world"

echo "=== [2/6] Backup de Segurança dos Saves ==="
if [ -d "$SAVES_DIR" ] && [ "$(ls -A "$SAVES_DIR")" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/cepas_saves_$TIMESTAMP.tar.gz"
    echo "Criando backup dos dados em: $BACKUP_FILE"
    tar -czf "$BACKUP_FILE" -C "/home/cepas/.local/share/godot/app_userdata/Cepas Selvagens" server_saves
else
    echo "Nenhum save existente para backup (primeiro deploy)."
fi

echo "=== [3/6] Configurando Permissões ==="
chown -R cepas:cepas /home/cepas
chmod -R 750 /home/cepas

echo "=== [4/6] Configurando Firewall (UFW) ==="
ufw allow 8787/udp comment "Cepas Selvagens ENet Game Traffic"
ufw allow 8787/tcp comment "Cepas Selvagens WS Traffic"
ufw reload

echo "=== [5/6] Instalando Serviço systemd ==="
cat << 'EOF' > "$SERVICE_FILE"
[Unit]
Description=Cepas Selvagens Dedicated Server
After=network.target

[Service]
Type=simple
User=cepas
WorkingDirectory=/home/cepas/cepas-server
ExecStart=/usr/local/bin/godot --headless --path . -- --server --port 8787
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cepas-server.service

echo "=== [6/6] Reiniciando Servidor de Jogo ==="
systemctl restart cepas-server.service
sleep 2

systemctl status cepas-server.service --no-pager
echo ""
echo "✅ Deploy concluído com sucesso!"
echo "Servidor ativo escutando em 187.77.22.250:8787 (DNS: jogar.tarciso.dev:8787)"
echo "Inspecione os logs com: journalctl -u cepas-server -f"
