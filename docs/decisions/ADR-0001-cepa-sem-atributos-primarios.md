---
type: adr
status: accepted
created: 2026-10-21
updated: 2026-10-21
tags:
  - adr
  - decisao
  - cepa-selvagem
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
deciders: tarciso
supersedes: ""
superseded_by: ""
---

# ADR-0001 — Cepa Selvagem sem atributos primários

## Contexto
O jogo não tem nível de personagem nem classe fixa: evolui pelo uso e a classe é definida pelos itens. Atributos primários (FOR/INT/AGI…) pedem pontos para distribuir, que não existem nesse modelo.

## Opções consideradas
1. **Atributos primários que sobem com o uso** (estilo Skyrim antigo) — familiar / duplica a maestria e cria um segundo eixo de balanceamento.
2. **Sem atributos primários; poder vem de equipamento + maestria + consumíveis** — um eixo só de balanceamento, valoriza o crafting / menos "identidade" fixa do personagem.

## Decisão
Proposta: **opção 2.** Stats são calculados por uma pilha de modificadores (ver [[08-Knowledge/decisions/ADR-0003-cepa-dano-como-evento|ADR-0003]]).

## Consequências
- Positivas: balanceamento passa pelos itens, que são feitos por jogadores → reforça economia e caça.
- Negativas / riscos: precisa de uma maestria com recompensas que deem sensação de crescimento pessoal.
- O que muda: `StatsComponent` sem atributos base além dos valores padrão da espécie/raça.

## Referências
- [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01]] · [[03-Projects/Cepa-Selvagem/notas/GDD-02-Progressao-por-uso|GDD-02]]
