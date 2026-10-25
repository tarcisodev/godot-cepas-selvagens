---
type: resource
status: draft
created: 2026-10-21
updated: 2026-10-21
tags:
  - gdd
  - indice
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# GDD-00 — Visão e pilares

> Índice do GDD. Cada sistema tem **uma** nota; as outras linkam. Decisão estrutural vira ADR.

## Visão em uma frase
Sandbox MMORPG / Action RPG de alta magia em que o jogador **caça, cultiva, cria e negocia** num mundo de ecologia viva, e evolui pelo que faz, não por níveis.

## Os 5 pilares

| # | Pilar | Referências | Notas |
|---|---|---|---|
| 1 | Combate e magia de ação: sem auto-ataque, sem target travado; mobilidade no cast depende da magia e do peso do equipamento | Action RPG | [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia\|GDD-01]] · [[03-Projects/Cepa-Selvagem/notas/GDD-12-Equipamento-e-encaixes\|GDD-12]] (encaixes/Albion) |
| 2 | Progressão orgânica: sem níveis; evolui o que se usa; classe = build + itens equipados | Skyrim, Albion | [[03-Projects/Cepa-Selvagem/notas/GDD-02-Progressao-por-uso\|GDD-02]] |
| 3 | Crafting e caça: itens de alto nível só forjados; materiais vêm de loot anatômico | Monster Hunter | [[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica\|GDD-03]] (caça) · [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja\|GDD-06]] (forja) · [[03-Projects/Cepa-Selvagem/notas/GDD-13-Cozinha-e-culinaria\|GDD-13]] (culinária/buffs) |
| 4 | Ecologia, genética e exploração: Modo Foto, catálogo, breeding com mutação, botânica profunda, cartas 3D | Ark, Triple Triad | [[03-Projects/Cepa-Selvagem/notas/GDD-04-Ecologia-e-genetica\|GDD-04]] · [[03-Projects/Cepa-Selvagem/notas/GDD-07-Cartas-colecionaveis-e-minigame\|GDD-07]] · [[03-Projects/Cepa-Selvagem/notas/GDD-09-Criaturas-plantas-procedurais-e-montarias\|GDD-09]] · [[03-Projects/Cepa-Selvagem/notas/GDD-10-Ciclo-natural\|GDD-10]] · [[03-Projects/Cepa-Selvagem/notas/GDD-11-Mapa\|GDD-11]] · [[03-Projects/Cepa-Selvagem/notas/GDD-14-Reproducao-ciclo-de-vida-e-familia\|GDD-14]] (gênero/reprodução) |
| 5 | Economia, território e multiplayer: mercado 100% de jogadores, Mercado Negro do sistema, montarias, guildas | Albion, WoW | [[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia\|GDD-05]] · [[03-Projects/Cepa-Selvagem/notas/GDD-08-Territorio-construcao-e-coleta\|GDD-08]] (território) · [[03-Projects/Cepa-Selvagem/notas/GDD-15-Guildas-territorio-e-uniformes\|GDD-15]] (guildas/uniformes) |

## Princípios de design (valem para todo o GDD)
1. **Um conceito, várias fontes.** Equipamento, buff, maestria e mutação são todos *modificadores* na mesma pilha. Golpe, magia, ataque de monstro e ferramenta de coleta são todos *habilidades*. Ver [[08-Knowledge/decisions/ADR-0003-cepa-dano-como-evento|ADR-0003]].
2. **Sistemas não se chamam, eles escutam eventos.** Combate emite; maestria, loot e IA reagem.
3. **O item é a classe.** Nada de atributo primário ([[08-Knowledge/decisions/ADR-0001-cepa-sem-atributos-primarios|ADR-0001]]).
4. **Como você faz importa, não só se fez.** Caçar bem rende material melhor; isso vira valor no mercado.
5. **Servidor decide o que tem valor** (dano, XP, loot) — [[08-Knowledge/decisions/ADR-0002-cepa-servidor-autoritativo|ADR-0002]].

## Como os pilares se ligam

```
 Genética (4) ──traits──▶ Criatura ──partes──▶ Caça (3) ──material──▶ Forja (3)
      ▲                      ▲                    │                      │
      │                      │                    ▼                      ▼
 Breeding/Botânica     Combate (1) ──XP por uso──▶ Maestria (2)        Item
                                                                         │
                       Mercado Negro ◀── ralo ── Mercado de jogadores (5)◀┘
```

## Glossário rápido
- **Modificador** — ajuste de um stat com origem rastreável (item, buff, maestria, gene).
- **Fase** — trecho de uma habilidade (preparo, canalização, disparo, recuperação) com perfil de mobilidade próprio.
- **Parte** — região de uma criatura com HP, resistências e loot próprios.
- **Carga** — peso equipado ÷ capacidade; reduz a mobilidade durante as fases.
- **Trait** — propriedade herdada (gene → material → item).
