---
type: block
status: done
created: 2026-10-25
updated: 2026-10-25
tags:
  - bloco
  - godot
  - equipamento
  - combate
  - boss
  - minerio
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B23 — Equipamento estilo Albion, boss, minério e golpes com peso

## Objetivo
Pedido do Tarciso (2026-10-25): 8 encaixes com famílias pano/couro/ferro e armas forjadas, veios de minério pelo mapa, um boss para testar o combate de verdade, golpes com mais peso e monstros sem aviso na tela. Design em [[03-Projects/Cepa-Selvagem/notas/GDD-12-Equipamento-e-encaixes|GDD-12]] e [[08-Knowledge/decisions/ADR-0007-cepa-encaixes-e-familias|ADR-0007]].

## Critérios de pronto
- [x] **Encaixes:** primária, secundária, cabeça, peito, botas, capa, mochila. Sai o de mãos; saves antigos de braçadeiras viram Couraça de Galhada.
- [x] **Família pelo revestimento** com o fator do GDD-12 §2.1; XP de armadura vai para a maestria da família de cada peça.
- [x] **Armas forjadas:** a primária define o estilo (espada sozinha, espada + escudo, mangual, cajado, punhos); duas mãos trava a secundária; dano × qualidade × núcleo. O Mestre de Armas dá armas de treino Q1.
- [x] **9 habilidades de armadura** nas teclas 4 / 5 / R com recarga e custo; chifre de Rinolito troca o Brado pela Investida. Barra no HUD.
- [x] **Mochila** com limite em kg e lentidão acima dele; **capas** com queda lenta e abrigo.
- [x] **Veios de Ferro e de Quartzo-Lume** nas encostas, com batidas múltiplas; **Fundir** barra de ferro na bigorna.
- [x] **Monstros sem aviso** (sem pisca vermelho nem "!").
- [x] **Peso:** hitstop local, tranco de câmera, empurrão, faíscas e som de impacto. Nada mexe no tempo do mundo.
- [x] **Rinolito Ancião** na Clareira do Ancião: 3 golpes com pose, fúria, partes quebráveis, atordoado, esfola, barra no HUD, volta em 10 min.
- [x] **Testes headless** dos itens acima; runner inteiro passando.

## Fora deste bloco

## Próximo passo (uma frase)
O Tarciso minerar ferro passando pelo Tatu-Espinho, caçar o bando de lobos à noite, forjar espada, escudo e cota, e enfrentar o Rinolito Ancião.

## Log
- 2026-10-25 — Bloco criado (Claude) depois de o Tarciso aceitar o GDD-12 §6 e pedir boss, minério, peso e fim do aviso.
- 2026-10-25 — Feito (Claude, pedido do Tarciso). **Encaixes:** `ForgedItem.Slot` = HEAD, BODY, FEET, MAIN_HAND, OFF_HAND, CAPE, BAG; `family` vem do revestimento (`Forge.RECIPES`, opção `family`) e o fator do GDD-12 §2.1 vale relativo à família de origem da receita (mesma receita de antes = mesmo item). Saves com `bracadeiras_galhada` viram `couraca_galhada` (`ForgedItem.RENAMED`). **Receitas novas:** Cota de Ferro, Couraça de Galhada, Botas de Saltarelo, Capa de Penas/Couro, Mochila, Espada de Ferro, Mangual, Cajado Arcano, Escudo; Fundir Barra de Ferro na bigorna. **Armas:** o estilo sai das armas (`Player.refresh_weapon_style`: espada, espada e escudo, mangual, cajado, punhos — estilos novos `sword.tres` e `unarmed.tres`); `weapon_power` = qualidade × núcleo multiplica o golpe (`_scaled_attack`); duas mãos trava a secundária. Kit de treino (espada + escudo Q1) no novo jogo e em saves antigos; o Mestre de Armas dá as de treino. **Habilidades:** `ArmorAbilities` (9 + Investida do chifre) e `ArmorAbilityComponent` nas teclas 4/5/R, com recarga, custo e barra no HUD. **Mochila:** limite 20 kg + mochila, lento acima, sem correr/esquivar acima de 150%; **capas:** queda lenta e abrigo. **Minério:** `GatherableResource` VEIO_FERRO (4 batidas) e VEIO_QUARTZO (3, brilha), grupos de 3–5 nas encostas altas (`_spawn_veins`). **Sem aviso:** `TestMonster` sem "!" nem pisca vermelho. **Peso:** `CombatFeel` (hitstop local 50–130 ms, empurrão, tranco de câmera `CameraRig.add_trauma`, faíscas e som pelo peso); nada mexe em `Engine.time_scale`. **Boss:** `BeastFighter` (bicho procedural que luta, guiado por config) + espécie RINOLITO no `CreatureDNA` (chifre no focinho e placas no dorso em pivôs próprios, poses head_low/rear/paw no `CreatureBody`); `BossLair` na Clareira do Ancião (sudoeste da vila, anel de pedras). XP de armadura por família. Teste `tests/test_equipment_and_boss.gd` (8 partes); runner 28/28. Prints em `tools/b23_shots.gd`. Achados nos prints e corrigidos: a pose de cabeça baixa estava com o sinal trocado, e a capa e a mochila apareciam no peito (no rig UAL a frente é +Z).
- 2026-10-25 — Lobo-do-Ermo e Tatu-Espinho (Claude, pedido do Tarciso; design no GDD-12 §12). Espécies LOBO e TATU no `CreatureDNA`; configs `BeastFighter.lobo_do_ermo()` (noturno pelo relógio único, bando com `pack_id`/`pack_slot` que cerca pelos flancos e acorda junto, bote que erra deixa tonto) e `tatu_espinho()` (territorial a 7 m, carapaça resiste a corte e quebra com impacto soltando placa, rolamento). `WildBeastSpawner`: 3 tocas com 3 lobos (pedras em meia-lua e ossos) e um tatu por grupo de veios de ferro (até 8). Materiais novos: Couro de Lobo (vale como couro; gibão +10% de durabilidade), Presa de Lobo (tempero *Serrilhado*, +6% de dano da arma), Garra de Tatu (tempero *Cravado*, +6% de Postura em botas e escudo). Teste `tests/test_wild_beasts.gd` (4 partes); runner 29/29. Prints em `tools/beasts_shots.gd`; nos prints o lobo estava de pescoço alto (parecia lhama) e o tatu redondo demais: ajustados. Capa nova da tela de título (`assets/ui/menu_background.png`, `tools/cover_shot.gd`).
- 2026-10-25 — Continuação (Claude). **Tocha na mão secundária:** acesa tira o escudo do estilo (fica a espada sozinha) e volta ao apagar; com arma de duas mãos o [T] recusa, e pegar uma arma de duas mãos apaga a tocha (`Player.refresh_weapon_style`, `TorchComponent`). **Desempenho** (RTX 3060, `tools/perf_beasts.gd`): os 18 BeastFighter custavam ~6,5 ms de física (62 → 41 FPS no acampamento); agora, parados a mais de 60 m do jogador, só pensam 4×/s e não mexem o corpo: acampamento 61 FPS (62 sem bichos), clareira do boss 35 → 51 FPS. **Tela de equipamento no [I]** (pedido do Tarciso): `EquipmentPanel` à esquerda da grade, com o boneco 3D do DNA do jogador vestido pelo mesmo `GearVisual` (arrastar gira, roda dá zoom), os 7 encaixes (clicar lista as peças daquele encaixe para equipar, ou tira) e resumo de Carga, mochila contra o limite, estilo e habilidades [4] [5] [R]. Teste `tests/test_equipment_panel.gd`; runner 31/31.
