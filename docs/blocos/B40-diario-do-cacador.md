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
2. **Capítulos restantes:** `EventBus.activity_done` (atalho `EventBusAutoload.report`) emitido na coleta, pesca, forja, fundição, cozinha (caldeirão e espeto), captura, crias, Elo ao montar, Companheira perdida (Página "perda", para sempre), mercado (venda e compra), Mercado Negro, missões e caravanas; Andanças por metros a pé e montado e lugares (células de 128 m); recordes (maior caça, melhor coleta/peixe/peça/prato, maior geração, maior Elo, maior venda). ✅ 2026-10-30.
3. **Marcos:** `MilestoneDef` + `MilestoneTable` (24 Marcos, uma linha cada), conferidos a cada feito; títulos (`set_title`), cartas, adornos, Contrato de Mestre no Quadro (última vaga, dobro do pedido, 2,5× a paga, exige o Marco de Trilha do capítulo), memória na arma (chefe e Lenda, em `memory["feitos"]`); anti-farm: abate digno (outra guilda, 6 h reais, equipamento ≥ metade), bicho de cercado/montaria não conta, teto de 200 recursos por lugar por dia de jogo. ✅ 2026-10-30.
4. **Tela do Diário [L]:** capa, capítulos, Páginas, Marcos, mostrar para outro jogador.
5. **Livro do Totem e Placar das Guildas:** `GuildLedger` por membro e semana, Feitos da Guilda, placar no Quadro da Vila.

## Critérios de pronto
- [x] Design do GDD-19 aprovado pelo Tarciso em 2026-10-30 (respostas propostas do §11).
- [x] Fase 1 (contadores e Páginas) — `tests/test_hunter_diary.gd`.
- [x] Fase 2 (ofícios, andanças e recordes) — mesmo teste, casos 7 a 9.
- [x] Fase 3 (Marcos, recompensas, memória na arma, anti-farm) — `tests/test_hunter_diary_milestones.gd`.
- [ ] Fases 4 e 5 implementadas em `feature/b40-diario-do-cacador`, com Issue ligada ao PR.
- [ ] Testes em `tests/` e `tests/run_all.gd` verde a cada fase.

## Próximo passo (uma frase)
Revisar e juntar o PR #29 (fases 1 a 3); depois, Fase 4 (tela do Diário [L] e cópia para o cliente).

## Notas da Fase 1
- Escrever só com autoridade: `NetworkManager.is_server_authoritative()`; o cliente ainda não recebe cópia (vem com a tela, Fase 4).
- Golpe sem dano em quem já caiu não gera abate nem queda (dedupe pelo dano do último golpe).
- Avatares remotos do servidor ainda não têm Vida nem DiaryComponent; o PvP online completo depende disso.

## Notas da Fase 2
- O Elo só é avisado quando sobe montando (a cada ponto inteiro); ganhos por cuidado no estábulo entram quando o Elo subir montado de novo.
- A pinheira (pinhão) e o abate de cria no cercado não contam como coleta; o abate do cercado conta como cria, e o anti-farm da Fase 3 tira o cercado da Caça.
- Ilhas visitadas (GDD-18) ficam para depois do B39: falta o B39 emitir `report(player, &"ilha", {"id": ...})` e um caso `&"ilha"` no DiaryComponent.

## Notas da Fase 3 (trocas em relação ao GDD-19 §6)
- Coleta Trilha: "colher em 5 lugares" (células de 128 m), já que ainda não há regiões com nome.
- Coleta Lenda: "minério raro de ilha" virou **pescar um peixe mutante de porte máximo** (qualidade 4); volta para minério de ilha quando o B39 entrar.
- Fogão Trilha: 5 receitas diferentes (há 6 no caldeirão hoje). Fogão Lenda: o banquete para 5 jogadores virou **prato 5★**, porque ainda não existe banquete.
- Andanças Trilha: 40 lugares. Andanças Lenda (ilhas) está marcado `pending` até o B39.
- Valor do equipamento no abate digno = soma da qualidade das peças vestidas; troca para o valor de mercado quando o servidor tiver tabela de preços.
- Doação na guilda fica para a Fase 5 (Livro do Totem).
- Cartas usadas: beast_horn (Caça Lenda), beehive (Coleta Trilha), polinization (Criadouro Trilha), fireball (Sangue Lenda), mimic (Andanças Trilha).
