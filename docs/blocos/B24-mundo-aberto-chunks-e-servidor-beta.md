---
type: block
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - bloco
  - godot
  - mundo-aberto
  - chunks
  - multimesh
  - multiplayer
  - persistencia
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B24 — Mundo Aberto em Chunks, MultiMesh & Servidor Beta com Persistência

## Objetivo
Expandir o mundo de *Cepas Selvagens* do vale inicial (360 m) para **escala de quilômetros**, viabilizando a necessidade e o prazer da **montaria** para travessias longas.
Implementar uma arquitetura de **streaming de terreno em chunks com MultiMesh** para vegetação, além de preparar o **servidor dedicado headless com persistência** para rodar localmente no PC e conectar amigos no Beta.

## Pilares e Arquitetura Técnica

### 1. Sistema de Terreno em Chunks (`TerrainChunkManager`)
- O mapa deixa de ser uma malha estática única de 360×360 m e passa a ser particionado em **chunks** (ex.: 64×64 m ou 128×128 m).
- Cada chunk avalia a função contínua de altura `get_height_at(x, z)` (expandindo ruído Simplex e relevo procedural para além das fronteiras antigas).
- Chunks próximos ao jogador (ou aos jogadores no multiplayer) geram malha visual (`ArrayMesh`) e colisão física (`HeightMapShape3D`).
- Chunks fora do raio de visão são descarregados da memória ou simplificados.

### 2. Vegetação Otimizada via MultiMesh por Chunk
- Cada chunk ativo hospeda suas próprias instâncias de `MultiMeshInstance3D` para grama, trevos, flores e rochas pequenas.
- Permite frustum culling real por GPU (apenas os chunks visíveis na tela têm suas draw calls processadas).

### 3. Remoção do Gargalo de Fronteira e Integração da Montaria
- `WorldBounds` passa a suportar raio ampliado de quilômetros (ou modo streaming ilimitado).
- O resgate de limbo do `Player` e da `Mount` se ajusta dinamicamente à posição atual, sem limites artificiais de 180 m.
- Travessia suave de montarias (terrestre, voadora e aquática) entre fronteiras de chunks.

### 4. Servidor Headless Autoritativo e Persistência de Jogadores
- Suporte a inicialização headless com argumento `--server` ou `--port <porta>`.
- O servidor atua como fonte da verdade para inventário, equipamentos, posição e montarias.
- Módulo de persistência que salva o estado dos jogadores em arquivos individuais no servidor ao desconectar e recarrega na reconexão.

### 5. Blindagem para Playtest Fechado, Segurança e Desempenho
- **Conexão Padrão Sem Digitação:** Client conecta diretamente em `jogar.tarciso.dev:8787` por padrão, mantendo gaveta `🔧 Servidor Avançado (Dev)` oculta para desenvolvedores.
- **Versionamento Semver (`GAME_VERSION`):** Validação estrita entre client e servidor no handshake de autenticação; rejeição amigável com mensagem de atualização obrigatória.
- **Proteção e Rate Limiting no Servidor:**
  - Limite de 5 tentativas de login por minuto por IP com log de recusa.
  - Limite de conexões simultâneas por IP (máx. 3).
  - Capacidade máxima ampliada para 32 jogadores simultâneos.
- **Otimização de CPU Ociosa:** Ativação de `OS.low_processor_usage_mode = true` no boot headless e substituição de `_process` por timers na cena `server_world.tscn` (`SunUpdateTimer`, `ChunkUpdateTimer`, `AutosaveTimer`).
- **Arquitetura Web-Ready (ADR-0008):** Isolamento do transporte no `NetworkManager`, preparando suporte futuro a `WebSocketMultiplayerPeer` (WSS via Traefik).

## Critérios de Pronto
- [x] Documento do Bloco B24 registrado no repositório.
- [x] `TerrainChunkManager` funcional gerando relevo contínuo sem frestas entre chunks adjacentes.
- [x] MultiMesh populado dinamicamente por chunk de terreno.
- [x] `WorldBounds` e limites de limbo do jogador adaptados para escala de quilômetros.
- [x] Persistência do servidor gravando dados do jogador ao desconectar e restaurando na entrada.
- [x] Autenticação de contas com usuário/senha (SHA-256 + salt) e suporte a WebSockets/Cloudflare Tunnel (ws://, wss://).
- [x] Tela de Login/Registro e Criação de Personagens vinculados à conta (OnlineAuthModal).
- [x] Conexão padrão para `jogar.tarciso.dev:8787` com gaveta avançada dev oculta.
- [x] Versionamento semver (`GAME_VERSION = "0.1.0"`) com recusa explicativa de versão incompatível.
- [x] Proteção básica de servidor (rate limit 5 req/min/IP, 3 conexões/IP, limite 32 jogadores e logs de recusa).
- [x] Otimização do modo servidor com `low_processor_usage_mode` e eliminação de `_process` em nós do `server_world`.
- [x] Presets de export Windows Desktop e Linux Server documentados em `docs/BUILD.md`.
- [x] Isolamento da camada de rede Web-Ready registrado em `docs/decisions/ADR-0008-cepa-camada-rede-abstrata-web-ready.md`.
- [x] Suíte de testes headless cobrindo novas rotas de segurança e versionamento com 100% de sucesso.
