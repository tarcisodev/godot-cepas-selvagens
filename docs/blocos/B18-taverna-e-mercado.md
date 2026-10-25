---
type: block
status: done
created: 2026-10-23
updated: 2026-10-23
tags:
  - bloco
  - godot
  - cartas
  - economia
  - vila
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B18 — Funções da Taverna e do Mercado

## Objetivo
Dar função aos prédios da Vila da Esperança (GDD-08 §6.1): a Taverna pronta abre a mesa do Duelo de Cepas ([[03-Projects/Cepa-Selvagem/notas/GDD-07-Cartas-colecionaveis-e-minigame|GDD-07 §7]]) e o Mercado pronto abre encomendas e vendas ([[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05 §6]]). Pedido do Tarciso; regras decididas pelo Claude como game designer.

## Critérios de pronto
- [x] Regras do duelo e do mercado do slice escritas no GDD antes do código.
- [x] Duelo de Cepas: baralho da coleção, 3 fileiras, Éter, elementos, traits das 8 cartas, Taverneira com IA, aposta com corte da casa e carta de prêmio.
- [x] Mercado: encomendas e ordens de venda com dinheiro/itens travados, taxas de 2% e 4%, caravana às 8h e 17h, cancelar, retirar, save.
- [x] Só abrem com a obra pronta; NPCs avisam enquanto estiver em obras.
- [x] Testes, prints.

## Próximo passo (uma frase)
Tarciso terminar a Taverna e o Mercado jogando, jogar umas partidas contra a Taverneira e dizer se as faixas de preço da caravana e a força da Taverneira estão boas.

## Log
- 2026-10-23 — Bloco criado e feito (Claude). Design no GDD-07 §7 e GDD-05 §6. `CardDuel` (regra pura para o servidor), `TavernTable` (mesa, cadeiras, caneca e Taverneira na porta da Taverna; aposta 0/5/10/20 com 10% da casa; vitória dá Colmeia → Esfera de Fogo → Polinização), `CardTableScreen` (clique na carta e na fileira; a Taverneira joga após 0,8 s; sair no meio perde a aposta). `VillageMarket` (17 materiais de coleta e caça; até 6 ordens; caravana às 8h e 17h; ★ e traits lembrados no que fica travado), Mercadora no pavilhão, `MarketScreen`. Estado do mercado no save da vila. Testes `test_card_duel.gd` (inclui 300 partidas bot × bot: inicial vence 27%) e `test_market.gd`; runner 23/23.
