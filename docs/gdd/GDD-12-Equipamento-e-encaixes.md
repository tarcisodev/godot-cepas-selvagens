---
type: resource
status: active
created: 2026-10-25
updated: 2026-10-25
tags:
  - gdd
  - equipamento
  - forja
  - combate
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-12 — Equipamento: encaixes e famílias (pano, couro, ferro)

> Pedido do Tarciso (2026-10-25): estruturar o equipamento como no Albion, com arma primária, arma secundária, capacete, armadura, botas, capa e mochila, e famílias de ferro, couro e pano. As 4 decisões de base foram fechadas pelo Tarciso em 2026-10-25 ([[08-Knowledge/decisions/ADR-0007-cepa-encaixes-e-familias|ADR-0007]]). As 6 perguntas foram fechadas no mesmo dia (§6). Boss, minério e peso dos golpes (§8–§11) são propostas do Claude como game designer, a pedido do Tarciso, que revisa jogando. Execução: [[03-Projects/Cepa-Selvagem/blocos/B23-equipamento-boss-e-minerio|B23]].
> Liga: [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01]] (barra de habilidades, Carga, esquiva), [[03-Projects/Cepa-Selvagem/notas/GDD-02-Progressao-por-uso|GDD-02]] (maestrias de armadura), [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06]] (receitas e slots da forja), [[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05]] (full loot).

---

## 1. Encaixes (8)

| Encaixe | O que dá | Carga |
|---|---|---|
| **Arma primária** | os 2 básicos (clique esq./dir.) e 3 habilidades | sim |
| **Arma secundária** | 1 passiva: escudo (bloqueio), tocha (luz), tomo (Éter), adaga (sangramento). Com arma de duas mãos este encaixe fica travado | sim |
| **Cabeça** | 1 habilidade utilitária | sim |
| **Peito** | 1 habilidade defensiva. As braçadeiras/manoplas aparecem no corpo como parte do peito | sim |
| **Botas** | 1 habilidade de mobilidade | sim |
| **Capa** | 1 passiva que vem do material (pele: frio e chuva; penas: queda lenta) | quase nada |
| **Mochila** | capacidade de carga do estoque. Não mexe no combate | fora da Carga de combate |
| *(Consumíveis)* | 2 atalhos, como no GDD-01 | — |

- O encaixe **mãos** deixa de existir. As Braçadeiras de Galhada passam a ser o visual de uma receita de peito (§5).
- A barra continua a do GDD-01: 2 básicos + 3 da arma + cabeça + peito + botas + 2 consumíveis. O que muda é que a arma secundária e a capa agora dão passivas.

## 2. Famílias = peso

A família de uma peça **vem do material do revestimento** (slot 2 da forja, GDD-06 §3). Assim, a mesma receita de elmo pode sair de pano, de couro ou de ferro.

| Família | Revestimento | Maestria (GDD-02) | Tipo de habilidade | Esquiva (GDD-01) |
|---|---|---|---|---|
| **Pano** | fibra, pena, seda, tecido | `armadura_leve` | Éter, cura, controle | rolamento longo |
| **Couro** | couro, pele, tendão | `armadura_media` | mobilidade, dano, furtividade | passo lateral |
| **Ferro** | metal, placa, carapaça | `armadura_pesada` | Postura, provocar, super armor | passo curto |

- **Sem bônus de set.** A família vale peça por peça. Misturar é a build: elmo de ferro, peito de pano e botas de couro. A Carga somada decide a esquiva, como já acontece hoje.
- Não entram tags novas de maestria: cada peça dá XP (`damage_mitigated`) para a maestria da família dela.
- **Habilidade por encaixe:** cada combinação família × encaixe tem uma lista curta (2–3 opções) que a maestria da família vai liberando. A parte de criatura usada no núcleo pode trocar ou dar uma habilidade nova (chifre do Rinolito → investida, GDD-01).

## 3. Armas forjadas

Armas saem da bigorna como as armaduras, usando os mesmos 3 slots do GDD-06:
- **Núcleo** define o tipo de dano (corte, impacto, perfuração; cristal ou seiva para os elementos).
- **Revestimento** define o peso e se a arma é de uma ou de duas mãos.
- **Tempero** dá o trait.

- A **primária** define os 2 básicos e as 3 habilidades (a maestria da arma libera as opções, GDD-01). A **secundária** dá só a passiva.
- Arma de duas mãos trava a secundária e compensa com mais dano/Postura por golpe.
- Os 3 estilos de hoje (B10) viram as primeiras receitas: **espada** (primária) + **escudo** (secundária), **mangual** (duas mãos), **cajado** (duas mãos).
- A tocha ocupa a mão secundária: acesa, o escudo não vale (fica a espada sozinha); com arma de duas mãos não sobra mão para ela.

## 4. Mochila e capa

- **Mochila:** couro ou pano (o ferro não tem mochila). Aumenta o peso que o estoque carrega sem lentidão. No PvP aberto é a mochila, com o que está dentro, que cai no full loot (GDD-05).
- **Capa:** quase sem Carga e sem mitigação. A passiva vem do trait do núcleo, e é aqui que o ciclo natural (GDD-10) entra no equipamento: frio da noite, chuva, queda.

## 5. O que muda nas 4 receitas do GDD-06 §6

| Receita | Antes | Agora |
|---|---|---|
| Elmo Chifre-de-Pedra | cabeça · pesada | cabeça · **ferro** (carapaça ou barra de ferro); couro se o revestimento for couro |
| Gibão do Andarilho | peito · leve | peito · **couro** (tendão), ou **pano** (fibra) |
| Capuz de Penacho | cabeça · leve | cabeça · **pano** (revestimento 4 Fibras); couro com Pele de Saltarelo |
| Braçadeiras de Galhada | mãos · média | vira **Couraça de Galhada** (peito · couro; ferro com barra) |

- A receita dá os números-base para a família de origem. Outra família muda Carga e mitigação pelo fator do §2.1. Por isso a mesma receita de origem rende o mesmo item de antes.

### 2.1 Fator da família

| Família | Carga | Mitigação (resistências) | Extra |
|---|---|---|---|
| Pano | ×0,5 | ×0,6 | +0,5 regen. de Éter |
| Couro | ×1,0 | ×1,0 | esquiva −1 Vigor |
| Ferro | ×1,6 | ×1,4 | +5% Postura |

## 6. Respostas do Tarciso (2026-10-25)

Todas as 6 recomendações do Claude foram aceitas.

1. **Capuz de Penacho vira pano:** revestimento 4 Fibras. A Pele de Saltarelo vai para as botas.
2. **Braçadeiras viram a Couraça de Galhada** (peito · couro): núcleo Chifre-Galhado, papel de impacto e Postura, manoplas e ombreiras como visual. A família escolhe as habilidades e a receita escolhe os números. Saves antigos: as braçadeiras viram Couraça com as mesmas ★.
3. **Uma habilidade por família × encaixe (9 no slice).** Teclas: **4** cabeça · **5** peito · **R** botas.

| | Pano | Couro | Ferro |
|---|---|---|---|
| **Cabeça [4]** | *Foco*: Éter regenera em dobro por 5 s · recarga 20 s | *Faro*: +20% de dano por 8 s · 10 Vigor · 24 s | *Brado*: atrai monstros a 10 m e +30% Postura por 6 s · 15 Vigor · 25 s |
| **Peito [5]** | *Véu*: escudo de Éter que absorve 40 de dano por 6 s · 30 Éter · 22 s | *Esquivo*: por 6 s a próxima esquiva sai sem custo e com i-frames de 0,45 s · 15 s | *Firmeza*: 3 s de super armor e −30% de dano · 20 Vigor · 25 s |
| **Botas [R]** | *Rajada*: avanço de 6 m que atravessa inimigos · 20 Éter · 10 s | *Disparada*: +40% de velocidade por 4 s · 15 Vigor · 14 s | *Pisão*: golpe em área de 3,5 m (18 impacto, 40 Postura) · 20 Vigor · 12 s |

   - A parte de criatura no núcleo troca a habilidade: o elmo com **chifre de Rinolito** troca o Brado pela **Investida** (avanço de 7 m, 30 de impacto, 35 de Postura).
4. **Mochila em kg** (o peso dos materiais que o estoque já soma): sem mochila 20 kg, pano 40 kg, couro 60 kg, multiplicado pela qualidade (Q1 100% … Q5 160%). Acima de 100% do limite fica mais lento conforme o excesso. Acima de 150% não corre nem esquiva. A mochila não entra na Carga de combate.
5. **Secundárias do slice: escudo e tocha.** Tomo e adaga entram com uma primária mágica de uma mão.
6. **Botas:** núcleo de Pele de Saltarelo; o revestimento decide a família (fibra = pano, couro = couro, carapaça ou barra de ferro = ferro). **Capa de Penas:** Pena de Penacho, queda lenta. **Capa de Couro:** Couro de Trotador, +2 regen. de Vigor à noite ou na chuva.

## 7. Receitas do slice (armas, peças novas e o ferro)

| Receita | Encaixe | Núcleo | Revestimento | Efeito |
|---|---|---|---|---|
| Espada de Ferro | primária | 2 Barras de Ferro | 1 Couro **ou** 2 Fibras (empunhadura) | estilo espada; com escudo, espada e escudo |
| Mangual | primária · 2 mãos | 3 Barras de Ferro **ou** 6 Pedras (−15% de dano) | 2 Madeiras | estilo arma pesada |
| Cajado Arcano | primária · 2 mãos | 2 Quartzos-Lume **ou** 2 Pinhões-Lume (−10%) | 2 Madeiras | estilo cajado |
| Escudo | secundária | 3 Madeiras **ou** 2 Barras de Ferro | 1 Couro **ou** 1 Placa | libera o bloqueio da espada |
| Cota de Ferro | peito | 3 Barras de Ferro | 2 Placas (ferro) **ou** 2 Couros (couro) | mitigação pesada |
| Botas de Saltarelo | botas | 2 Peles de Saltarelo | 3 Fibras · 1 Couro · 1 Placa | esquiva mais barata |
| Capa de Penas / de Couro | capa | 4 Penas / 2 Couros | 2 Fibras **ou** 1 Tendão | passiva do §6.6 |
| Mochila | mochila | 2 Couros **ou** 6 Fibras | 1 Tendão (couro) **ou** 3 Fibras (pano) | limite do §6.4 |

- O dano da arma é o do estilo × qualidade × fator do núcleo. Os estilos do Mestre de Armas viram **armas de treino** (Q1), que ele dá de graça a quem não tem.
- Sem arma primária, o personagem luta de **punhos** (impacto fraco).

## 8. Veios de minério

Pedido do Tarciso: "criar veios de minério pelo mapa".
- **Veio de Ferro** (pedra escura com manchas de ferrugem): nasce em grupos de 3–5 nas encostas altas, longe do rio e da vila. Cada nó aguenta **4 batidas** (1–2 Minérios de Ferro cada), encolhe a cada batida e volta em 4 min. Maestria `mineracao`.
- **Veio de Quartzo-Lume** (cristal que brilha fraco à noite, como a Pinheira): mais raro, nas encostas mais altas. 3 batidas, 1 Quartzo cada. Núcleo do cajado.
- **Fundir** na bigorna: 2 Minérios de Ferro + 1 Madeira = 1 Barra de Ferro, com a qualidade do minério.

## 9. Boss: Rinolito Ancião

Pedido do Tarciso: "algum brabo pra testar de fato a mecânica do jogo".
- Rinolito velho e enorme (corpo procedural do GDD-09, ~5 m), na **Clareira do Ancião**, a sudoeste da vila. Fica nela: se você sai da clareira, ele volta e se cura inteiro (sem puxar para longe).
- **Vida 900 · Postura 220.** A carapaça resiste a corte (25%); o impacto entra cheio.
- **Sem aviso na tela.** O aviso é o próprio corpo, e cada golpe tem uma pose diferente:

| Golpe | Pose antes (o aviso) | Efeito |
|---|---|---|
| Chifrada | abaixa a cabeça (0,55 s) | arco de 3,5 m na frente · 28 impacto, 30 Postura, empurra |
| Pisão | empina nas patas de trás (0,8 s) | área de 4,5 m · 22 impacto, 45 Postura, empurra longe |
| Investida | raspa a pata no chão (0,9 s) | corre 14 m em linha reta · 40 impacto, 60 Postura. Errou → fica tonto 1,6 s (a sua janela) |

- **Fúria abaixo de 50% de Vida:** prepara os golpes 25% mais rápido e emenda 2 investidas.
- **Partes:** o **chifre** (quebra com impacto) cai na hora como Chifre de Rinolito 4★ *Cicatrizado* e enfraquece a investida em 40%. A **carapaça** quebrada cai como 3 Placas e tira a resistência a corte.
- **Postura zerada:** fica atordoado 3 s e leva +30% de dano.
- **Corpo:** esfola em 4 partes (Chifre 3★ se não foi quebrado, 6 Placas 3★, 4 Ossos, Carne). Volta em 10 min.
- Barra do boss no topo da tela enquanto você luta com ele.

## 10. Golpes com peso

Pedido do Tarciso: "dar mais peso aos ataques". **Nada desacelera o mundo** (ADR-0006): o peso fica todo no corpo de quem bate e de quem apanha.
- **Hitstop local:** a animação de quem bate e a de quem apanha congelam por 50–130 ms, conforme a Postura do golpe. O relógio do golpe também para, então o tempo só muda para essas duas entidades.
- **Tranco na câmera** de quem bate (leve) e de quem apanha (mais forte).
- **Empurrão** no alvo pela Postura do golpe; golpes de boss jogam o jogador longe.
- **Faíscas** no ponto do impacto (cor pelo tipo de dano) e som de impacto com o tom pelo peso.

## 11. Fim do aviso dos monstros

Pedido do Tarciso: "tirar aviso antes dos ataques dos monstros". O monstro deixa de piscar vermelho e o "!" some. Quem lê o golpe é o jogador, pela animação de preparação.

## 12. Lobo-do-Ermo e Tatu-Espinho

Pedido do Tarciso (2026-10-25): mais dois bichos procedurais para matar e fazer equipamento. Decisões do Claude como game designer; o Tarciso revisa jogando. Os dois usam o mesmo corpo procedural e o mesmo código de luta do boss (`BeastFighter`): golpes com pose, sem aviso na tela.

### 12.1 Lobo-do-Ermo (bando à noite)
- **Onde:** 3 tocas nas bordas do vale, longe da vila, com 3 lobos cada.
- **Quando:** de dia dormem na toca e só reagem se apanharem. **À noite** (18h30–6h) caçam: veem você a 16 m.
- **Bando:** cada lobo cerca por um lado diferente (um vem pela frente, os outros pelos flancos). Lutar com as costas viradas para eles custa caro.
- **Vida 110 · Postura 35.** Leve: o empurrão do golpe joga o lobo longe.
- **Golpes:** *Mordida* (abaixa a cabeça, 0,4 s; 10 de corte) e *Bote* (raspa a pata, 0,6 s; salta 7 m; 16 de corte, 20 de Postura). Bote que erra deixa o lobo tonto 0,8 s.
- **Esfola:** 2 Couros de Lobo, 1 Presa de Lobo, 1 Carne. Volta em 3 min.

### 12.2 Tatu-Espinho (território dos veios)
- **Onde:** nas encostas dos veios de ferro (um perto de cada grupo de veios, até 8). Quem quer minério tem que passar por ele.
- **Quando:** sempre; é **territorial**. Ataca quem chega a 7 m do seu canto e para de seguir a 14 m.
- **Vida 170 · Postura 70.** Carapaça: resiste 35% a corte e 20% a perfuração, leva 15% a mais de impacto. A **carapaça quebra com impacto** e cai como 1 Placa; quebrada, o corte entra.
- **Golpes:** *Garrada* (cabeça baixa, 0,5 s; 14 de perfuração) e *Rolamento* (abaixa e se fecha, 0,8 s; rola 10 m; 24 de impacto, 35 de Postura). Rolamento que erra deixa o tatu tonto 1,2 s.
- **Esfola:** 2 Placas de Carapaça, 1 Garra de Tatu, 1 Carne. Volta em 3 min.

### 12.3 Materiais novos e para que servem
| Material | De onde | Uso na forja |
|---|---|---|
| Couro de Lobo | lobo | vale como Couro de Trotador no gibão, na capa de couro e na mochila; no gibão o núcleo de lobo dá +10% de durabilidade |
| Presa de Lobo | lobo | tempero de arma (Espada, Mangual): *Serrilhado*, +6% de dano |
| Garra de Tatu | tatu | tempero de botas e escudo: *Cravado*, +6% de Postura |

- O mapa começa a ter um ciclo: o ferro está onde o tatu mora; o couro melhor vem do lobo, que só caça à noite (tocha, fogueira e capa de couro ajudam).

## 13. Tela de equipamento no [I]

Pedido do Tarciso: apertar [I] e ver o que está equipado, com o personagem em 3D para girar e dar zoom, e equipar ou desequipar ali. A coluna fica à esquerda do inventário: boneco no centro, encaixes de armadura à esquerda (cabeça, peito, botas, capa), armas e mochila à direita. Clicar num encaixe lista as peças que cabem nele; o tooltip mostra família, durabilidade, traits e a habilidade da tecla. Embaixo: Carga, peso da mochila contra o limite, estilo de luta e as três habilidades. O mundo continua rodando com a tela aberta.
