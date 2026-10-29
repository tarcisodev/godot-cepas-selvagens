---
type: block
status: active
created: 2026-10-28
updated: 2026-10-28
tags:
  - bloco
  - godot
  - cidade
  - visual
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B36 — Nova planta da Vila da Esperança

## Objetivo
Pedido do Tarciso (2026-10-28): reescrever a vila inicial da forma mais criativa possível e maior, mantendo os personagens e o que se faz nela. É o "replanejar a planta da vila" que o [[B35-passe-visual-da-vila|B35]] deixou para um bloco próprio. Nenhuma regra de jogo muda: as 5 obras, custos, Reputação, contratos, loja, mercado, missões e save continuam iguais.

## A planta
- **Forma:** elipse de 38 × 50 m (antes: círculo de 30 m) centrada em (−1, 15). Área ≈ 2,1× a antiga. O spawn (0, 0) fica na chegada da praça.
- **O rio é a muralha leste:** a paliçada pula a água, então do moinho até a feira quem fecha a vila é o rio.
- **3 portões com portal de madeira:** norte (covil e serra), oeste (arena) e **sul (novo, estrada de Porto Bruma)**. A placa entalhada "VILA DA ESPERANÇA" fica virada para fora; para dentro, o rumo da estrada.
- **Relevo:** dentro da elipse o ruído do vale é amansado (15%), a praça é plana e há a Colina da Capela (1,4 m) no sul. Transição suave até 35% além da paliçada.
- **Chão:** ruas de terra batida pintadas na cor do terreno (com borda suave), praça com calçamento procedural (Voronoi, pedras soltas na borda, anel claro em volta da árvore) e grama crescendo dentro da vila, fora de ruas e lotes.

## Bairros
| Bairro | O que tem |
|---|---|
| **Praça da Cepa-Mãe** (centro) | Árvore retorcida gigante de folhas vermelhas num canteiro de pedra, roda de 6 bancos, varal de lâmpadas coloridas da copa a 6 postes, Fogueira com tocos, Poço, Quadro de Obras + Mestre Construtor, Quadro de Missões, Baú, Marco de Viagem, Cronista do Mural |
| **Rua da Forja** (oeste) | Forja Pública, Bigorna, lenha, carrinho de minério |
| **Pátio de Armas** (oeste) | Cercado com 3 bonecos de treino, suporte de armas e o Mestre de Armas |
| **Ateliê da Alquimista** (pé do portão norte) | Bancada, caldeirão, poções, vasos e ervas |
| **Taverna** (sudoeste) | Taverna 6×6, varanda com Mesa de Cartas, mesa comprida, Caldeirão público, barris |
| **Feira** (sudeste) | Pavilhão do Mercado, Mercadora, bancas, carroça, varal de roupa, boutique da Estilista Astral e cadeira do Barbeiro |
| **Cais do Rio** (leste) | Píer de tábuas entrando no rio (alaga na cheia), pescador sentado na ponta |
| **Moinho** (nordeste) | Casa com roda d'água girando na correnteza |
| **Colina da Capela** (sul) | Capela no alto, Berçário, Horta cercada com espantalho, pomar |
| **Moradias** | 4 casas de cenário (não entram no Quadro de Obras) |

## Moradores novos (só conversa)
Seu Lambari (pescador), Dona Mó (moleira), Bento Caneca (taverneiro), Tia Rama (horta), Vó Brasa (contadora de histórias na fogueira), Guarda Tião (portão norte). `[E] Conversar` mostra uma fala curta.

## Noite
Lâmpadas do varal e lanternas das ruas e portais numa MultiMesh só, com shader que acende pelo relógio único (B22) e tremula. 6 luzes sem sombra que só ligam à noite (árvore, forja, taverna, feira, cais) + fogueira; as 6 luzes de portão continuam só com a Paliçada pronta.

## Arquivos
- `scripts/town/village_layout.gd` — planta inteira (elipse, praça, ruas, lotes, relevo, cor do chão). Mexer na planta = mexer só aqui.
- `scripts/city_hub.gd` — montagem dos bairros; economia e save sem mudança.
- `scripts/town/town_project.gd` — paliçada em elipse (`ring_radii`) e casas de cenário (`decorative`).
- `scripts/town/town_npc.gd` — `snap_to_ground` (pescador no píer).
- `materials/village_cobble.gdshader`, `materials/village_glow.gdshader`.
- Terreno, grama e zonas leem a planta (`landscape_generator.gd`, `grass_and_flowers.gd`, `zone_manager.gd`).
- `scenes/world.tscn` (Mestre de Armas, Barbeiro, Baú), `tutorial_trail.gd` (estações e textos), `world_settlements.gd` (capital, placas e estradas), `tools/village_shots.gd` (12 ângulos novos).

## Efeitos colaterais conhecidos
- Os arredores de 20 m sem totem (GDD-08 §8) contam da paliçada nova, então crescem junto. Três pontos de teste em `test_city_and_building.gd` foram afastados da vila; a regra não mudou.
- Passo 4 da Trilha ("coleta") agora sai pelo Portão Sul; passo 5 ("rio") termina no Cais.

## Critérios de pronto
- [x] Vila maior com bairros, portais, cais, moinho, colina e moradias.
- [x] Todos os NPCs e atividades antigas presentes (5 obras, loja, mercado, cosméticos, barbeiro, mestre de armas, mural, missões, cartas, caldeirão, capela, berçário, fogueira, bigorna, baú, marco).
- [x] Runner inteiro passando.
- [x] Prints em `build/b36/` (12 ângulos × dia/tarde/noite).
- [ ] FPS na praça medido com `tools/village_perf.gd` (teto do B35: −5%).
- [ ] Tarciso andar pela vila e aprovar.

## Log
- 2026-10-28 — Bloco criado e implementado (Claude, pedido do Tarciso). Branch `feature/b36-nova-vila-da-esperanca`.
