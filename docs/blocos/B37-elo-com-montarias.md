---
type: block
status: active
created: 2026-10-29
updated: 2026-10-29
tags:
  - bloco
  - godot
  - montarias
  - vinculo
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B37 — Elo com montarias

## Objetivo
Implementar o [[03-Projects/Cepa-Selvagem/notas/GDD-16-Elo-com-montarias|GDD-16]]: Elo de 0 a 100 com as montarias próprias, Companheira única, apito de chamado, salto e pegada no ar, sentidos de caça, morte permanente e Prova do Ninho.

## Critérios de pronto
- [x] Fase 1: Elo, faixas, nome, gene `indole`, Companheira única, ordem Seguir/Ficar e save.
- [x] Fase 2: Apito de Osso ([H]); a Companheira vem pelo mundo, sem teleporte.
- [x] Fase 3: dano de queda, salto no ar e pegada no ar.
- [ ] Fase 4: Vida da montaria, morte permanente e Lembrança (`saudade`).
- [ ] Fase 5: Faro e Olho de caça ([Q]).
- [ ] Fase 6: Prova do Ninho (ninhos, oferenda Íntegra, voo bravio).
- [ ] Testes em `tests/` e runner verde a cada fase.

## Próximo passo (uma frase)
Tarciso testar as fases 1 a 3 jogando (estábulo, Apito de Osso, salto e pegada no ar) e liberar a Fase 4 (Vida da montaria e morte permanente).

## Log
- 2026-10-29 — Bloco criado (Claude) com a proposta do GDD-16.
- 2026-10-29 — GDD-16 aprovado pelo Tarciso: montar continua 1,5 s; a Companheira recebe a ordem Seguir ou Ficar; 10–14 dias de jogo até a faixa plena.
- 2026-10-29 — Fase 1 implementada (Claude) no branch `feature/b37-elo-com-montarias`. `MountBond` (Elo, faixas, tetos diários pelo dia do relógio único, comida da espécie, fome, ciúme, save). Gene `indole` no `CreatureDNA` (sorteado por último, sem mudar os bichos que já existiam; saves antigos ganham índole pela seed). [E] em montaria própria abre a `MountCareDialog` (montar, alimentar, escovar no estábulo, Companheira, ordem, batizar). Companheira com Seguir anda/corre atrás do dono e para a 4 m; além do alcance do apito, espera. Saves antigos entram como capturadas no laço (Elo 10). Teste `tests/test_mount_bond.gd`.
- 2026-10-29 — Fase 2 implementada (Claude). Apito de Osso (3 Restos Ósseos + 1 Fibra no [Tab]; não se gasta). [H] chama a Companheira: o estábulo confere o alcance da faixa (60/150/300 m) e ela vem pelo mundo; a terrestre corre e contorna paredão (tenta 45° e 90° para cada lado), a voadora sobe a ~10 m, desce nos últimos 20 m e pousa ao lado. Desiste se o dono montar outra ou se não chegar em 60 s. As dicas da tela saíram do [H] para o [F2]. Teste `tests/test_mount_whistle.gd`.
- 2026-10-29 — Fase 3 implementada (Claude). Dano de queda para todo mundo, pela velocidade do impacto e via CombatResolver (parte `queda`; a esquiva não anula): até ~5 m nada, ~15 m −60, ~25 m ou mais a Vida inteira (antes da armadura de impacto). Cair na água e a Capa de Penas não machucam. Voando a mais de 3 m do chão, [E] salta da montaria com o embalo do voo; queda livre com braços abertos (`A_TPose`, corpo deitado; não há animação de queda livre nas bibliotecas UAL). Sem cavaleiro no ar, a voadora desce planando a 3 m/s. Caindo, [H] faz a Companheira plena voadora (a até 60 m, fôlego ≥ 20) mergulhar a 34 m/s; alcançou (2,5 m), você monta na hora. Falha se você pousar, cair na água ou levar dano antes. Derrubado da voadora no alto (Postura quebrada) também cai de verdade. Teste `tests/test_mount_air_catch.gd`.
