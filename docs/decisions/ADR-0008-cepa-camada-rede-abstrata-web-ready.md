---
type: adr
status: accepted
created: 2026-10-25
updated: 2026-10-25
tags:
  - adr
  - decisao
  - cepa-selvagem
  - rede
  - web
  - websocket
  - traefik
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
deciders: tarciso
supersedes: ""
superseded_by: ""
---

# ADR-0008 — Isolamento da Camada de Rede para Suporte Futuro a Web/WSS

## Contexto
Atualmente, o cliente desktop de *Cepas Selvagens* e o servidor dedicado se comunicam via protocolo ENet (UDP na porta 8787). No entanto, o roadmap contempla disponibilizar o jogo diretamente no navegador via export Web (HTML5/WebAssembly) ou conexões através de redes corporativas/móveis restritas onde tráfego UDP é bloqueado.

Navegadores não suportam sockets UDP brutos (ENet); clientes web em Godot dependem exclusivamente de **WebSockets seguros (WSS)**. É fundamental garantir que a transição de transporte de rede não exija refatorações na lógica de gameplay, combate, inventário ou persistência.

## Opções consideradas
1. **Acoplamento direto ao ENet com refatoração posterior:** manter chamadas específicas do ENet dispersas pelo código e reescrever quando o build Web for priorizado.
2. **Camada de Transporte Abstrata unificada no `NetworkManager`:** isolar totalmente o backend de conexão (`MultiplayerPeer`), permitindo alternar entre `ENetMultiplayerPeer` e `WebSocketMultiplayerPeer` (com terminação WSS via proxy reverso Traefik) sem alterar nenhuma linha de lógica de jogo.

## Decisão
Adotamos a **Opção 2**.
- Toda a lógica de jogo (combate via `CombatResolver`, movimentação de avatares, inventário, ciclo de dia/noite e persistência) comunica-se unicamente através da `MultiplayerAPI` de alto nível do Godot e métodos públicos do autoload `NetworkManager` (`send_auth_request`, `request_combat_hit`, `send_enter_world_request`).
- O transporte físico é encapsulado em `NetworkManager`:
  - Se a URL de conexão iniciar com `ws://` ou `wss://` (ou se o servidor for iniciado com `--ws`), utiliza-se `WebSocketMultiplayerPeer`.
  - Caso contrário (padrão desktop/VPS), utiliza-se `ENetMultiplayerPeer` (porta 8787 UDP).
- Em ambiente de produção web, o proxy reverso **Traefik** no VPS gerencia os certificados SSL (Let's Encrypt) e faz proxy reverso de `wss://jogar.tarciso.dev/ws` para a porta local do servidor WebSocket, mantendo o servidor Godot focado na lógica autoritativa.

## Consequências
- **Positivas:**
  - Zero acoplamento entre mecânicas de jogo e transporte de pacotes.
  - O mesmo código roda no desktop nativo (ENet UDP de baixa latência) e, futuramente, no client Web sem duplicar rotas.
  - Segurança aprimorada e compatibilidade com proxies reversos modernos (Traefik, Cloudflare).
- **Negativas / Riscos:**
  - Manter consistência de comportamentos de desconexão e identificação de IPs remotos entre ENet e WebSocket (`get_peer_ip` e `disconnect_peer_safe`).

## Referências
- [[03-Projects/Cepa-Selvagem/decisions/ADR-0002-cepa-servidor-autoritativo|ADR-0002]] · [[03-Projects/Cepa-Selvagem/blocos/B24-mundo-aberto-chunks-e-servidor-beta|B24]]
