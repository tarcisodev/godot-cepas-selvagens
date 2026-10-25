---
type: resource
status: active
created: 2026-10-24
updated: 2026-10-25
tags:
  - gdd
  - mapa
  - ui
  - exploracao
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-11 — Mapa [M]

> Pedido do Tarciso (backlog, 2026-10-23): ao apertar **M** abre o mapa; no início **o mapa inteiro já está visível** (sem névoa); com o tempo, **o que os jogadores constroem aparece no mapa**. Propostas do Claude como game designer, **fechadas pelo Tarciso em 2026-10-25** (§9).
> Liga: [[03-Projects/Cepa-Selvagem/notas/GDD-08-Territorio-construcao-e-coleta|GDD-08]] (zonas, totem, Obras da Vila), [[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica|GDD-04]] (exploração e catálogo), [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10]] (rio, cheia), [[08-Knowledge/decisions/ADR-0002-cepa-servidor-autoritativo|ADR-0002]].

---

## 1. Para que serve

- **Orientar**, não guiar. O mapa diz *onde as coisas estão* (vila, rio, covil, territórios), não *onde está a caça*. Achar bicho, planta e mutação continua sendo exploração (Pilar 4).
- **Mostrar o mundo dos jogadores.** É a vitrine de que o mundo é compartilhado: totens, construções e obras da vila crescem no mapa conforme as pessoas jogam.
- Uma tela só, sem minimapa no slice (ver P7).

## 2. Abrir e fechar

- **[M]** abre e fecha; **[Esc]** fecha.
- **O mundo não para** (nada de moleza de single-player): o tempo segue, bichos andam e podem atacar. Com o mapa aberto o personagem **fica parado** (como no inventário [I]).
- **Tomar dano fecha o mapa.** Abrir o mapa em combate é permitido, e quem faz isso sabe o risco que corre.

## 3. Como o mapa é desenhado

- **Vista de cima do terreno real, pintada como pergaminho.** A imagem sai da mesma função de altura do terreno (`get_height_at`), então nunca fica errada quando o mundo mudar.
  - Relevo com sombreado leve e **curvas de nível a cada 4 m**; o rio e a água profunda em azul de tinta; a cachoeira com um traço próprio.
  - Paleta de papel envelhecido (sépia, tinta marrom), borda desenhada e uma rosa dos ventos.
- Gerada **uma vez ao carregar o mundo**, em ~512 × 512 px (≈ 0,7 m por pixel no vale de 360 m). Custa um carregamento, não um frame.
- **Zoom** de 1× (vale inteiro) a 4×, com a roda do mouse; **arrastar** move o mapa; **[Espaço]** centraliza no jogador.
- O mapa **não muda de dia para noite** nem com a chuva. A cheia do rio também não aparece (é um retrato do vale, não uma câmera).

## 4. Camadas

| Camada | O que mostra | De onde vem | Muda quando |
|---|---|---|---|
| **Terreno** | relevo, curvas, rio, água profunda | altura do terreno | nunca (só se o mundo for regerado) |
| **Zonas** | Cidade (verde), Covil (vermelho tracejado), Arena (laranja), futura Zona Selvagem (borda vermelha grossa) | `ZoneManager` | nunca no slice |
| **Lugares** | nomes à mão: Vila da Esperança, Arena de Teste, Covil da Besta de Sucata, Taverna, Mercado, Forja Pública | lista fixa de pontos | nunca |
| **Construções dos jogadores** | círculo de cada **totem** (raio 14 m) com o nome do dono; planta baixa das **peças** (piso, parede, cerca, canteiro…) como traços pequenos | `BuildingSystem` | ao colocar ou desmontar uma peça |
| **Obras da Vila** | ícone de cada projeto com a etapa (estaca → piso → andaime → prédio) | `TownProject` | ao completar uma etapa |
| **Você** | seta na sua posição, virada para onde você olha | jogador | todo frame com o mapa aberto |
| **Suas montarias** | ícone de cada montaria **sua** onde ela está (resolve o "cadê a Raia?" do backlog §5) | capturas do jogador | com o mapa aberto, a cada 1 s |
| **Seus marcadores** | até **20** marcadores pessoais (§5) | save do personagem | quando você mexe |

**Fora do mapa, de propósito:** outros jogadores, bichos selvagens, recursos de coleta, Pinheiras e peixes. Ver P2 e P3.

## 5. Marcadores pessoais

- **Clique direito** no mapa põe um marcador; escolhe-se o ícone (bandeira, caveira, folha, peixe, olho, estrela) e, se quiser, um nome curto.
- **Clique direito em cima** de um marcador apaga.
- Até **20 por personagem**; são **seus**, ninguém mais vê (compartilhar fica para quando houver grupo/guilda).
- **Um marcador ativo** (clique esquerdo nele): aparece no HUD como uma setinha na borda da tela com a distância em metros. Só um de cada vez.

## 6. Construções dos jogadores no mapa

- Tudo o que se constrói **já é visível no mundo** para quem passa perto; o mapa só mostra o mesmo de longe. Por isso **é informação pública**: todo mundo vê o totem e as peças de todo mundo.
- O mapa mostra **a forma, não o conteúdo**: piso, parede e cerca como traços; canteiro, bancada e tanque com um ícone pequeno. Não mostra baú, estoque nem o que tem plantado.
- Nome do dono aparece só ao passar o mouse sobre o território (evita poluir o vale com texto).
- **Totem abandonado** (GDD-08 §8, decisão 7) aparece em cinza como "ruína", o que avisa quem quer desmontar por material.
- Quando houver guilda (backlog §1), a sede da guilda entra aqui com o brasão.

## 7. Rede e save (ADR-0002)

- **Terreno, zonas e lugares** o cliente desenha sozinho: vêm da seed do mundo, iguais para todos, e não têm valor de jogo.
- **Construções e obras** chegam do servidor como uma lista leve (tipo de peça, posição, rotação, dono). O cliente só redesenha a camada quando a lista muda, sem consultar o servidor a cada frame.
- O servidor **nunca manda** posição de outro jogador nem de bicho para o mapa. Assim o mapa não vira um radar nem com o cliente adulterado.
- **Marcadores** ficam no personagem: no slice vão no `SaveGame`; no online, no servidor.
- Posição das **suas montarias** o servidor manda só para o dono.

## 8. Propostas (Claude como game designer)

| # | Proposta | Por quê |
|---|---|---|
| P1 | **Estilo pergaminho sobre o relevo real** (§3) | Bonito e legível sem desenhar à mão; se o terreno mudar, o mapa acompanha. |
| P2 | **Outros jogadores não aparecem** (nem amigos, por enquanto) | Num MMO com Zona Selvagem e PvP com full loot, um radar de jogadores acaba com a emboscada e a fuga. Grupo/guilda pode ganhar isso depois. |
| P3 | **Bichos, recursos e plantas não aparecem** | O mapa orienta; a natureza se descobre andando. O catálogo do GDD-04 é que premia a exploração. |
| P4 | **Construções são públicas** no mapa (§6) | Já são visíveis no mundo; mostrar de longe faz o mapa "crescer" com os jogadores, como pediu o Tarciso. |
| P5 | **Personagem parado com o mapa aberto; o mundo segue; dano fecha** (§2) | Sem moleza de single-player e sem andar com o mapa na cara. |
| P6 | **20 marcadores pessoais + 1 ativo no HUD** (§5) | Dá ao jogador um jeito de anotar o próprio mundo ("bosque de Pinheira azul aqui") sem o jogo entregar de graça. |
| P7 | **Sem minimapa no slice** | A tela fica limpa e o jogador olha o mundo. Volta à mesa se faltar orientação jogando. |
| P8 | **Suas montarias aparecem** | Resolve o problema real do backlog §5 (achar a Raia) sem mostrar bicho selvagem. |

## 9. Decisões (2026-10-25, Tarciso)

| # | Pergunta | Decisão |
|---|---|---|
| 1 | Estilo | **Pergaminho sobre o relevo real** (P1). |
| 2 | Outros jogadores | **Ninguém aparece**, nem grupo (P2). Volta à mesa quando houver grupo/guilda. |
| 3 | Mapa aberto | **Personagem parado**, mundo segue, dano fecha (P5). |
| 4 | Minimapa | **Sem minimapa** no slice (P7). |
| 5 | Natureza no mapa | **Nada vivo** (P3): sem bichos, plantas, peixes ou recursos; marcadores pessoais servem para anotar. |

## 10. Bloco de execução

Vira o [[03-Projects/Cepa-Selvagem/blocos/B21-mapa|B21 — Mapa [M]]]:
- `MapImageBaker`: gera a textura de pergaminho a partir da altura e do rio (relevo, curvas de 4 m, água).
- `WorldMapScreen` ([M]): zoom, arrastar, centralizar; camadas de zonas, lugares, construções, obras, jogador, montarias, marcadores.
- Eventos: `BuildingSystem` e `TownProject` avisam quando mudam; o mapa escuta e redesenha só a camada deles (princípio 2 do GDD-00).
- Marcadores no `SaveGame`; setinha do marcador ativo no HUD.
- Teste headless (bake com tamanho certo, construção nova aparece na camada, limite de 20 marcadores, dano fecha o mapa) e print do mapa.

## Log
- 2026-10-24 — Nota criada pelo Claude a partir do item 3 do [[03-Projects/Cepa-Selvagem/notas/Ideias-pendentes|backlog]], a pedido do Tarciso. Propostas P1–P8; perguntas do §9 aguardando o Tarciso.
- 2026-10-25 — Tarciso fechou o §9 com as 5 recomendações; nota `active`, vira o B21.
