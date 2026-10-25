---
type: block
status: done
created: 2026-10-23
updated: 2026-10-23
tags:
  - bloco
  - godot
  - ecologia
  - pesca
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B19 — Nado, mergulho, peixes procedurais e pesca

## Objetivo
O Tarciso não conseguiu montar na Raia-do-Rio: o personagem andava pelo fundo do rio (a superfície some vista de baixo), então a Raia parecia flutuar no ar e o "montar" era interrompido pela distância. Pedido: natação com animação, mergulho com fôlego, trocar o cardume antigo pelos peixes procedurais e pescar. Design em [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10 §7 e §8]].

## Critérios de pronto
- [x] Nadar em água com mais de 1,2 m (Swim_Idle / Swim_Fwd do UAL1), correnteza, Shift com Vigor, sem combate na água.
- [x] Mergulho (Ctrl desce, Espaço sobe), fôlego de 30 s com barra, afogamento tira Vida, véu azul embaixo d'água, superfície do rio visível por baixo.
- [x] Raia na margem do lado da vila; montar nadando funciona (a correnteza não cancela o montar).
- [x] Cardume antigo (`fish_school.gd` + shader) removido; Lambari, Traíra e Dourado procedurais com tamanho, cores, profundidade e fuga próprios; save antigo ganha os peixes novos.
- [x] Vara de Pesca (receita), lançar pela roda rápida, boia que atrai peixe real, fisgar no clique, briga com tensão, peixe vira item com ★ pelo porte.
- [x] Testes headless e prints no jogo.

## Próximo passo (uma frase)
Tarciso nadar até a Raia, mergulhar até acabar o fôlego e pescar um Dourado no poço da cachoeira, e dizer se os números (fôlego 30 s, força do Dourado, espera da mordida) estão bons.

## Log
- 2026-10-23 — Bloco criado e feito (Claude). Player: `_update_swim_state`, `_process_swimming`, `_update_oxygen`, sinal `oxygen_changed`, `set_hand_gear_visible`. As animações Swim_* do UAL têm a cabeça só ~26 cm acima da origem (medido no jogo), por isso o corpo boia com a origem 12 cm abaixo da superfície. HUD: barra de fôlego e véu embaixo d'água; `river_water.gdshader` passou a `cull_disabled`. `CreatureDNA`: espécies TRAIRA e DOURADO (no fim do enum, saves antigos continuam válidos); peixes comuns agora usam o tamanho da espécie (o Lambari tinha 1 m). `WildCreature._swim` novo (alvo por profundidade preferida, cardume do Lambari, fuga, isca, fisgado). `FishingComponent` novo + `vara_pesca`, `peixe_lambari/traira/dourado`. Ferramenta `tools/river_shots.gd` para prints do rio. Teste `test_swim_and_fishing.gd`; runner 24/24.
- 2026-10-23 — Correções após o Tarciso jogar (Claude): (1) não remontava na Raia depois de ir até a borda — ela guardava a velocidade do passeio e, ao montar de novo, o resto de embalo a jogava "para fora d'água", que desmonta na hora; agora a velocidade zera ao montar/descer e só desce quem empurra para a terra. Descer põe o cavaleiro na terra firme mais perto (antes podia cair a 7 m). O alcance do [E] conta da borda do corpo (`talk_radius`), o rótulo só diz "[E] Montar" quando alcança, e o [E] escolhe o mais perto entre montar e coletar. (2) Pedras: as do rio não tinham colisão e as do campo usavam uma esfera baixa; agora `RockCollision` dá a cada pedra a casca convexa da própria malha (pedrinhas com menos de 35 cm ficam passáveis). Runner 25/25.
