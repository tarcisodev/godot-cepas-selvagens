---
type: block
status: ready
created: 2026-10-28
updated: 2026-10-28
tags:
  - bloco
  - godot
  - cutscene
  - intro
  - tutorial
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B34 — Intro: Jardim das Cepas + OG Dog

> Pacote de design no vault: `03-Projects/Cepa-Selvagem/blocos/B34-intro-og-dog/` ([[00 - Índice]]). A praia vem do [B36 — Ilha e litoral](B36-ilha-e-litoral.md): por enquanto o mundo é uma ilha e o spawn fica na foz do rio.

## Objetivo
Pedido do Tarciso: o jogo (18+) começa com uma cutscene feita na engine, não em vídeo, para ficar leve no celular. O jogador anda por um jardim de ervas, flores, frutas, sementes, cannabis e árvores; vê cepas lendárias (uma planta, um animal, um monstro e um bebê raro); sente o perigo; e conhece o **OG Dog**, um velho grisalho que dichava na mão uma flor rara curada, bola um baseado sem piteira, acende com fogo do dedo, dá um dois, conta um ensinamento histórico e passa o baseado. O jogador pega, ganha o buff **Visão da Cepa**, o OG Dog some em fumaça, tela preta, e o jogador acorda na praia sem nada: começo do tutorial de sobrevivência. Roteiro e regras: [[01 - Roteiro]], [[03 - Sistemas e regras]].

## Critérios de pronto
- [ ] **Tela 18+:** antes do primeiro menu, uma vez por dispositivo (`GameSettings` `legal/age_confirmed`); "Sair" fecha o jogo.
- [ ] **Flags:** `intro_seen` por personagem no save (`SaveGame.collect/apply_save`); `cutscenes/intro_watched_once` no `GameSettings`. Saves antigos não veem a intro.
- [ ] **`CutsceneDirector`:** beats como dados (`CutsceneBeat`), estados `LOADING → PLAYING → WAITING_INPUT → FADE_OUT → HANDOFF → DONE`, sinal `EventBus.intro_finished`.
- [ ] **Jardim:** cena `intro_garden.tscn` com flora por MultiMesh (geradores do B13) e 4 espécimes com aura de raridade.
- [ ] **OG Dog e ritual:** pote, dichavar, bolar sem piteira, chama do dedo, puxada, ensinamento, passa o baseado, some em fumaça. Legendas em pt-BR.
- [ ] **Interação:** prompt "[E] Pegar o baseado" / "Toque para pegar"; espera o input.
- [ ] **Visão da Cepa:** modificador do `StatsComponent` com fonte `visao_da_cepa`, **10 min reais**, coletáveis a 25 m com contorno ciano, +15% velocidade de coleta, +10% regen de Vigor (decidido pelo Tarciso; seguem tunáveis); não acumula, some no Caído, salva o tempo restante.
- [ ] **Praia:** fade preto e spawn em `BeachSpawn` com inventário e equipamento vazios; servidor aplica (ADR-0002); primeiro objetivo "Sobreviva. Encontre água e abrigo."
- [ ] **Kit inicial como recompensa:** `_grant_starter_explorer_kit` não roda no spawn; é entregue uma vez ao concluir o objetivo da praia (`starter_kit_granted` no save); personagens antigos não recebem de novo.
- [ ] **Ensinamento:** jogo novo usa o #3 (diamba/pango no Brasil); replay usa o #2 (cânhamo nos navios).
- [ ] **Pular:** sem botão na 1ª vez; da 2ª em diante "Pular ▶▶" (segurar 1 s / tocar e confirmar). Pular aplica o mesmo resultado.
- [ ] **Extras › Memórias:** replay no menu principal, sem rede, sem aplicar buff/spawn.
- [ ] **Acessibilidade:** legendas ligadas por padrão (P/M/G), "Reduzir flashes", volumes separados.
- [ ] **Desempenho:** ≥ 30 fps no renderizador mobile/web, ≤ 150k triângulos na cena.
- [ ] **Testes headless:** age gate, flags e migração, diretor (sequência, skip bloqueado/liberado, replay), buff, handoff na praia, kit como recompensa (idempotente). Runner inteiro passando.
- [ ] Prints: jardim lendário, chama do dedo, acordar na praia.

## Fora deste bloco
- Voz dublada do OG Dog, outras cutscenes, reaparição do OG Dog no mundo, outras recompensas do tutorial além do kit.

## Próximo passo (uma frase)
O Tarciso criar um personagem novo, assistir a intro sem poder pular, pegar o baseado e acordar na praia sem nada; depois revê-la em Extras › Memórias pulando.

## Log
- 2026-10-28 — Bloco rascunhado (Grok Bot) a pedido do Tarciso; pacote de design no vault.
- 2026-10-28 — Tarciso decidiu: números do buff, ensinamento #3 (replay #2), kit inicial como recompensa do tutorial; passe visual da vila renumerado para B35.
- 2026-10-28 — Tarciso decidiu: o mundo por enquanto é uma ilha (~360 m, o vale atual); praia de spawn na foz do rio; mar fundo com correnteza que devolve o nadador. Vira o bloco B36, feito antes da T07. Execução de T00–T09 de uma vez (Antigravity), branch `feature/intro-og-dog`.
