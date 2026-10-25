---
type: block
status: done
created: 2026-10-22
updated: 2026-10-22
tags:
  - bloco
  - godot
  - procedural
  - fauna
  - montarias
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B13 — Fauna e flora procedurais, e montarias

## Objetivo
Implementar o [[03-Projects/Cepa-Selvagem/notas/GDD-09-Criaturas-plantas-procedurais-e-montarias|GDD-09]]: criaturas e plantas geradas por DNA, espécies do slice no mundo e as três montarias (terrestre, voadora, aquática).

## Critérios de pronto
- [x] `CreatureDNA` + construtor de corpo (quadrúpede, ave, peixe) com animação procedural.
- [x] `PlantDNA` + construtor (árvore, arbusto florido, Cepa Selvagem, cogumelo-lume).
- [x] Espécies no mundo: Trotador, Planador, Raia, Saltarelo, Lambari — fora da vila.
- [x] Plantas procedurais espalhadas pelo vale.
- [x] Montaria: montar em 1,5 s ([E]), dano cancela; controles por tipo; fôlego; desmontar.
- [x] Estábulo na vila com Trotador e Planador; Raia na margem do rio.
- [x] Testes headless e prints no jogo.

## Próximo passo (uma frase)
Tarciso montar as três montarias e passear pelo vale; ajustar velocidades, tamanhos e quantidade de bichos/plantas.

## Log
- 2026-10-22 — Bloco criado (Claude) a partir do pedido do Tarciso.
- 2026-10-22 — Implementado (Claude). `CreatureDNA` (alelos porte/chifre/padrão + mutação `*`, `cross()` com 3%), `CreatureBody` (quadrúpede, ave, peixe; animação procedural sem esqueleto), `PlantDNA` + `PlantBody` (árvore, arbusto florido, Cepa Selvagem em leque, cogumelo-lume emissivo; 1 malha por planta). `WildCreature`: rebanhos de Trotador e Saltarelos que fogem de quem corre, Planadores em círculo, Raias e cardumes no rio. `EcosystemSpawner` no `world.tscn` (39 bichos e ~120 plantas, fora da vila, água e arena). `Mount`: montar em 1,5 s parado (dano cancela), Trotador 9/15 m/s com pulo, Planador 11/17 com Espaço/Ctrl e teto de 40 m, Raia 7/11 só na água (sai do rio = desce na margem); fôlego 100 (−18/s correndo, +12/s); Postura quebrada derruba; montado não ataca. Estábulo a noroeste da vila (−15, −5); Raia no rio na altura da vila. Teste `tests/test_procedural_fauna.gd`; runner 17/17; as três montarias conferidas no mundo (andou 8 m, voou 14 m, nadou 5 m).
