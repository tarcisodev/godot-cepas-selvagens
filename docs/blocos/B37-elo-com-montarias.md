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
- [x] Fase 4: Vida da montaria, morte permanente e Lembrança (`saudade`).
- [x] Fase 5: Faro e Olho de caça ([Q]).
- [x] Fase 6: Prova do Ninho (ninhos, oferenda Íntegra, voo bravio).
- [x] Testes em `tests/` e runner verde a cada fase.

## Próximo passo (uma frase)
Tarciso testar o B37 jogando (estábulo, apito, salto e pegada, morte e Lembrança, faro, Prova do Ninho) e ajustar os números; depois, revisar e fazer o merge do PR #23.

## Log
- 2026-10-29 — Bloco criado (Claude) com a proposta do GDD-16.
- 2026-10-29 — GDD-16 aprovado pelo Tarciso: montar continua 1,5 s; a Companheira recebe a ordem Seguir ou Ficar; 10–14 dias de jogo até a faixa plena.
- 2026-10-29 — Fase 1 implementada (Claude) no branch `feature/b37-elo-com-montarias`. `MountBond` (Elo, faixas, tetos diários pelo dia do relógio único, comida da espécie, fome, ciúme, save). Gene `indole` no `CreatureDNA` (sorteado por último, sem mudar os bichos que já existiam; saves antigos ganham índole pela seed). [E] em montaria própria abre a `MountCareDialog` (montar, alimentar, escovar no estábulo, Companheira, ordem, batizar). Companheira com Seguir anda/corre atrás do dono e para a 4 m; além do alcance do apito, espera. Saves antigos entram como capturadas no laço (Elo 10). Teste `tests/test_mount_bond.gd`.
- 2026-10-29 — Fase 2 implementada (Claude). Apito de Osso (3 Restos Ósseos + 1 Fibra no [Tab]; não se gasta). [H] chama a Companheira: o estábulo confere o alcance da faixa (60/150/300 m) e ela vem pelo mundo; a terrestre corre e contorna paredão (tenta 45° e 90° para cada lado), a voadora sobe a ~10 m, desce nos últimos 20 m e pousa ao lado. Desiste se o dono montar outra ou se não chegar em 60 s. As dicas da tela saíram do [H] para o [F2]. Teste `tests/test_mount_whistle.gd`.
- 2026-10-29 — Fase 3 implementada (Claude). Dano de queda para todo mundo, pela velocidade do impacto e via CombatResolver (parte `queda`; a esquiva não anula): até ~5 m nada, ~15 m −60, ~25 m ou mais a Vida inteira (antes da armadura de impacto). Cair na água e a Capa de Penas não machucam. Voando a mais de 3 m do chão, [E] salta da montaria com o embalo do voo; queda livre com braços abertos (`A_TPose`, corpo deitado; não há animação de queda livre nas bibliotecas UAL). Sem cavaleiro no ar, a voadora desce planando a 3 m/s. Caindo, [H] faz a Companheira plena voadora (a até 60 m, fôlego ≥ 20) mergulhar a 34 m/s; alcançou (2,5 m), você monta na hora. Falha se você pousar, cair na água ou levar dano antes. Derrubado da voadora no alto (Postura quebrada) também cai de verdade. Teste `tests/test_mount_air_catch.gd`.
- 2026-10-29 — Fase 4 implementada (Claude). Montaria própria tem Vida (tabela dos bichos selvagens pelo porte: Trotador TT 120, Planador TT 90) e hurtbox; o dano passa pelo CombatResolver. Na vila (zona segura) e pelo próprio dono não toma dano. Golpe forte (≥ 10% da Vida) com o dono montado tira Elo (`hurt`); 20 s sem apanhar, ainda montados, contam como fuga junto (`fight`, +2). Morreu: derruba o dono (no alto, ele cai), sai do estábulo e do save, e no lugar do corpo fica uma trouxa (`DroppedLoot`) com a Lembrança 3★ e o trait `saudade`, que qualquer um pega. Lembrança é tempero opcional das 9 receitas de armadura (cabeça, peito, botas, capa, mochila): Saudade = +5% de resistência a corte, impacto e perfuração. A Vida não vai para o save (volta cheia no load) e o nome dela não fica gravado na Lembrança. Teste `tests/test_mount_death.gd`.
- 2026-10-29 — Pedido do Tarciso: a Lembrança guarda o nome, e os itens guardam mais. Implementado (Claude): pilha pode ter `memory` (nome, espécie, Elo, dia da morte); só junta com memória igual e a memória vai para o chão, o save, o mercado da vila e a peça forjada (`ForgedItem.memory`, nome "… · Saudade de Estrela"). A tela de inventário mostra a linha "Memória".
- 2026-10-29 — Fase 5 implementada (Claude). `MountSenses`: montado na Companheira, segurar [Q] 1 s. Faro (Parceira): rastros (5 pegadas e o nome com a distância) de cada bicho vivo a até 60 m (90 m na voadora no ar) por 20 s. Olho de caça (plena): nas presas a até 25 m, marca a Vida (%, vermelha abaixo de 20%) e as partes que quebram (chifre, carapaça) por 8 s. Recarga 45 s; não dá dano. Os bichos selvagens comuns não têm hurtbox por parte, então neles o Olho mostra só a Vida. Teste `tests/test_mount_senses.gd`.
- 2026-10-29 — Fase 6 implementada (Claude). `PlanadorNest`: 2 ninhos nos topos mais altos do relevo (fora da vila, do rio e do estábulo; no mapa atual a ~25 m). [E] com carne Íntegra (e lugar no estábulo) deixa a oferenda; um adulto vem voando de 45 m e 22 m de altura, pousa e espera 60 s só por quem ofereceu. Outro jogador pode roubar a oferenda antes de ele chegar (ele dá meia-volta). Montar leva 1,5 s; aí o voo bravio (`BraveFlight`, 20 s): voltas altas em torno do ninho, e a cada tranco (seta no HUD) 0,9 s para segurar o lado oposto; errar o lado +0,3, deixar passar +0,25, acertar −0,05, golpe +0,4 na barra de queda. Domado: vira montaria própria marcada, Elo 50, e você segue voando nela; o ninho fica vazio por 3 dias de jogo. Caiu (ou saltou): queda livre de verdade e ele vai embora. `Mount` ganhou `autopilot`, `reserved_for` e `rider_mounted`. Limite: o estado dos ninhos não vai para o save. Teste `tests/test_nest_trial.gd`.
