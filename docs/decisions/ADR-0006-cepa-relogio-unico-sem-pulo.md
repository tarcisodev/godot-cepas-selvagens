---
type: adr
status: accepted
created: 2026-10-24
updated: 2026-10-24
tags:
  - adr
  - decisao
  - cepa-selvagem
  - tempo
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
deciders: tarciso
supersedes: ""
superseded_by: ""
---

# ADR-0006 — Um relógio do mundo, que nenhum jogador pula

## Contexto
O botão **Esperar** do menu de ações adianta 4 horas, mas só no sol: plantas, solo, bichos, pinhas e clima não ficam sabendo (e depois da meia-noite o sol anda para trás). Ao mesmo tempo, cada sistema conta o dia do seu jeito: a `Ecology` lê a duração do dia do sol, enquanto a `WildCreature` usa `DAY_SECONDS = 300` fixo. O jogo é pensado como MMO com servidor autoritativo ([[08-Knowledge/decisions/ADR-0002-cepa-servidor-autoritativo|ADR-0002]]): num mundo de todos, um jogador não pode adiantar a noite dos outros.

## Opções consideradas
1. **Pular o tempo do mundo inteiro** (simular as horas puladas em todos os sistemas): caro, e no online um jogador mudaria o mundo dos outros.
2. **Pular só no solo/host local:** é a facilidade de single-player que o Tarciso não quer; o solo e o online virariam jogos diferentes.
3. **Pular quando todos estão dormindo** (estilo Minecraft): num servidor cheio quase nunca acontece, e cria atrito entre jogadores.
4. **Relógio único que nunca pula; descansar mexe só no personagem.**

## Decisão
**Opção 4** (aceita pelo Tarciso em 2026-10-24, junto com os números do GDD-10 §10).
- Um relógio no servidor (hora, dia corrido, lua). Nenhuma ação de jogador adianta, pausa ou desacelera esse relógio, nem no host local.
- Todo sistema de natureza lê a duração do dia desse relógio; nenhuma constante própria.
- O **Esperar** sai. **Descansar** (sentar, fogueira, banco, cama) só mexe no personagem: Vida volta, buff Descansado, cama vira o lugar de renascer. Detalhes no [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10 §10]].

## Consequências
- Positivas: solo e online seguem a mesma regra; a noite vira conteúdo (tocha, Pinheira-Lume, lua) em vez de algo a pular; mudar a duração do dia ajusta tudo de uma vez; construir fogueira e cama ganha propósito.
- Negativas / riscos: quem não gosta da noite não tem atalho; a duração do dia no online ainda está em aberto e pode deixar plantas e bichos lentos demais (GDD-10 §10.6).
- O que muda: `actions_menu.gd` (tira o Esperar), `WildCreature` e os timers de fruta e esterco (leem o relógio), `PoolsComponent` (Vida no descanso), peças novas no `BuildablePiece`, `spawn_point` vindo da cama.

## Referências
- [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural|GDD-10 §10]]
- [[03-Projects/Cepa-Selvagem/blocos/B22-relogio-unico-e-descansar|B22]] (execução)
- [[03-Projects/Cepa-Selvagem/notas/GDD-08-Territorio-construcao-e-coleta|GDD-08]] (peças, totem, renascer no §4)
