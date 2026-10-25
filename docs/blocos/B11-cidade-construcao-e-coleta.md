---
type: block
status: done
created: 2026-10-22
updated: 2026-10-22
tags:
  - bloco
  - godot
  - construcao
  - coleta
  - cidade
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B11 — Cidade, construção e coleta

## Objetivo
Registrar e revisar um protótipo que entrou no repo **antes do design**: coleta de 10 recursos do mapa, zonas do mundo (cidade, perigo, natureza), totem de território, construção modular e a cidade inicial (Vila da Esperança). O código está pronto e testado; falta o Tarciso decidir o que fica e levar as regras para o GDD.

## Origem
Feito em 2026-10-21 (~19h55–20h16) por um agente sem bloco nem handoff (provavelmente o Antigravity, pelo estilo). Achado e registrado pelo Claude em 2026-10-22. Fere o princípio "design antes de código" — por isso entra como **review**, não como done.

## O que existe no jogo

### Coleta (`scripts/gatherable_resource.gd`, `gatherable_spawner.gd`)
- 10 recursos: Madeira (tronco), Galho, Folha, Fibra, Pedra, Frutinha, Besouro, Ossos, Erva e Mel. [E] coleta usando o mesmo fluxo da esfola (segurar, animação, interrompe ao andar/atacar).
- Tempo de coleta de 0,3 s (besouro) a 1,5 s (mel), encurtado pela maestria. Renascem entre 25 s (galho) e 60 s (mel).
- Maestria: 3 tags novas no `MasteryComponent` — `lenharia` (madeira), `mineracao` (pedra) e `coleta` (o resto).
- Mel: coletar sem proteção dá −4 Vida e −8 Vigor (abelhas).
- Spawner espalha ~173 nós pelo mapa por regra ecológica: espalhados, beira de rio, encostas e áreas de risco.

### Zonas (`scripts/core/zone_manager.gd`)
- **Cidade:** círculo de raio 16,5 m em (1,5; 4,5) — sem combate e sem construção.
- **Perigo:** Arena de Teste (−17; 6, r 14) e Covil da Besta de Sucata (−3,5; −6,5, r 9,5) — sem construção.
- **Água:** leito do rio — sem construção.
- **Natureza:** o resto — constrói só dentro de um totem.
- O HUD mostra o nome da zona; o Player não ataca em zona de cidade.

### Território e construção (`claim_totem.gd`, `buildable_piece.gd`, `building_system.gd`)
- **Totem de Território** (4 madeira + 4 pedra): reivindica raio de 14 m, anel no chão, não pode sobrepor outro totem.
- [B] liga o modo construção (também pelo menu de ações); teclas 1–7 escolhem a peça; prévia fantasma verde/vermelha com grade de 1 m; consome material do inventário.
- Peças: Piso (2 madeira), Parede (3 madeira + 1 fibra), Parede com porta que abre (4 madeira + 1 fibra), Telhado (2 madeira + 2 folha), Cerca (2 galho + 1 fibra), Canteiro (2 madeira + 2 erva), Bancada do Rancho (4 madeira + 2 pedra). Desmontar devolve material.

### Cidade (`scripts/city_hub.gd`)
- Vila da Esperança em volta do acampamento: placa, praça com banca e carroça, estandartes, ruas de pedra, Portão Norte e Leste com tochas.
- 2 NPCs: Alquimista Botânica e Mestre Construtor — por enquanto só falam (modelos `Female_Peasant`/`Male_Peasant`, não DNA do B09).

### Ajustes soltos no mesmo lote
- Pegada da espada, do martelo e do cajado na mão trocada; cajado com animação de pistola (`Pistol_Aim_Neutral`/`Pistol_Shoot`) na mira.
- Projétil do cajado sai da ponta da arma.
- Menu de ações lista os materiais coletados com ícone.

## Conflitos com o GDD e pendências
- [x] **GDD:** [[03-Projects/Cepa-Selvagem/notas/GDD-08-Territorio-construcao-e-coleta|GDD-08]] fechado em 2026-10-22 (§8); a lista de mudanças de código está lá.
- [x] **Maestria:** `lenharia` removida; madeira dá XP de `coleta`; saves antigos descartam a tag.
- [ ] **Materiais:** os 10 recursos não têm `MaterialData` (GDD-06) e a coleta não rola 1★/2★. Bloqueado: o `InventoryComponent` só guarda contagem por id, inclusive para a caça. Precisa de um bloco próprio para estoque com qualidade.
- [ ] **Zonas x GDD-05:** a cidade aqui é zona segura sem combate; o GDD-05 fala de Zona Selvagem com full loot e duelo consensual. Ligar as duas coisas.
- [x] **Regras de zona do GDD-08:** duelo libera ataque na cidade (`Player.in_duel`, ainda sem convite), totem a ≥ 20 m da borda da vila e ≥ 6 m de outro território, 1 totem por dono, zona `WILD_PVP` sem construção (lista de áreas vazia por enquanto).
- [ ] **Dono em rede:** o dono é o nome do nó do player (`Player`), não o nome do personagem; serve no single-player, precisa de id real com o servidor (ADR-0002).
- [x] **Save:** totens e peças entram no `SaveGame` (tipo, dono, posição, rotação); carregadas não ganham a janela de 100%.
- [x] **Código duplicado:** catálogo único montado de `ClaimTotem` + `BuildablePiece.PIECE_CONFIG`; a Bancada do Rancho entrou (teclas 1–8).
- [x] **Desmontar:** [X] no modo construção desmonta a peça/totem do dono perto da prévia; 50% de volta, 100% nos 2 primeiros minutos; totem só sai com o território vazio.
- [ ] **NPCs da vila** deveriam usar `CharacterDNA` (próximo passo do B09).
- [ ] Jogar no mundo: só foi verificado pelos testes headless, não visto em jogo.

## Critérios de pronto (do que já existe)
- [x] 10 recursos coletáveis com maestria e renascimento.
- [x] Zonas com regras de combate/construção e nome no HUD.
- [x] Totem, modo construção e 7 peças com custo e reembolso.
- [x] Vila da Esperança com praça, portões e 2 NPCs.
- [x] `tests/test_gatherable_resources.gd` (6 etapas) e `tests/test_city_and_building.gd` (5 etapas); runner 12/12.

## Próximo passo (uma frase)
Tarciso jogar a vila e o modo construção (1–8, [X] desmonta) e decidir se abre o bloco de estoque com qualidade (`MaterialData`) para fechar o 1★/2★ da coleta.

## Log
- 2026-10-22 — Bloco criado pelo Claude a partir do trabalho achado sem commit; testes rodados (12/12 verdes); commit `d83030d` enviado ao GitHub.
- 2026-10-22 — GDD-08 rascunhado (Claude): Totem = rancho do GDD-04, coleta comum como material barato de qualidade baixa, zonas encaixadas no GDD-05, manutenção do totem como ralo de moeda.
- 2026-10-22 — GDD-08 §8 fechado pelo Claude como game designer, a pedido do Tarciso. Bloco segue em review até o código seguir as decisões.
- 2026-10-22 — Código alinhado ao GDD-08 §8 (Claude): save das construções, catálogo único com a Bancada, desmontar com [X] (50% / 100% em 2 min, totem só com território vazio), regras de totem (vila 20 m, folga 6 m, 1 por dono), duelo na cidade, `WILD_PVP`, `lenharia` removida. Os novos scripts usam `preload` porque os `class_name` deles não estão no cache de classes até o editor reescanear. `test_city_and_building` com 7 etapas; runner 12/12; mundo carrega sem erro. Fora: qualidade 1★/2★ (falta estoque com qualidade).
- 2026-10-22 — Vila em obras (Claude, pedido do Tarciso; desenho no GDD-08 §6.1). NPCs da vila agora usam `TownNPC` (CharacterDNA + animação UAL; `alchemist_dna`, `builder_dna`) no lugar dos modelos prontos em T-pose. Besta de Sucata flutuava 1,3 m (CharacterBody sem gravidade em y=1,2): assenta no relevo e foi para o morro ao norte (−5, −11). **Bug corrigido:** o covil da besta ficava dentro do raio da cidade e a cidade era testada antes do perigo, então não dava para atacar a besta. Agora perigo vem antes; vila com raio 14; covil r 6; arena movida para (−27, 3) r 10. Cinco obras (`TownProject`, peças do Medieval Village MegaKit em `assets/models/village/`, texturas reduzidas a 1024 px): Poço, Paliçada, Mercado, Forja Pública e Taverna, cada uma com Fundação → Estrutura → Acabamento e visual por etapa (estacas e cordão → base de pedra e piso → paredes com andaime → telhado, porta, chaminé). Jogo novo já começa com a vila andando (forja com paredes, taverna e mercado com piso, paliçada com estacas). Quadro de Obras na praça ([E] na placa ou no Mestre Construtor) para doar materiais; Reputação da Vila (1 por unidade); obras e reputação no save. Trabalhadores com machado em cada obra em andamento. Natureza e recursos não nascem mais dentro da paliçada (`CityHub.in_village`). `tests/test_town_projects.gd` (3 etapas); runner 15/15.
- 2026-10-22 — Bloco concluído (status `review` estava fora da convenção). Pendências de jogo ficam para o Tarciso: custos das obras e distância da forja ao spawn. Dono das construções agora é o nome do personagem.
