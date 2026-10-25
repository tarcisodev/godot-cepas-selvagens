---
type: block
status: done
created: 2026-10-23
updated: 2026-10-24
tags:
  - bloco
  - godot
  - ecologia
  - genetica
  - flora
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B20 — Pinheira-Lume

## Objetivo
Pedido do Tarciso: uma árvore parecida com a araucária, que brilha no escuro e dá frutos como o pinhão; cultivável, com semente que carrega genética (cor da luz, copa e fruto mudam), frutos procedurais de mandala e Fibonacci, broto visível a partir de 2 dias, e dentro do ciclo natural: bichos comem, espalham a semente no esterco, e pinha esquecida no chão brota. Design em [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10 §9]] (decisões do Claude como game designer; o Tarciso revisa jogando).

## Critérios de pronto
- [x] `PlantDNA.Kind.PINHEIRA` (no fim do enum) com genes copa, brilho, lume, forma, simetria, escamas; cruzamento de dois pais; genoma em código curto para o trait do pinhão.
- [x] Corpo procedural: tronco alto, verticilos por copa, tufos e pinhas que brilham à noite (material emissivo + luz na adulta); pinha Fibonacci e pinha mandala.
- [x] Ciclo: semente 2 dias até o broto, safra com pólen da vizinha, pinhas caídas que brotam, teto de 36 no vale, Pinheiras iniciais no vale.
- [x] Bichos comem a pinha, carregam a semente e soltam no esterco (ave solta voando).
- [x] Jogador abre a pinha, sacode a árvore e planta com [G] (canteiro dentro da vila); inventário mostra o genoma e escolhe o pinhão.
- [x] Save: pinhas no chão e sementes na barriga dos bichos.
- [x] Testes headless e prints de dia e de noite.

## Próximo passo (uma frase)
O Tarciso plantar um pinhão, esperar o broto e ver de noite as cores diferentes.

## Log
- 2026-10-23 — Bloco criado (Claude) a partir do pedido do Tarciso.
- 2026-10-23 — Feito (Claude). `PlantDNA`: `Kind.PINHEIRA` no fim do enum, genes copa/brilho/lume/forma/simetria/escamas, `cross`, `sprout`, `genome_code`/`from_genome_code`, `describe`; o trait `gen_…` do pinhão aparece legível em `MaterialData.trait_name`. `PinhaShape` novo (pinha Fibonacci por ângulo de ouro com faixas nas espirais de 13 e 8; mandala por anéis) + shader emissivo único com `night` vindo da `Ecology`. `PlantBody`: broto próprio, 4 copas, estróbilos acesos na florada, pinhas no alto dos galhos, `OmniLight3D` na adulta (grupo `lume_lights`), contrato harvestable para sacudir; montinho de terra no pinhão plantado. `PinhaFruit` novo (abrir, comer, brotar em 1,5 dia). `Ecology`: `drop_pinhas` com `pollen_father`, `plant_seed`/`plant_by_player` (canteiro com solo fixo 0,7), `drop_dung`, teto de 36. `WildCreature`: `gut`, `_digest`, `_forage` do Planador. Spawner: 2 bosques de 4; save guarda pinhas, canteiro/dono e barriga; save antigo ganha os bosques. Material `pinhao_lume` (ferramenta `plantar`), botão "Plantar este com [G]" no inventário. Teste `test_pinheira.gd` (6 partes); runner 26/26. Ferramenta `tools/pinheira_shots.gd` (fileira de genomas de dia/noite e close das pinhas).
- 2026-10-24 — Crescimento contínuo (Claude, pedido do Tarciso): `PlantBody.PINHEIRA_GROWTH` dá a escala [começo, fim] de cada etapa e `growth_scale()` segue o progresso; broto e jovem processam e alcançam esse tamanho suavemente. `build(animate, sparkle)`: na troca, a malha velha vai para um irmão `PlantaSaindo` que encolhe em 0,7 s enquanto a nova sai do zero (ou só "respira" se o tamanho não muda) e há faíscas na cor do lume. Vale também para as outras plantas (sem faíscas). Teste `test_pinheira.gd` parte 7; runner 26/26. Ferramenta `tools/pinheira_growth_shots.gd`.
