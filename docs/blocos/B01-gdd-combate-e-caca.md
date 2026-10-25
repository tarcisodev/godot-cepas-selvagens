---
type: block
status: done
created: 2026-10-21
updated: 2026-10-21
tags:
  - bloco
  - gdd
  - combate
  - caca
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
agent: labu
---

# B01 — GDD: combate e caça anatômica (Pilares 1+3)

## Objetivo
Fechar no papel a arquitetura de atributos, habilidades, mira, pipeline de dano e partes de criatura, com todas as perguntas em aberto respondidas pelo Tarciso.

## Critérios de pronto
- [x] [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01]] escrito (stats, fases, mobilidade, mira, pipeline de dano).
- [x] [[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]] escrito (BodyPart, estados de quebra, loot condicional).
- [x] Perguntas em aberto do GDD-01 respondidas (câmera, controle, recursos, esquiva, slots, fogo amigo, PvP, tipos de dano) → GDD-01 §8.
- [x] Perguntas em aberto do GDD-03 respondidas (captura, coleta, reserva de loot, decepar, partes por porte, regeneração) → GDD-03 §8.
- [x] ADR-0001, 0002 e 0003 → `accepted` ou `rejected`.
- [x] Vault atualizado (log + próximo bloco ativo).

## Contexto
- [[03-Projects/Cepa-Selvagem/notas/GDD-00-Visao-e-pilares|GDD-00 — Visão e pilares]]
- [[08-Knowledge/decisions/ADR-0001-cepa-sem-atributos-primarios|ADR-0001]] · [[08-Knowledge/decisions/ADR-0002-cepa-servidor-autoritativo|ADR-0002]] · [[08-Knowledge/decisions/ADR-0003-cepa-dano-como-evento|ADR-0003]]

## Handoffs
- _(nenhum; trabalho de design com o Tarciso)_

## Próximo passo (uma frase)
B01 concluído; B02 ativado para desenhar o sistema de materiais, receitas e forja.

## Log
- 2026-10-21 — bloco criado e ativado; GDD-01 e GDD-03 escritos.
- 2026-10-21 — perguntas do GDD-01 fechadas: todas as recomendações aceitas. Tarciso acrescentou o PvP: duelo consensual como base; PvP aberto só em mapas e momentos liberados (registrado no GDD-01 §8 e no GDD-05).
- 2026-10-21 — perguntas do GDD-03 fechadas: todas as recomendações aceitas (captura como única fonte de partes Íntegras, esfola manual de ~3 s por parte, reserva de loot única, partes por porte, criaturas veteranas Cicatrizadas). Faltam só as ADRs.
- 2026-10-21 — ADR-0001, ADR-0002 e ADR-0003 aceitas pelo Tarciso; B01 concluído com sucesso e B02 ativado.
