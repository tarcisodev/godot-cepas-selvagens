---
type: adr
status: accepted
created: 2026-10-21
updated: 2026-10-21
tags:
  - adr
  - decisao
  - cepa-selvagem
  - rede
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
deciders: tarciso
supersedes: ""
superseded_by: ""
---

# ADR-0002 — Servidor autoritativo desde o vertical slice

## Contexto
É um MMO com mercado 100% de jogadores. Se o cliente decide acerto, XP ou loot, a economia quebra. Refatorar single-player para servidor autoritativo depois custa muito.

## Opções consideradas
1. **Slice single-player puro, rede depois** — mais rápido agora / reescrita grande depois.
2. **Slice já separado em servidor + cliente (os dois na mesma máquina, host local)** — um pouco mais lento agora / arquitetura certa desde o início.

## Decisão
Proposta: **opção 2.** O cliente prevê movimento e animação; o servidor resolve dano, quebra de parte, XP e loot. No slice, servidor e cliente rodam no mesmo processo/máquina (MultiplayerAPI do Godot, host local).

## Consequências
- Positivas: o código de combate já nasce correto para multiplayer.
- Negativas / riscos: mais complexidade no B06; servidor MMO de verdade (escala) continua fora de escopo.
- O que muda: `CombatResolver`, `MasteryService` e `LootService` só rodam no servidor.

## Referências
- [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01 §7]] · [[03-Projects/Cepa-Selvagem/blocos/B06-arquitetura-tecnica-godot|B06]]
