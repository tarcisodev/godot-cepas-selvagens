---
type: resource
status: active
created: 2026-10-21
updated: 2026-10-21
tags:
  - gdd
  - cartas
  - minigame
  - colecionaveis
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-07 — Cartas 3D colecionáveis e mini-game de taverna

> Sistema de cartões tridimensionais colecionáveis que documentam o mundo de Cepa Selvagem, registram marcos de caça e botânica e servem de base para o futuro mini-game tático de tavernas e acampamentos.

---

## 1. Visão do sistema

As cartas colecionáveis de Cepa Selvagem unem o **catálogo de exploração** (Pilar 4) à **identidade dos monstros e materiais** (Pilares 1 e 3) e à **economia social** (Pilar 5).

Em vez de simples ícones num inventário 2D, cada carta é um **objeto 3D interativo**:
- Possui uma moldura esculpida, relevo volumétrico e um mini-diorama 3D no centro da janela da carta.
- Ao inspecionar no álbum, a carta responde à posição do cursor com inclinação física (tilt) e efeito holográfico de profundidade.
- Pode ser virada (flip) em 180° para revelar a ilustração do verso, a lore do espécime e os atributos táticos para o mini-game.

---

## 2. Como as cartas são obtidas no mundo

As cartas não caem de forma banal; cada carta é a comprovação de um marco no jogo:

| Categoria | Origem no Mundo | Exemplo de Carta |
|---|---|---|
| **Bestiário & Caça** | Abater criaturas ou quebrar partes anatômicas específicas | *Besta de Treino*, *Chifre Lascado*, *Mímico da Sucata*, *Monstro Abissal* |
| **Botânica & Ecologia** | Cultivar mutações genéticas raras ou espécimes no rancho | *Polinização Arcana*, *Colmeia Fúngica*, *Cogumelos de Sobretudo* |
| **Magia & Elementos** | Dominar catalisadores e feitiços arcanos/telúricos | *Elemento Terra*, *Elemento Fogo*, *Relâmpago Telúrico*, *Círculo de Sangue* |
| **Economia & Mercado Negro** | Descobrir contrabandistas, acumular riquezas e abrir baús selados | *Moeda Clandestina*, *Mercado da Fronteira*, *Livro de Transações Proibidas* |

---

## 3. Anatomia do objeto Carta 3D

O modelo da carta combina componentes tridimensionais modulares (utilizando o *3D Card Kit*):

1. **Card Frame / Container (`0_Card_Container.gltf`)**: A estrutura externa e relevo da carta, definindo sua espessura e solidez.
2. **Card Front (`0_Card_Front.gltf`)**: A face frontal com a janela de visualização do espécime, ranhuras de atributos e textura atlas.
3. **Card Back (`0_Card_Back.gltf`)**: A parte traseira com o brasão de Cepa Selvagem e acabamento desgastado / couro arcano.
4. **Diorama 3D Central**: O modelo tridimensional em miniatura (ex: `11_Polinization.gltf`, `25_Element_Earth.gltf`, `12_Mimic.gltf`, `1_Fireball.gltf`) posicionado no interior da janela da carta com profundidade real.
5. **Comportamento Interativo**:
   - **Hover / Tilt**: Rotação suave nos eixos X e Y proporcional à posição do mouse, criando efeito de cartão holográfico/lenticular.
   - **Giro (Flip)**: Transição animada de 180° no eixo Y para alternar entre arte frontal e estatísticas/lore no verso.

---

## 4. Atributos para o futuro Mini-Game de Taverna

As cartas possuem atributos padronizados para alimentar um futuro jogo de cartas em mesas de taverna, acampamentos e apostas entre jogadores:

| Atributo | Faixa | Descrição |
|---|---|---|
| **Éter (Custo)** | 1 a 5 | Quantidade de recurso mágico necessária para baixar a carta na mesa por turno. |
| **Poder (Ataque)** | 1 a 10 | Dano direto causado às cartas da fileira oposta ou ao total de vida do jogador adversário. |
| **Postura (Defesa)** | 1 a 12 | Resistência a dano. Ao zerar a postura, a carta é atordoada ou enviada ao descarte. |
| **Elemento** | 6 tipos | Fogo, Terra, Água, Ar, Eletricidade, Trevas. Segue o sistema de fraquezas do GDD-01 (ex: Água apaga Fogo; Terra absorve Eletricidade). |
| **Trait Especial** | 1 por carta | Efeito temático desencadeado na jogada (ex: *Polinização*: concede +2 de postura a cartas vizinhas; *Chifre Quebrador*: ignora 50% da postura defensiva do alvo). |

### Raridades
- **Comum (Bronze)**: Espécimes básicos de fauna e flora selvagem.
- **Incomum (Prata)**: Variantes veteranas com cicatrizes ou reagentes refinados.
- **Raro (Ouro)**: Monstros alfa, mutações genéticas puras e magias avançadas.
- **Lendário (Cromado/Éter)**: Criaturas colossais de eventos mundiais e segredos lendários do Mercado Negro.

---

## 5. Interface da Coleção (Álbum)

- **Acesso rápido**: Tecla de atalho `K` (ou botão de interface no menu de ações).
- **Painel do Álbum**:
  - Grade de miniaturas com status desbloqueado ou silhueta misteriosa para cartas ainda não descobertas.
  - Contador de progresso da coleção (ex: `12 / 30 Descobertas`).
  - Filtro por elemento e tipo (Monstros, Botânica, Magia, Itens).
- **Palco de Inspeção 3D**:
  - Ao clicar em uma carta, ela é destacada no centro da tela em visão 3D completa com iluminação dedicada.
  - O jogador pode arrastar com o botão esquerdo para inspecionar em qualquer ângulo, ou clicar para virar (flip) e inspecionar os detalhes do verso.

---

## 6. Integração técnica no Godot

- **Classe de Dados**: `CardData` (Resource ou Dictionary tipado contendo `id`, `title`, `rarity`, `element`, `power`, `poise`, `ether_cost`, `model_path`, `description`).
- **Componente de Coleção**: `CardCollectionComponent` anexado ao `Player`, registrando IDs desbloqueados e disparando sinal `card_unlocked(card_data)`.
- **Cena da Carta 3D**: `scenes/card_3d.tscn` com meshes GLTF instanciadas, scripts de rotação suave e sinalizadores de interação.
- **Cena do Álbum**: `scenes/card_album.tscn` controlando a navegação na coleção e o palco de inspeção 3D.

---

## 7. Duelo de Cepas — a mesa da Taverna (decidido em 2026-10-23, Claude como game designer, pedido do Tarciso)

Partida curta (5 a 8 minutos) que usa os atributos do §4. Abre quando a obra **Taverna** fica pronta (GDD-08 §6.1); antes disso a Taverneira diz que a mesa ainda está em obras.

- **Baralho:** 3 cópias de cada carta da sua coleção, completado até 12 com **Recrutas de Taverna** (Neutro, Éter 1, Poder 2, Postura 3, sem trait; não são colecionáveis). Quanto mais cartas você descobre, mais forte e variado fica o baralho.
- **Mesa:** 3 fileiras por lado. Cada jogador tem **15 de Vida**.
- **Turno:** o Éter máximo sobe 1 por turno (até 5) e enche de novo; compra 1 carta (mão inicial 4; baralho vazio = perde 1 de Vida na compra). Baixe cartas pagando o Éter numa fileira vazia sua.
- **Ataque no fim do seu turno:** cada carta sua bate na carta da fileira em frente (tira Postura igual ao Poder; Postura 0 = descartada). Fileira da frente vazia = o Poder vai direto na Vida do rival. A carta ataca já no turno em que entra.
- **Elementos (GDD-01):** Água > Fogo > Ar > Terra > Raio > Água; vantagem dá **+2 de dano**. Trevas e Neutro não têm vantagem nem fraqueza.
- **Traits das cartas atuais:** Ressonância Telúrica (+2 Postura nas vizinhas ao entrar) · Germinação Rápida (+3 Postura na aliada mais ferida ao entrar) · Contrabando Fúngico (+1 Éter no próximo turno quando cai) · Emboscada Dentada (dano dobrado no primeiro ataque) · Enxame Protetor (quem ataca a colmeia perde 1 de Postura) · Suborno de Taverna (compra 1 ao entrar) · Queimadura Solar (a carta atingida queima 2 por 2 rodadas) · Chifre Quebrador (+50% de dano contra cartas).
- **Fim:** Vida 0, ou depois de 15 rodadas vence quem tem mais Vida (empate devolve a aposta).
- **Aposta (ralo pequeno):** 0, 5, 10 ou 20 $S. Quem vence leva o pote **menos 10% da casa**; contra a Taverneira, você ganha 2× a aposta − 10%. A casa é ralo de moeda (GDD-05 §1).
- **Prêmio de coleção:** cada vitória contra a Taverneira dá a próxima carta da lista que você ainda não tem (Colmeia Fúngica → Esfera de Fogo → Polinização Arcana), com ou sem aposta. Baralho dela: Colmeia, Esfera de Fogo e Elemento Terra.
- **Equilíbrio medido:** em 300 partidas bot contra bot, o baralho inicial (Terra, Moeda, Cogumelos) vence 27% e a partida dura ~9 rodadas; jogando de verdade (escolhendo a fileira) a chance sobe, e cada carta ganha deixa o baralho mais forte.
- **Implementado em 2026-10-23 (B18):** `CardDuel` (regra pura), `TavernTable` na porta da Taverna com a Taverneira, `CardTableScreen`; teste `tests/test_card_duel.gd`.
- **Rede (ADR-0002):** a regra é uma classe pura (`CardDuel`) que o servidor roda; o cliente só manda "baixar carta X na fileira Y" e "encerrar turno". Mesa entre jogadores fica para quando houver servidor; no slice o rival é a Taverneira.
