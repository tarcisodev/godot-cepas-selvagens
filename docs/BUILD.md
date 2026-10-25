# Guia de Compilação e Exportação: Cepas Selvagens (Godot 4.7)

Este documento descreve o procedimento padronizado para gerar os pacotes de distribuição do **Client Windows Desktop** e do **Servidor Dedicado Linux Headless** para o Playtest Fechado de *Cepas Selvagens*.

---

## 1. Pré-requisitos

1. **Godot Engine 4.7+** (versão oficial estável com suporte a Forward Plus).
2. **Export Templates do Godot 4.7** instalados:
   - No editor: `Projeto -> Gerenciar Modelos de Exportação -> Baixar e Instalar`.
   - Ou baixados e extraídos em:
     - **Windows:** `%APPDATA%\Godot\export_templates\4.7.2.stable\`
     - **Linux:** `~/.local/share/godot/export_templates/4.7.2.stable/`

---

## 2. Presets Configurados (`export_presets.cfg`)

O repositório já possui os seguintes presets configurados:

| Preset | Plataforma | Tipo | Binário de Saída | Detalhes |
| :--- | :--- | :--- | :--- | :--- |
| **Windows Desktop** | Windows Desktop (x86_64) | Client | `build/windows/CepaSelvagem.exe` | Embed PCK ativo, texturas S3TC/BPTC |
| **Linux Server** | Linux/X11 (x86_64) | Dedicated Server | `build/linux/cepas-server.x86_64` | Embed PCK ativo, flag `dedicated_server=true` |

---

## 3. Geração de Builds via Linha de Comando (CLI)

Antes de exportar, certifique-se de que os diretórios de saída existem:

### No Windows (PowerShell):
```powershell
# 1. Cria diretórios de saída
New-Item -ItemType Directory -Force -Path "build/windows", "build/linux"

# 2. Localiza o executável do Godot
$godot = (Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "*godot*console.exe").FullName

# 3. Exporta o Client Windows (.exe)
& $godot --headless --export-release "Windows Desktop" build/windows/CepaSelvagem.exe

# 4. Exporta o Servidor Linux (.x86_64)
& $godot --headless --export-release "Linux Server" build/linux/cepas-server.x86_64
```

### No Linux (Bash):
```bash
# 1. Cria diretórios de saída
mkdir -p build/windows build/linux

# 2. Exporta o Client Windows (.exe)
godot --headless --export-release "Windows Desktop" build/windows/CepaSelvagem.exe

# 3. Exporta o Servidor Linux (.x86_64)
godot --headless --export-release "Linux Server" build/linux/cepas-server.x86_64

# 4. Garante permissão de execução no binário do servidor
chmod +x build/linux/cepas-server.x86_64
```

---

## 4. Execução do Servidor Dedicado no VPS

O servidor headless deve ser executado com os argumentos de linha de comando após `--`:

```bash
./cepas-server.x86_64 --headless -- --server --port 8787 --max-fps 20 --ticks 20
```

### Parâmetros Suportados:
- `--server`: Ativa o modo de servidor dedicado (`DedicatedServerBootAutoload`), inicializando a cena `server_world.tscn`.
- `--port <número>`: Define a porta de escuta ENet UDP (padrão: `8787`).
- `--max-fps <número>`: Limita os frames do loop headless para economizar CPU (padrão: `20`).
- `--ticks <número>`: Limita `Engine.physics_ticks_per_second` (padrão: `20` Hz).
- `--ws`: Inicializa o servidor usando `WebSocketMultiplayerPeer` (para tráfego web/proxy).

### Otimizações Automáticas de Servidor:
- `OS.low_processor_usage_mode = true` é ativado automaticamente, mantendo o consumo de CPU ociosa em ~1-5% de 1 vCPU.
- A cena `server_world.tscn` desativa timers de frame contínuo (`_process`) e utiliza Timers de baixa frequência para simulação do mundo e chunks.

---

## 5. Exemplo de Serviço Systemd (`/etc/systemd/system/cepas-server.service`)

```ini
[Unit]
Description=Cepas Selvagens Dedicated Server
After=network.target

[Service]
Type=simple
User=game
WorkingDirectory=/opt/cepas-selvagens
ExecStart=/opt/cepas-selvagens/cepas-server.x86_64 --headless -- --server --port 8787 --max-fps 20 --ticks 20
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

Comandos para gerenciar o serviço:
```bash
sudo systemctl daemon-reload
sudo systemctl enable cepas-server
sudo systemctl restart cepas-server
journalctl -u cepas-server -f
```

---

## 6. Conexão do Jogador (Client)

- O client compilado conecta automaticamente em `jogar.tarciso.dev:8787`.
- **Modo Dev / Conexão Local:** Na tela de login, clique no botão `🔧 Servidor Avançado (Dev) ▶` para revelar os campos de Host e Porta e apontar para `127.0.0.1` ou servidor de testes.
- **Versionamento Obrigatório:** O client valida a constante `NetworkManagerAutoload.GAME_VERSION` com o servidor. Versões divergentes recebem a instrução clara de atualização do jogo.
