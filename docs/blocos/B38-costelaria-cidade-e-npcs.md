---
type: block
status: active
created: 2026-10-29
updated: 2026-10-29
tags:
  - bloco
  - godot
  - cidade
  - npc
  - ui
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B38 — Costelária: cidade dentro do Colosso e Ficha do NPC

## Objetivo
Implementar o GDD-17 (vault): segunda base, maior e mais marcante que a Vila da Esperança, construída no esqueleto fossilizado de um Colosso a oeste do vale; NPCs que vendem, compram (com bolsa diária), treinam (Lições e Técnicas de marco) e ensinam o jogo; e a **Ficha do NPC** no [E] (NPC em 3D à esquerda, papel, horário e ações à direita).

## Decisões do Tarciso (2026-10-29)
Tema e nome aprovados; lugar a oeste (≈ −110, −10); compradores a 0,6 × valor-base, 300 $S/dia, −3% por unidade; Técnica do marco só com o mestre; cidade aberta desde o começo, com rotina pelo relógio; Ficha também na Vila da Esperança; elenco completo.

## O que entrou
- **Ficha do NPC** (`NpcProfile`, `NpcAction`, `NpcDialog`): retrato 3D num `SubViewport` com mundo próprio (mesmo DNA e ferramenta, gira e aproxima), nome, papel, bairro, horário aberto/fechado, saudação por período, ações com atalhos 1–9, ação cinza com motivo, painéis dentro da Ficha. Não pausa; fecha ao se afastar. Todos os NPCs da Vila (incluindo Mestre de Armas e Barbeiro) usam a Ficha.
- **Planta** (`CostelariaLayout`): elipse de 64 × 116 m girada (cauda/portão virada para a Vila). Terreno aplainado, praça do Coração lisa, ruas de pó de osso, grama fora das ruas, zona segura (CITY), proibido construir, combate só no **Pátio dos Mestres**.
- **Esqueleto** (`ColossoSkeleton`): espinha com vértebras e espinhos, 12 pares de costelas, bacia, cauda enrolada no portão, 4 patas com garras, crânio com chifres, mandíbula, dentes e órbitas de âmbar que acendem à noite. Tubos gerados em código numa malha só; colisão onde o osso toca o chão.
- **Bairros:** Cauda (portão, estábulo, Guarda), Espinha (avenida, púlpito da Pregoeira), Costelas (8 bancas), Coração (cristal de âmbar = Marco de Viagem, bancos, Mural de Notícias), Pulmão Oeste (Salão das Forjas com bigorna de verdade), Pulmão Leste (Estalagem com lareira para descansar), Pélvis (Pátio com 3 bonecos de treino sem loot), Crânio (Arquivo e mesa do Esfolador), Ventre (Feira da noite), cerca de presas, casas, lanternas.
- **Elenco (31):** 10 de comércio, 8 mestres, 4 tutores, 9 moradores (`CostelariaCast`).
- **Comércio** (`CostelariaEconomy`): estoque por item que repõe ao amanhecer; compradores com bolsa do dia e preço caindo para a cidade toda; 2 encomendas por dia com ★ mínima no Seu Graxa (+Reputação); Feira do Ventre (oferta rara sorteada pelo dia, compra qualquer coisa pela metade); desconto pela Reputação da Costelária. Sorteios com semente do dia (iguais para todos no online).
- **Mestres** (`MasterTechniques`): Lição (golpes ou partes nos bonecos em 45 s, ou "mostrar" o que fez sem gastar) com bônus de primeira vez por faixa; Técnica nos marcos 10/25/50/75/100 só com nível + Prova (Lição da faixa) + taxa. Efeitos reais: dano por tipo, dano em partes e de postura (CombatResolver), degraus da esfola, velocidade de coleta e mineração, encaixe de tempero e crítico da forja, duração da comida. Conselho aponta a bússola para onde treinar.
- **Tutores:** Arquivista e Compêndio (7 capítulos, 17 páginas que abrem fazendo ou conversando, "Mostre-me", capítulo completo = +10 de Reputação); Guardas com "Onde fica?" (bairros e moradores, com status aberto/fechado); Pregoeira e Mural com notícias tiradas do estado do mundo; Cartógrafa vende rumo para qualquer assentamento ou marco.
- **Rotina:** fora do horário cada morador anda até casa e volta ao posto no horário; Ventre abre das 20h às 4h; guardas e Pregoeira 24 h.
- **Save:** economia, Reputação e páginas da Costelária; Técnicas e Lições na maestria do personagem.

## Mudanças de regra (efeito da decisão 4)
- Os degraus de tempo da esfola (10/50/100) e o encaixe de tempero da forja (10) agora pedem a Técnica do mestre além do nível. Saves antigos com o nível alcançado precisam passar no mestre.
- Mestre Tocaia (arco) virou **Mestre Marrão (Impacto)**: o jogo não tem XP de perfuração/arco. Herbalista ensina só Coleta (botânica ainda não dá XP).

## Arquivos
`scripts/npc/`, `scripts/ui/npc_dialog.gd`, `scripts/costelaria/` (layout, skeleton, cast, economy, master_techniques, compendium, hub), ganchos em `town_npc.gd`, `city_hub.gd`, `weapon_trainer.gd`, `character_stylist.gd`, `world_settlements.gd`, `landscape_generator.gd`, `grass_and_flowers.gd`, `zone_manager.gd`, `dummy_creature.gd`, `mastery_component.gd`, `combat_resolver.gd`, `player.gd`, `gatherable_resource.gd`, `forge.gd`, `forge_screen.gd`, `food_buff_component.gd`, `save_game.gd`, `explorer_guide.gd`. Prints: `tools/costelaria_shots.gd` → `build/b38/`.

## Fora deste bloco (pendências)
- Cofre da Cidade (banco) da planta: não entrou (precisa de sistema de armazenamento).
- Dia de 5 min reais deixa a rotina corrida; alongar o dia mexe no ADR-0006 e em toda a natureza: decidir num bloco próprio.
- No online, estoque/bolsas/encomendas vão para o servidor; páginas do Compêndio para o personagem.

## Critérios de pronto
- [x] Fases 1–6 implementadas.
- [x] `tests/test_npc_dialog.gd` e `tests/test_costelaria.gd`; runner verde.
- [x] Prints em `build/b38/` (12 ângulos × dia/noite + 2 Fichas).
- [ ] Tarciso andar pela Costelária e aprovar.

## Log
- 2026-10-29 — Bloco criado (Claude); GDD-17 aprovado com as 7 respostas; fases 1–6 implementadas no branch `feature/b38-costelaria` (Issue #24).
