---
type: block
status: done
created: 2026-10-25
updated: 2026-10-25
tags:
  - bloco
  - economia
  - mercado_negro
  - armadilhas
  - caca
  - baus
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
agent: labu
---

# B30 — Mercado Negro Clandestino, Armadilhas de Caça & Baús do Ermo

## Objetivo
Implementar o regulador sistêmico da economia (GDD-05 §3) e ferramentas especializadas de caça anatômica (GDD-03 §8):
1. **Armadilha de Mandíbula (`HuntingTrap`) & Isca Odorífera (`HuntingBait`):** posicionadas no solo pelo jogador, desarmam ou alimentam presas, causam dano físico direto às pernas com quebra anatômica e imobilizam presas por 8s (`State.TRAPPED`).
2. **Mercado Negro Clandestino (`BlackMarketSystem`):** gera ordens de compra sistêmicas pagando prêmios em $S (+40% a +60%), compra equipamentos forjados de jogadores e armazena no cofre de Loot Orgânico (`organic_loot_pool`).
3. **Triturador de Excesso (Ralo Permanente de Economia):** desmancha peças excedentes que ultrapassem o teto de 12 itens no cofre para evitar inflação e saturação do mercado.
4. **Baús de Tesouro do Ermo (`WildChest`):** recompensam exploradores de zonas perigosas com equipamentos forjados originalmente por jogadores retirados do cofre do Mercado Negro (`take_organic_loot`), moedas $S, matérias-primas nobres e a carta colecionável 3D *Cogumelos de Sobretudo* (`CardDatabase`).
5. **Estação Clandestina 3D (`BlackMarketStation`) & Interface (`BlackMarketScreen`):** balcão de ardósia com lampião violeta de lume e tela com abas para cumprimento de ordens e liquidação direta de equipamentos forjados.

---

## Critérios de Pronto
- [x] Novos recursos de materiais:
  - `resources/materials/armadilha_mola.tres` (Mandíbula de ferro, tool_action `&"armadilha"`)
  - `resources/materials/isca_feromonio.tres` (Isca aromática, tool_action `&"isca"`)
- [x] Novas receitas de manufatura no `InventoryComponent`:
  - `&"armadilha_mola"`: 3 madeira, 2 pedra, 1 tendão elástico
  - `&"isca_feromonio"`: 2 erva, 2 folha, 2 frutinha
- [x] `HuntingTrap` (Node3D):
  - Gatilho cilíndrico de 1.6m;
  - Desfecha mandíbulas duplas com dentes de aço;
  - Causa 45 de dano físico e 65 de dano de quebra anatômica direcionado à perna (`HitEvent` com `part_id = &"leg"` via `CombatResolver`);
  - Imobiliza a criatura por 8s (`force_trap` / `State.TRAPPED`);
  - Desarme e recolhimento pelo jogador via `talk_to(player)`.
- [x] `HuntingBait` (Node3D):
  - Raio de atração aromática de 25m e duração de 90s;
  - Atrai criaturas selvagens (`set_bait_attraction`);
  - Saciedade (`hunger = 0.0`) quando consumida por uma presa próxima;
  - Recolhimento antes do consumo via `talk_to(player)`.
- [x] `TrapSystem` & Integração com Roda Rápida (`QuickItemWheel`):
  - Tecla `[G]` posiciona a armadilha ou isca consumindo 1 material da mochila;
  - Métodos `deploy_trap_by_player` e `deploy_bait_by_player`.
- [x] `BlackMarketSystem` (Node):
  - 4 ordens sistêmicas ativas com prêmio de demanda (+40% a +60%);
  - Venda direta de equipamentos forjados (`sell_gear`);
  - Cofre de Loot Orgânico (`organic_loot_pool`);
  - Ralo econômico (Triturador de Excesso ao exceder 12 itens);
  - Fornecimento de peças reais de jogadores para baús dos ermos (`take_organic_loot`);
  - Serialização completa (`to_dict` / `from_dict`).
- [x] `WildChest` (Node3D):
  - Baú rúnico de ferro e carvalho escuro;
  - Concede 1× peça forjada do Loot Orgânico, 35 $S, 2× óleo de peixe e carta 3D *Cogumelos de Sobretudo*;
  - Tampa articulada e prevenção contra saque duplicado.
- [x] `BlackMarketStation` & `BlackMarketScreen`:
  - Balcão 3D clandestino com lampião violeta;
  - Tela completa com abas de Ordens e Venda de Equipamentos, feedback e atalho ESC.
- [x] Suíte de testes automatizados `tests/test_black_market_and_traps.gd` (6/6 suites verdes, 100% de aprovação).

---

## Log
- 2026-10-25 — Criação do branch `feature/mercado-negro-e-armadilhas`.
- 2026-10-25 — Criação dos materiais `armadilha_mola.tres` e `isca_feromonio.tres` e adição das receitas ao `InventoryComponent`.
- 2026-10-25 — Implementação de `HuntingTrap`, `HuntingBait` e `TrapSystem` com deploy por atalho de ferramenta na `QuickItemWheel`.
- 2026-10-25 — Implementação de `force_trap` e `set_bait_attraction` em `WildCreature`.
- 2026-10-25 — Implementação do `BlackMarketSystem` com ordens de compra sistêmicas, venda de equipamentos forjados, triturador de excesso e cofre de loot orgânico.
- 2026-10-25 — Implementação do `WildChest` entregando loot orgânico, moedas $S e destrancamento de cartas 3D do álbum.
- 2026-10-25 — Implementação de `BlackMarketStation` 3D e `BlackMarketScreen`.
- 2026-10-25 — Criação e validação do teste `tests/test_black_market_and_traps.gd`.
- 2026-10-25 — Execução do runner geral `tests/run_all.gd`: 44/44 testes passando com 0 erros.
