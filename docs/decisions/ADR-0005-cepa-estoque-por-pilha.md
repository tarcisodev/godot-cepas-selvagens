---
type: adr
status: accepted
created: 2026-10-22
updated: 2026-10-22
tags:
  - adr
  - decisao
  - cepa-selvagem
  - materiais
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
deciders: tarciso
supersedes: ""
superseded_by: ""
---

# ADR-0005 — Materiais guardados em pilhas por (id, qualidade, traits)

## Contexto
O [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06]] diz que o material "não é apenas um ID numérico com quantidade": carrega qualidade (1–5★) e traits (genéticos, Cicatrizado). O código guarda só `id → quantidade`, e a qualidade do chifre está escondida no id (`chifre_integro` / `chifre_lascado`). O [[03-Projects/Cepa-Selvagem/notas/GDD-08-Territorio-construcao-e-coleta|GDD-08]] decidiu que a coleta sai 1★ ou 2★, o que o inventário atual não consegue guardar. Construção e receitas simples pedem "N de madeira" sem ligar para estrela; a forja precisa escolher a pilha exata.

## Opções consideradas
1. **Qualidade no id** (`madeira_1`, `madeira_2`…): nada muda no inventário, mas multiplica ids, os custos de construção não sabem somar e traits ficam impossíveis.
2. **Pilha por (id, qualidade, traits)**: unidades iguais se juntam; diferentes ficam em pilhas separadas. Soma por id continua fácil.
3. **Item individual** (cada unidade com id único, como equipamento): máxima rastreabilidade, mas pesado para 50 galhos e para a rede.

## Decisão
**Opção 2** (aceita pelo Tarciso em 2026-10-22).
- `MaterialData` (Resource) descreve o **tipo** de material (id, nome, categoria, ícone, traits de base). A **pilha** guarda o estado: `{id, quality, traits (ordenados), amount}`.
- Duas unidades só se juntam se id, qualidade e traits forem iguais.
- Pedido genérico (`consume_materials({id: n})`, usado por construção e custos simples) gasta da **pior qualidade para a melhor**. Receitas da forja usam a pilha escolhida.
- `get_material_count(id)` soma as pilhas, para o código atual seguir funcionando.
- Save e rede trafegam a lista de pilhas; o formato antigo é migrado como 1★.

## Consequências
- Positivas: GDD-06 e GDD-08 cabem sem inventar ids; código que só conta material não muda; pilha é pequena para save e rede (ADR-0002).
- Negativas / riscos: ordem e igualdade de traits precisam ser canônicas (ordenar) senão as pilhas não se juntam; a UI precisa mostrar várias pilhas do mesmo material.
- O que muda: `InventoryComponent`, forja do elmo, esfola (`chifre_integro`/`chifre_lascado` viram um só id com qualidade), coleta e `SaveGame`.

## Referências
- [[03-Projects/Cepa-Selvagem/blocos/B12-estoque-com-qualidade|B12]]
- [[03-Projects/Cepa-Selvagem/blocos/B11-cidade-construcao-e-coleta|B11]]
