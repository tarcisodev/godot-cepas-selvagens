---
type: block
status: active
created: 2026-10-27
updated: 2026-10-27
tags:
  - bloco
  - godot
  - cidade
  - visual
  - iluminacao
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B35 — Passe visual da Vila da Esperança

> Renumerado de B25 para B35 em 2026-10-28 (o B25 ficou com a Culinária no repo). Branch `feature/b25-passe-visual-da-vila` e pasta `build/b25` mantêm o nome antigo até o OK do Tarciso.

## Objetivo
Pedido do Tarciso: dar um tapa de qualidade na cidade inicial, com foco em visual e ambiente (iluminação, props, chão, vida na praça). A vila já funciona ([[03-Projects/Cepa-Selvagem/blocos/B11-cidade-construcao-e-coleta|B11]], [[03-Projects/Cepa-Selvagem/blocos/B18-taverna-e-mercado|B18]]), mas parece um protótipo: formas cruas no lugar de modelos, texto flutuante demais, chão chapado e noite quase preta. Este bloco não muda regra de jogo; é só aparência e ambiente.

## Diagnóstico (2026-10-27)
Jogo rodado com `tools/village_shots.gd` (7 ângulos × dia 11h, tarde 17h36, noite 22h30; 21 prints). Lista em ordem de impacto:

### 1. Formas cruas no lugar de modelo
- **Chama da fogueira** é um cone laranja sólido (`CylinderMesh` com `top_radius = 0` em `scripts/town/campfire.gd`), sem partícula nem brilho.
- **Estações da Trilha do Iniciado** (`scripts/world/tutorial_trail.gd`, classe da estação): poste cilíndrico com esfera em cima — amarela no passo atual, cinza nos outros. Na praça parecem lâmpadas ou ovos; ocupam o centro da praça.
- **Marco de Viagem**: esfera ciano sobre bloco cinza.
- Postes do `TownBoardSign` e estacas da obra (`town_project.gd`) também são cilindros lisos.

### 2. Poluição de texto flutuante
- 8–10 `Label3D` visíveis ao mesmo tempo na praça (Mestre de Armas, Passo 1/8, Poço da Praça · Fundação, Mural de Feedback, Obras da Vila, Mestre Construtor, Marco de Viagem, placa da encruzilhada…), em tamanhos diferentes, vários ilegíveis.
- Não somem com a distância e se sobrepõem.

### 3. Chão
- Grama verde chapada, sem textura nem variação; sem terra batida onde se anda.
- Rua de pedra (`RockPath_Square_Wide`) são blocos soltos com buracos entre eles, alguns parecendo flutuar; não forma caminho contínuo.
- A praça não tem piso próprio que a separe do campo.

### 4. A vila não lê como vila
- De cima some no vale: 4 cercados pequenos num canto, muito espaço vazio dentro da paliçada.
- Paliçada são estacas soltas e espaçadas (parecem toras fincadas).
- Obras em andamento parecem só esqueletos; parede de pedra lisa sem textura atrás.
- Praça amontoada na beira do rio, o resto vazio.

### 5. Iluminação de dia
- Luz chapada: sem SSAO, pouca sombra de contato; névoa volumétrica quase nula (densidade 0,005). Nada guia o olhar para a praça.
- Barranco marrom atrás da cachoeira é um corte reto do terreno.
- Textura da cachoeira estourada e pixelada.

### 6. Noite
- Vila quase preta; só a fogueira ilumina. De cima é um ponto de luz.
- Sem tochas acesas nos portões, sem janelas, sem lanternas espalhadas; o único lampião da praça fica no chão.
- No fim de tarde o terreno escurece muito antes do céu — vila sem contraste.

### 7. Pouca vida na praça
- NPCs parados em pose fixa; alguns amontoados no mesmo ponto.
- Ninguém circula; sem fumaça, sem animais da vila, sem sinais de rotina (varal, lenha empilhada, sacos).
- Banca, carroça e mesas espalhadas sem formar feira.

### 8. Outros
- Placa de madeira da entrada sul sem nada escrito.
- (Ferramenta) Tutorial e painel de Objetivo ficam em `CanvasLayer` próprios e não somem ao esconder o `HUD`; os prints ainda saem com eles.

## Decisões de escopo (Tarciso, 2026-10-27)
Aceitas as recomendações das 6 perguntas:
1. **Entram os grupos 1, 2, 3, 6 e 7** e a placa da entrada sul (8). Planta da vila (4), cachoeira e barranco (5) ficam para um bloco próprio.
2. **Trilha do Iniciado:** a estação vira objeto do mundo (estaca de madeira com fita e lanterna); só a do passo atual acende e mostra texto, as outras ficam apagadas e sem rótulo.
3. **Rótulos:** regra única — nome do NPC/objeto só a ≤ 6 m; de 6 a 15 m, só um ícone pequeno; além disso, nada. Texto de ação (`[E] …`) só ao mirar.
4. **Noite:** até 6 luzes com sombra na vila (fogueira, 2 portões, taverna, forja, mercado); o resto é material emissivo ou luz sem sombra de alcance curto.
5. **Assets:** só o que já está no repo (props fantasy, Medieval Village MegaKit, natureza). Texturas novas, se precisar, geradas por shader/ruído — nada baixado.
6. **Vida na praça:** poses e animações de idle variadas e NPCs espalhados; rotina (andar entre pontos, sentar, trabalhar) fica para um bloco de NPCs.

## Critérios de pronto

### Formas cruas → modelos (grupo 1)
- [x] **Fogueira** (`campfire.gd`): cone sai; chama de partículas (reaproveitar a do `TorchComponent`) com brasa, luz que tremula e fumaça leve subindo. Vale para todas as fogueiras.
- [x] **Estação da Trilha** (`tutorial_trail.gd`): estaca de madeira com fita colorida e `Lantern_Wall` pendurada; acesa (luz curta + emissivo) só no passo atual. Esferas saem.
- [x] **Marco de Viagem:** pedra de pé (`Rock_Medium`) com runa emissiva ciano no lugar da esfera sobre bloco.
- [ ] **Postes e estacas** do `TownBoardSign` e das obras: madeira com ponta e topo irregular, não cilindro liso.

### Texto flutuante (grupo 2)
- [x] Um componente único de rótulo (ex.: `WorldLabel`) usado por NPCs, obras, quadro, marco e trilha, com a regra 6 m / 15 m e fade (sem estalo).
- [x] Mesmo tamanho de fonte e contorno para todos; o texto `[E] …` só aparece no alvo mirado.
- [x] Na praça, olhando de qualquer um dos 4 ângulos de print: no máximo 3 nomes legíveis ao mesmo tempo.

### Chão (grupo 3)
- [ ] **Rua contínua:** caminhos da praça aos portões com `RockPath` encostados, sem buraco e assentados no relevo (nenhuma peça flutuando nem enterrada mais de 2 cm).
- [ ] **Terra batida:** faixa de terra sob as ruas e em volta das obras (cor no shader do terreno ou malha/decal com ruído), com borda suave na grama.
- [ ] **Piso da praça:** `Floor_UnevenBrick` (ou pedra) marcando a praça como lugar.
- [ ] **Grama com variação:** ruído de cor/tom no terreno dentro e em volta da vila; tufos (`Grass_*`, `Clover`, `Pebble_*`) nas bordas das ruas e cercas, nunca no meio do caminho.

### Noite (grupo 6)
- [ ] `Torch_Metal` acesas nos 2 portões, na taverna e na forja; acendem ao pôr do sol e apagam ao amanhecer pelo relógio único (B22).
- [ ] Lanternas emissivas (sem sombra) pela praça e nas ruas, em postes — não no chão.
- [ ] Janelas e porta da taverna e da forja com brilho quente quando a obra tiver paredes.
- [ ] Ambiente de fim de tarde/noite: terreno não fica mais escuro que o céu próximo; a vila é reconhecível no print aéreo da noite (manchas de luz nos portões, praça e taverna).
- [ ] No máximo 6 luzes com sombra dentro da paliçada.

### Vida na praça (grupo 7)
- [ ] NPCs espalhados com espaço entre si (≥ 1,5 m), cada um virado para algo (banca, fogueira, outro NPC).
- [ ] Idle variado por papel (mexer na banca, braços cruzados, conversar, martelar na forja), sem dois vizinhos na mesma animação em sincronia.
- [ ] Feira montada: `Stall_Empty`/`Stall_Cart_Empty` com `FarmCrate_*`, `Barrel_Apples`, sacos e `Bench`; lenha empilhada perto da fogueira e da forja; varal ou estandarte entre postes.
- [ ] Fumaça na chaminé da forja e da taverna quando a obra tiver telhado.

### Placa e ferramenta (grupo 8)
- [ ] Placa da entrada sul com "Vila da Esperança" escrito na madeira (Label3D sem billboard, ou textura).
- [x] `tools/village_shots.gd` esconde também o painel da Trilha e o de Objetivo nos prints.

### Sempre
- [ ] Sem regressão de FPS na praça: medir antes e depois (mesmo horário, ângulo e máquina; RTX 3060); queda máxima aceita de 5%.
- [ ] Prints antes/depois com `tools/village_shots.gd` nos 7 ângulos × 3 horários, guardados para comparar.
- [ ] Testes de Trilha, cidade e obras continuam verdes; runner inteiro passando.

## Linha de base "antes" (2026-10-27)
`tools/village_perf.gd`: câmera fixa nos ângulos do `village_shots.gd`, sem vsync, `max_fps = 0`, UI escondida, 120 quadros de aquecimento + média de 300. RTX 3060, viewport 1706×720 (janela 2560×1080). Branch `feature/b25-passe-visual-da-vila` saída de `feature/in-game-updater` (`e8ac4bf`). Rodado 3 vezes; variação de ±2 FPS.

| Horário | Ângulo | FPS médio | Pior quadro (ms) | Draw calls | Primitivas |
|---|---|---|---|---|---|
| dia | aérea | 45,9 | 27,9 | 2.502 | 3,95 M |
| dia | entrada sul | 44,6 | 35,9 | 2.132 | 3,20 M |
| dia | praça norte | 46,6 | 26,9 | 2.190 | 3,06 M |
| dia | praça leste | 47,9 | 107,9 | 1.655 | 3,05 M |
| noite | aérea | 50,0 | 29,1 | 1.905 | 3,29 M |
| noite | entrada sul | 47,4 | 33,0 | 2.137 | 3,19 M |
| noite | praça norte | 49,1 | 26,5 | 2.137 | 2,96 M |
| noite | praça leste | 51,3 | 24,6 | 1.693 | 2,83 M |

- **Teto do bloco (−5%):** praça norte de dia ≥ 44,3 FPS; de noite ≥ 46,6 FPS.
- O custo é do mundo, não da vila: ~3 M primitivas e ~2 mil draw calls em qualquer ângulo. A vila tem pouca folga para luz com sombra, então os 6 pontos de luz precisam ser medidos um a um.
- O pico de ~100 ms na praça leste de dia se repetiu nas 3 rodadas (provável carga de chunk ou shader ao virar a câmera); fica anotado, mas não é deste bloco.
- Prints "antes" (7 ângulos × 3 horários, sem UI) e `fps.csv` em `build/b25/antes/` no repo (pasta ignorada pelo git).

## Fora deste bloco
- Regras da vila (obras, custos, reputação, mercado).
- Replanejar a planta da vila (praça centralizada, paliçada de verdade, obras com textura), cachoeira e barranco — bloco próprio.
- Rotina de NPCs (andar entre pontos, sentar, trabalhar) — bloco de NPCs.
- Quadro de missões na praça ([[03-Projects/Cepa-Selvagem/notas/Ideias-pendentes|Ideias pendentes §2]]).

## Próximo passo (uma frase)
Postes e estacas do `TownBoardSign` e das obras com cara de madeira (último item do grupo 1).

## Log
- 2026-10-27 — Bloco criado (Claude, pedido do Tarciso) a partir de 21 prints da vila; `tools/village_shots.gd` criado no repo (ainda sem commit). Fica `pending` enquanto o B23 está ativo.
- 2026-10-27 — Tarciso aceitou as 6 recomendações; critérios de pronto fechados (Claude). Segue `pending` enquanto o B23 está ativo.
- 2026-10-27 — B25 ativado a pedido do Tarciso; o B23 já estava `done`. Branch `feature/b25-passe-visual-da-vila`.
- 2026-10-27 — Linha de base medida (Claude): `tools/village_perf.gd` criado; praça norte 46,6 FPS de dia e 49,1 de noite; prints "antes" em `build/b25/antes/`. `village_shots.gd` agora esconde HUD, Trilha e Objetivo (o autoload `Objectives` reexibia o painel a cada quadro).
- 2026-10-27 — Fogueira feita (Claude): cone sai; chama, fagulhas e fumaça em `CPUParticles3D` com textura radial suave (sem ela as partículas viravam quadrados), brasa emissiva no meio da lenha, luz tremendo. Vale para todas as fogueiras (vila, vilas do mundo, peça construída). Ângulo `fogueira` novo no `village_shots.gd`; prints em `build/b25/antes|depois/*_fogueira.png`. FPS na praça norte 47,6 dia / 51,0 noite (sem queda; draw calls iguais). Runner 39/39. A fumaça ficou discreta — ajustar se o Tarciso quiser mais. Ainda sem commit.
- 2026-10-27 — Rótulo único feito (Claude): `scripts/ui/world_label.gd` (`WorldLabel`: NAME, PROMPT, SIGN). Nome por extenso até 6 m e só para os 3 mais perto à frente da câmera; ícone de 6 a 15 m; nada além; troca com fade. `[E]` só do alvo em foco — o mais perto dentro do alcance do [E] e à frente da câmera (o jogo não tem mira de interação; o [E] já usa o mais perto). Placas de vila como SIGN até o alcance delas. Trocados: TownNPC (com ícone por papel), obras, Quadro de Obras, Bigorna, Baú, coleta (todo o mapa), Trilha, Marco de Viagem, placas de estrada e das vilas, Mestre de Armas e Barbeiro. Rótulos longe do jogador dormem 20 quadros (a 1ª versão custou ~10% de FPS por causa dos ~170 [E] de coleta). `test_world_label.gd` (4 etapas); runner 40/40. Ferramentas agora põem o jogador invisível onde está a câmera (os rótulos medem dele). FPS praça norte 47,4 dia / 49,5 noite. Fora: bichos, montaria, chefe, loot e construção continuam com Label3D próprio. Ainda sem commit.
- 2026-10-28 — Estações da Trilha feitas (Claude): estaca facetada com ponta, fita (volta + 2 pontas) na cor do estado (amarela atual, verde feita, cinza pendente) e lanterna pequena (`tools/lantern.gltf`) num toco de galho; só a do passo atual acende (luz curta sem sombra + brilho). O `Lantern_Wall` do kit era um suporte de ~2 m com corrente e gaiola — descartado. As 14 esferas-guia viraram pontinhos de luz suaves. Ângulo `estacoes` nos prints. FPS praça norte 49,5 dia / 51,1 noite. Runner 40/40. Commit do WorldLabel: `026423f`; trilha ainda sem commit.
- 2026-10-28 — Marco de Viagem feito (Claude): menir facetado (hexágono achatado, levemente inclinado), runa ᛉ em traços ciano na face que respira devagar, brilho suave e luz curta sem sombra, 3 pedras na base. Esfera e bloco saem. Vale para os 4 marcos do mapa. Ângulo `marco` nos prints. FPS praça norte 49,6 dia / 49,2 noite. Runner 40/40. Commit da Trilha: `27028e3`; marco ainda sem commit.
- 2026-10-28 - Renumerado B25 → B35 (Grok Bot, decisão do Tarciso): B25 é Culinária no repo; B34 é a Intro OG Dog.
