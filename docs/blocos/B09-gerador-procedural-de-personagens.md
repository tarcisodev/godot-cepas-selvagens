---
type: block
status: done
created: 2026-10-21
updated: 2026-10-22
tags:
  - bloco
  - godot
  - personagens
  - procedural
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B09 — Gerador procedural de personagens

## Objetivo
Parar de depender de modelos prontos de personagem: gerar humanoides por código a partir de um `CharacterDNA` (seed + parâmetros), com skin no rig UAL para reaproveitar todas as animações ([[08-Knowledge/decisions/ADR-0004-cepa-personagens-procedurais|ADR-0004]]).

## Decisões fechadas com o Tarciso (2026-10-21)
- Geometria: malha procedural com skin no esqueleto UAL de 65 ossos.
- Escopo: só humanoides (jogador e NPCs); as criaturas ficam para depois.
- Entrada: seed + parâmetros (`CharacterDNA`), sem ligar ao genoma por enquanto.

## Critérios de pronto
- [x] `CharacterDNA` (Resource): seed, altura, massa, forma do corpo, proporções, cabeça, pele, cabelo, barba e roupa; `randomized(seed)` determinístico; `to_dict`/`from_dict`.
- [x] `ProceduralCharacterBuilder`: esqueleto com proporções do DNA + malha com skin + material.
- [x] Correção da pelve animada pela razão da perna.
- [x] `CharacterVisual` aceita `dna` no lugar de `model_scene`, com a arma e as animações funcionando igual.
- [x] Cena de demonstração com uma grade de personagens aleatórios e uma tecla para sortear de novo.
- [x] Teste headless: determinismo, contagem de ossos, pesos válidos e animação tocando.

## Próximo passo (uma frase)
Concluído. Melhorias de visual ficam para depois (pedido do Tarciso).

## Log
- 2026-10-21 — Bloco criado; escopo fechado com o Tarciso; ADR-0004 proposta.
- 2026-10-21 — Gerador implementado: `CharacterDNA` (scripts/data), `ProceduralCharacterBuilder` (scripts/systems; tronco, membros, mão em luva + polegar, sapato, cabeça com olhos/nariz/boca/orelhas, 7 cabelos, 3 barbas, roupa por cor de vértice com barra nítida), `PelvisHeightModifier` (pé no chão com perna de 0,88 a 1,12) e `CharacterVisual.dna` + `rebuild()`. Cena `scenes/character_lab.tscn` (R sorteia, 1–6 animação, T gira). `tests/test_procedural_character.gd` passa (DNA determinístico, 30 rigs com pesos válidos, pés no chão animados); suítes antigas seguem verdes. Pegadinha: a pose corrigida por SkeletonModifier3D só é legível no sinal `modification_processed`, porque o Godot a restaura depois do frame.
- 2026-10-21 — Player e dummy trocados para DNA: `resources/characters/player_dna.tres` (patrulheiro de barba, manga longa, luva e bota alta) e `brute_dna.tres` (brutamontes moicano, escala 1,3, no lugar do Puglin; o chifre continua preso no osso Head). Testes verdes; conferido no world.tscn.
- 2026-10-21 — Barbeiro (NPC de aparência) no acampamento, ao lado do Mestre de Armas: [E] abre editor com prévia 3D (arrastar gira, zoom no rosto), gênero Masculino/Feminino, abas Corpo/Rosto/Cabelo e barba/Roupa, Sortear/Cancelar/Aplicar. DNA ganhou `hair_length`, `beard_length` e o cabelo Juba (MANE); cabelo longo agora vai do ombro ao meio das costas com mechas na frente, barba cheia desce em ponta até o peito. Barba liberada para qualquer gênero. Aparência entra no save (`appearance`). `tests/test_character_stylist.gd` passa; runner 10/10.
- 2026-10-21 — Criação de personagem no Novo jogo: editor extraído para o componente `AppearanceEditor` (scripts/ui), usado pelo Barbeiro e pela nova `scenes/character_creation.tscn` (nome + aparência; "Voltar" não apaga o save). `SaveGame.start_new_game(dna, nome)` veste o DNA ao entrar no mundo e grava o primeiro save; nome vai para o save e aparece em "Continuar — Nome". test_character_stylist com 4 etapas passa.
- 2026-10-22 — ADR-0004 aceita pelo Tarciso ("depois melhoramos"); bloco concluído. NPCs da vila e trabalhadores já usam DNA (`TownNPC`, B11).
