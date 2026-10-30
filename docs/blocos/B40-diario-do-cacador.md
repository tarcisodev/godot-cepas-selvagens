---
type: block
status: active
created: 2026-10-29
updated: 2026-10-30
tags:
  - bloco
  - godot
  - feitos
  - estatisticas
  - guildas
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B40 — Diário do Caçador

## Objetivo
Implementar o [[03-Projects/Cepa-Selvagem/notas/GDD-19-Diario-do-cacador|GDD-19]]: Diário por personagem com oito capítulos de contadores, Páginas de quedas e abates, Marcos sem poder e o Livro do Totem da guilda com o Placar das Guildas.

## Base que já existe
- `CombatResolver` emite `EventBus.entity_defeated(entity, killer)` e `part_broken` — hoje ninguém escuta o primeiro.
- `MasteryComponent` (GDD-02) para mostrar a maestria ao lado de cada capítulo.
- `memory` nas pilhas do `InventoryComponent` (B37) para a memória na arma.
- Quadro de Missões (B28), guildas (B26), manutenção (B32), caravanas (B33).
- `play_time` no branch `feature/char-delete-and-stats` (ainda fora do master).

## Fases
1. **Contadores e Páginas:** `FeatLedger` (dados) e `DiaryComponent` no jogador escutando o EventBus (`hit_resolved` + `entity_defeated`), abate/assistência/queda, ajuda na Página, 50 Páginas (chefes para sempre), save `"diary"` local e do servidor. ✅ 2026-10-30, Issue #28.
2. **Capítulos restantes:** ligar sinais de coleta, forja, cozinha, criadouro, andanças e balcão; recordes.
3. **Marcos:** `MilestoneDef` em dados, títulos, cartas, adornos, acesso no Quadro, memória na arma; anti-farm do §8.
4. **Tela do Diário [L]:** capa, capítulos, Páginas, Marcos, mostrar para outro jogador.
5. **Livro do Totem e Placar das Guildas:** `GuildLedger` por membro e semana, Feitos da Guilda, placar no Quadro da Vila.

## Critérios de pronto
- [x] Design do GDD-19 aprovado pelo Tarciso em 2026-10-30 (respostas propostas do §11).
- [x] Fase 1 (contadores e Páginas) — `tests/test_hunter_diary.gd`.
- [ ] Fases 2 a 5 implementadas em `feature/b40-diario-do-cacador`, com Issue ligada ao PR.
- [ ] Testes em `tests/` e `tests/run_all.gd` verde a cada fase.

## Próximo passo (uma frase)
Revisar e juntar o PR da Fase 1; depois, Fase 2 (sinais de coleta, forja, cozinha, criadouro, andanças e balcão).

## Notas da Fase 1
- Escrever só com autoridade: `NetworkManager.is_server_authoritative()`; o cliente ainda não recebe cópia (vem com a tela, Fase 4).
- Golpe sem dano em quem já caiu não gera abate nem queda (dedupe pelo dano do último golpe).
- Avatares remotos do servidor ainda não têm Vida nem DiaryComponent; o PvP online completo depende disso.
