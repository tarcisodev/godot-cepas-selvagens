---
type: block
status: done
created: 2026-10-22
updated: 2026-10-22
tags:
  - bloco
  - godot
  - ecologia
  - clima
  - rio
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B15 — Rio de verdade e ciclo natural

## Objetivo
Melhorar o cenário (rio com profundidade) e implementar o [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10]]: ciclo da água com nuvens e chuva, solo com umidade e nutrientes, plantas que nascem/crescem/dão fruto/semeiam/morrem e bichos que comem, bebem, se reproduzem e morrem.

## Critérios de pronto
- [x] Rio com leito fundo (até 2,8 m), barranco nítido, malha de 1 m, água com cor pela profundidade, transparência no raso, espuma na margem, pedras nas margens e respingo na cachoeira.
- [x] Clima: calor, umidade, nuvens visíveis e chuva com efeito no céu e no solo.
- [x] Solo em grade com umidade e nutrientes.
- [x] Plantas com ciclo de vida, frutos, sementes e mutação por nutriente.
- [x] Bichos com fome, sede, reprodução e morte natural devolvendo nutriente.
- [x] Testes, prints e desempenho.

## Próximo passo (uma frase)
Tarciso jogar uns dias de jogo e ver chuva, cheia e lua; depois: nuvens mais bonitas, carga mais rápida (7,5 s) e salvar o ecossistema.

## Log
- 2026-10-22 — Bloco criado (Claude) a partir do pedido do Tarciso; rio refeito.
- 2026-10-22 — Implementado (Claude). **Rio:** corte em "U" até 2,8 m, barranco nítido, várzea, malha de 1,2 m, shader com profundidade real (transparente no raso, escuro no fundo, refração, espuma na margem), pedras nas margens e respingo na cachoeira. **Mapa:** 360 × 360 m (`WorldBounds.HALF`), relevo mais bravo longe do centro, 4 picos novos; spawners por fração do mapa. **Clima** (`WeatherSystem`): calor → umidade → nuvens → chuva (~15% do tempo, pancadas de ~2 min a cada ~2 dias), céu e luz escurecem com nuvem, névoa e partículas de chuva; **cheia e vazão** no `RiverSystem.flood` (até 1,4 m, alaga a várzea). **Lua** (`Moon` + fases no `DayNightCycle`): 28 dias, luar pela fase, céu escuro à noite (antes ficava azul). **Ecologia** (`Ecology`): solo em células de 6 m (umidade, nutrientes), plantas em 6 estágios com fruto que cai como frutinha e semente que brota em volta; mutação de 3% a 12% pelo nutriente; morte devolve nutriente. **Bichos:** fome e sede, bebem na margem, comem fruta/arbusto ou pastam, reproduzem (filhote com `cross`), envelhecem e morrem; população mín./máx. por espécie. Teste `tests/test_natural_cycle.gd`; runner 19/19; simulação acelerada de 4 dias sem erro (chuva, cheia de 0,57 m, plantas 195 → 420, 8 mutantes, filhotes). FPS 94 (era 113) e carga 7,5 s no mapa grande.
