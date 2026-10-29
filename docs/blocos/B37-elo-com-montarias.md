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
- [ ] Fase 2: Apito de Osso ([H]); a Companheira vem pelo mundo, sem teleporte.
- [ ] Fase 3: dano de queda, salto no ar e pegada no ar.
- [ ] Fase 4: Vida da montaria, morte permanente e Lembrança (`saudade`).
- [ ] Fase 5: Faro e Olho de caça ([Q]).
- [ ] Fase 6: Prova do Ninho (ninhos, oferenda Íntegra, voo bravio).
- [ ] Testes em `tests/` e runner verde a cada fase.

## Próximo passo (uma frase)
Tarciso testar a Fase 1 no estábulo (capturar, alimentar, batizar, escolher a Companheira, Seguir/Ficar) e liberar a Fase 2 (Apito de Osso).

## Log
- 2026-10-29 — Bloco criado (Claude) com a proposta do GDD-16.
- 2026-10-29 — GDD-16 aprovado pelo Tarciso: montar continua 1,5 s; a Companheira recebe a ordem Seguir ou Ficar; 10–14 dias de jogo até a faixa plena.
- 2026-10-29 — Fase 1 implementada (Claude) no branch `feature/b37-elo-com-montarias`. `MountBond` (Elo, faixas, tetos diários pelo dia do relógio único, comida da espécie, fome, ciúme, save). Gene `indole` no `CreatureDNA` (sorteado por último, sem mudar os bichos que já existiam; saves antigos ganham índole pela seed). [E] em montaria própria abre a `MountCareDialog` (montar, alimentar, escovar no estábulo, Companheira, ordem, batizar). Companheira com Seguir anda/corre atrás do dono e para a 4 m; além do alcance do apito, espera. Saves antigos entram como capturadas no laço (Elo 10). Teste `tests/test_mount_bond.gd`.
