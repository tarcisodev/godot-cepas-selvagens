---
type: block
status: done
created: 2026-10-24
updated: 2026-10-25
tags:
  - bloco
  - godot
  - tempo
  - descanso
  - construcao
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B22 — Relógio único e Descansar

> B21 fica reservado para o Mapa [M] ([[03-Projects/Cepa-Selvagem/notas/GDD-11-Mapa|GDD-11]]), que ainda tem perguntas em aberto.

## Objetivo
Pergunta do Tarciso: o "Esperar" avança o jogo inteiro ou só o sol? Hoje só o sol: adianta 4 h, anda para trás depois da meia-noite e não vira o dia (a lua não avança). Plantas, bichos e clima não ficam sabendo. Decisão aceita ([[08-Knowledge/decisions/ADR-0006-cepa-relogio-unico-sem-pulo|ADR-0006]]): o relógio do mundo é um só e nunca pula; o Esperar sai e vira **Descansar**, que mexe só no personagem. Design e números em [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10 §10]].

## Critérios de pronto
- [x] **Relógio único:** a duração do dia vem só do `DayNightCycle`. `WildCreature.DAY_SECONDS` sai; fome, sede, idade e reprodução usam o relógio. Os timers de fruta caída e esterco da `Ecology` acompanham uma mudança da duração do dia.
- [x] **Sem pulo:** o botão Esperar sai do menu de ações. Nenhum código de jogo escreve em `current_time_hours`, a não ser o próprio relógio e o load do save.
- [x] **Descansar:** o botão do menu (no lugar do Esperar) senta. Sentado ou deitado na cama, a Vida volta a **0,5%/s** no chão, **2%/s** a até 4 m de uma Fogueira acesa ou sentado num Banco, e **3%/s** na sua Cama. Fora de descanso a Vida não volta.
- [x] **Interrupção:** andar, atacar, lançar magia, levar dano, montar ou entrar na água tira do descanso. O descanso não começa com combate (dano dado ou recebido) há menos de 10 s; o HUD diz o motivo.
- [x] **Descansado:** depois de 60 s descansando em fogueira, banco ou cama, o buff dura **15 min reais** e dá **+25% na volta de Vigor e Éter**. É um modificador do `StatsComponent` com fonte `descanso`, não acumula, renova ao descansar de novo e some quando o jogador fica Caído. Aparece no HUD com o tempo que falta.
- [x] **Peças novas** no `BuildablePiece` (catálogo do GDD-08): **Fogueira** (4 Pedra + 3 Galho, com fogo e luz), **Banco** (3 Madeira), **Cama** (4 Madeira + 4 Fibra, 1 por personagem). Fogueira e banco são de uso público; a cama é só do dono.
- [x] **Fogueira pública na vila**, junto do acampamento.
- [x] **Cama = renascer:** deitar na sua cama marca o `spawn_point`. Caído volta para a cama marcada; se ela não existe mais, volta ao acampamento. O save guarda a cama marcada e o buff Descansado.
- [x] **Testes headless:** relógio (mudar a duração do dia muda o ritmo de bicho, planta e fruta); taxas de Vida por lugar; interrupção e bloqueio de 10 s pelo combate; buff aplicado, renovado e removido no Caído; renascer na cama e de volta ao acampamento sem cama; save e load. Runner inteiro passando.
- [x] Print: jogador descansando na fogueira de noite.

## Fora deste bloco
- Duração do dia no online, fogueira de viagem fora do totem e XP no descanso ficam como perguntas em aberto (GDD-10 §10.6).

## Próximo passo (uma frase)
O Tarciso descansar na fogueira da vila de noite, construir uma cama no totem e cair de propósito para ver se volta para ela.

## Log
- 2026-10-24 — Bloco criado (Claude) depois de o Tarciso aceitar a ADR-0006 e os números do GDD-10 §10.
- 2026-10-25 — Feito (Claude, pedido do Tarciso). **Relógio:** `DayNightCycle.seconds_per_day()` (instância única do sol) é a duração do dia para a `Ecology` e a `WildCreature` (`DAY_SECONDS` saiu); fruta caída e esterco apodrecem por `rot_days` contado no `step` da natureza, no lugar de timers de 300 s. **Esperar** saiu da cena e do `actions_menu.gd`; o botão de sentar virou "🔥 Descansar (sentar)". **`RestComponent`** novo no jogador: taxa de Vida por lugar (chão 0,5%/s, fogueira a 4 m ou banco a 1,3 m 2%/s, cama 3%/s), bloqueio de 10 s depois de dano dado/recebido (`hit_resolved` e queda de Vida), dano/montar/água tiram do descanso, buff Descansado (2 modificadores `PCT_ADD` +25% em `vigor_regen` e `ether_regen`, fonte única, 15 min reais, renova sem acumular, some no Caído), linha no HUD. **Peças:** `FOGUEIRA` (4 Pedra + 3 Galho, `Campfire` com chama e luz), `BANCO` (3 Madeira, [E] senta), `CAMA` (4 Madeira + 4 Fibra, [E] deita, só o dono, 1 por personagem); catálogo com 11 entradas, teclas 1–0 e roda do mouse no modo construção. **Fogueira pública** no acampamento (`city_hub.gd`). **Cama:** `Player.lie_in_bed`, `marked_bed` e `respawn_point()`; Caído volta para a cama ou para o acampamento. Save guarda `rest` e `bed`. Teste `test_rest_and_clock.gd` (6 partes); runner 27/27. Ferramenta `tools/rest_shots.gd`. Bug achado no teste e corrigido: o primeiro aviso de Vida contava como dano e levantava o jogador.
