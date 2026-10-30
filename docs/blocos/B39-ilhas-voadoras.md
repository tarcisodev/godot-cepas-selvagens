---
type: block
status: active
created: 2026-10-29
updated: 2026-10-30
tags:
  - bloco
  - godot
  - mundo
  - procedural
  - montarias
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B39 — Ilhas voadoras

## Objetivo
Implementar o [[03-Projects/Cepa-Selvagem/notas/GDD-18-Ilhas-voadoras|GDD-18]]: ilhas voadoras procedurais em cinco raridades (comum, incomum, rara, lendária, mítica), alcançadas por Correntes de vento com a voadora, com agenda calculada da seed e do relógio único (igual para todos, ADR-0002 e ADR-0006), conteúdo por raridade, afundamento com queda real e a mítica como evento do mundo.

## Critérios de pronto
- [x] GDD-18 aprovado pelo Tarciso (perguntas do §13 respondidas em 2026-10-30).
- [x] Fase 1: `SkyIslandSchedule` (função pura: seed + relógio → ilhas ativas) e `SkyIslandShape` (malha e colisão por raridade) e `SkyIslandField` no mundo, com todas as raridades da agenda. (A silhueta de longe e o conteúdo de perto ficam para a fase 3, quando houver conteúdo.)
- [x] Fase 2: Corrente de vento sob cada ilha; teto de voo relativo à ilha (`Mount.AIR_CEILING` continua 40 m); descida planada fora da Corrente.
- [x] Fase 3: flora, veios (Quartzo-Lume, Cristal-de-Vento, Ferro-Celeste, Âmbar-Estelar), baús e ninhos por raridade; renovação.
- [ ] Fase 4: deriva, troca de lugar, surgir e afundar; quem fica cai de verdade; save do estado que muda (veio, baú, chefe).
- [ ] Fase 5: rajadas, raios na família ferro, Zona Selvagem no `ZoneManager` e aviso no HUD.
- [ ] Fase 6: Guardião da Ruína; anúncio da mítica no `CelestialSky`; espécie mítica e chefe mítico.
- [ ] Fase 7: sombras das comuns no mapa [M].
- [ ] Testes em `tests/` e runner verde a cada fase. Branch `feature/b39-ilhas-voadoras` a partir do master, PR ligado a uma Issue. Cópia deste bloco em `docs/blocos/`.

## Próximo passo (uma frase)
Tarciso revisar os PRs das fases 1–2 e 3 (voar até uma Ilhota, minerar, abrir o baú) e liberar a Fase 4 (ciclo, aviso de afundamento e save).

## Log
- 2026-10-29 — Bloco criado (Claude, pedido do Tarciso) com a proposta do GDD-18. Numerado B39 porque o B38 e o GDD-17 já são da Costelária. Aguardando aprovação; nenhum código ainda.
- 2026-10-30 — Fases 1 e 2 feitas (Claude, Issue #27, branch `feature/b39-ilhas-voadoras`). **Agenda:** `SkyIslandSchedule.islands_at(seed, dia)` é uma função pura: 6 comuns fixas, 3 incomuns em órbita de 18 m (renovam a cada 4 dias), 2 raras que derivam e trocam de lugar a cada 2 dias (uma em cada metade do vale), lendária a cada 3 dias por 6 h e mítica a cada 7 dias por 2 h, com 1 h de anúncio (coluna de luz); surgir e afundar levam 10 min de jogo e percorrem 40 m. As faixas de altura foram ajustadas para os volumes nunca se cruzarem: 55–65, 80–90, 105–115, 130–140 e 155–165 m. **Forma:** `SkyIslandShape` (topo recortado com relevo, base em cone com saliências, cor por raridade) gera a malha, a colisão e o chão da montaria. **Mundo:** `SkyIslandField` na `world.tscn` segue o relógio a cada 0,5 s; cada `SkyIsland` é um `AnimatableBody3D` que carrega quem está em cima. **Corrente:** coluna de 8 m de raio na borda de cada ilha (shader `sky_current`, fiapos subindo); dentro dela a voadora sobe a 8 m/s até 12 m acima do topo; em cima, a ilha é o chão (teto 40 m acima dela); embaixo, a base não se atravessa; acima do teto e fora da Corrente, desce planando a 3 m/s em vez de ser cortada. Bug achado nos prints e corrigido: a ilha nascia na origem e levava o jogador da vila até o céu (agora nasce no lugar; teste cobre). Teste `tests/test_sky_islands.gd` (4 partes); prints em `tools/sky_island_shots.gd`. **Limites:** ilhas ainda sem conteúdo (fase 3), mítica sem as ilhotas satélites (fase 6), Correntes sem rajadas nem liga/desliga (fase 5), sem aviso de afundamento, a Companheira chamada pelo apito não sobe pela Corrente, e o `server_world.tscn` ainda não tem o céu.
- 2026-10-30 — Fase 3 feita (Claude, branch `feature/b39-fase-3-conteudo`, empilhado no PR das fases 1–2). **Minérios novos:** Cristal-de-Vento (40 $S), Ferro-Celeste (70) e Âmbar-Estelar (160), com veios próprios no `GatherableResource` (3, 5 e 6 batidas; não voltam sozinhos). As receitas de forja que usam esses minérios ainda não existem. **Conteúdo por raridade** (`SkyIslandContent`): Ilhota com fibra, erva, pedra e galho, e **2 das 6 com ninho de Planador** (regra fixa pela seed, porque com 35% de chance a seed 2026 não tinha nenhum); Ilha de Musgo com 1 veio de Quartzo-Lume e o Baú de Musgo; Ventania com 3 veios de Cristal-de-Vento e o Baú da Ventania; Ruína com 3 de Ferro-Celeste, pilares quebrados e o Baú da Ruína; Eclipse com 1 de Âmbar-Estelar, cristais coloridos e o Relicário. Os enfeites crescem com a área da ilha. **Perto/longe:** o conteúdo nasce com jogador a 150 m e some sem ninguém a 200 m; o que foi pego (veio esgotado ou pela metade, baú aberto, ninho vazio) fica em `SkyIslandField.content_state` pela chave ilha@época; ninho com prova em andamento segura o conteúdo. A incomum se renova na época nova; a ilha que sai do céu leva o estado junto. `WildChest` ganhou título, material de recompensa e `snap_to_ground` (o baú descia até o vale); o `PlanadorNest` usa o chão da ilha. **Bug achado nos prints e corrigido:** `BeastFighter` media só a distância horizontal, e o Rinolito Ancião "lutava" com quem estava na Ilha-Ruína 130 m acima. Agora quem está a mais de 15 m de altura não é alvo (teste no `test_equipment_and_boss`). Teste novo `tests/test_sky_island_content.gd` (5 partes). **Limites:** `content_state` ainda não vai para o save (fase 4); baús das ilhas não dão carta (a carta por raridade fica para depois); a flora é só de coleta (sem PlantBody nem Pinheira-Lume, para não entrar no ciclo e no save da natureza do vale).
