---
type: adr
status: accepted
created: 2026-10-21
updated: 2026-10-21
tags:
  - adr
  - decisao
  - cepa-selvagem
  - arquitetura
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
deciders: tarciso
supersedes: ""
superseded_by: ""
---

# ADR-0003 — Dano como evento + pilha única de modificadores

## Contexto
Combate, maestria, quebra de partes, loot, IA e status precisam reagir ao mesmo golpe. Se cada sistema chamar o outro direto, o jogo incha e fica acoplado.

## Opções consideradas
1. **Chamadas diretas** (`target.take_damage()` que chama maestria, loot…) — simples no início / acoplamento cresce a cada sistema.
2. **`HitEvent` resolvido num pipeline central + sinais; stats como pilha de `ModifierData`** — sistemas independentes, uma regra para buff/item/maestria/gene / um pouco mais de estrutura inicial.

## Decisão
Proposta: **opção 2.**
- Todo dano vira `HitEvent` → `CombatResolver` → sinais (`damage_dealt`, `damage_mitigated`, `part_broken`, `poise_broken`).
- Todo ajuste de stat (item, buff, maestria, gene, terreno) é `ModifierData` com `source`.
- Golpe, magia, ataque de monstro e ferramenta de coleta são `AbilityData`.

## Consequências
- Positivas: novo sistema = novo ouvinte, sem mexer nos antigos. Monstros e jogadores compartilham código.
- Negativas / riscos: depurar fluxo por sinais é menos direto; precisa de log de eventos desde o B06.
- O que muda: base de todo o código de gameplay.

## Referências
- [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01]] · [[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]]
