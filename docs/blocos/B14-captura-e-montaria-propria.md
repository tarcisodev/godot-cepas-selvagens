---
type: block
status: done
created: 2026-10-22
updated: 2026-10-22
tags:
  - bloco
  - godot
  - caca
  - captura
  - montarias
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B14 — Captura e montaria própria

## Objetivo
Implementar o [[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03 §9]]: os bichos procedurais viram caça; captura em 3 passos (cansar → laço → sedativo); depois, abate Íntegro ou levar ao estábulo como montaria própria com o DNA do bicho.

## Critérios de pronto
- [x] Trotador, Planador e Saltarelo com Vida, hurtbox, partes e esfola.
- [x] Estado Exausto (< 20% Vida) com recuperação em 30 s.
- [x] Laço de Fibra e Sedativo de Erva: receitas, uso pela roda rápida, regras de alcance e canal.
- [x] Escolha pós-captura: abate Íntegro ou estábulo.
- [x] Montaria própria com velocidade pelo gene porte; entra no save.
- [x] Testes e prints.

## Próximo passo (uma frase)
Tarciso caçar e capturar um Trotador jogando; ajustar vida dos bichos, tempos (Exausto 30 s, laço 20 s, sedativo 3 s) e receitas.

## Log
- 2026-10-22 — Bloco criado (Claude) com a proposta de captura.
- 2026-10-22 — Proposta aceita pelo Tarciso: bichos só fogem; montaria capturada convive com as de teste; até 3 por personagem.
- 2026-10-22 — Implementado (Claude). `WildCreature` com Vida (Trotador 120, Planador 90, Saltarelo 25, escalada pelo porte), hurtbox, fuga ao apanhar, Exausto abaixo de 20% (recupera em 30 s), preso pelo laço (20 s, corda visível), sedação de 3 s parado (dano cancela), corpo esfolável (chifre-galhado, couro, carne, pena, pele; 2★, ou 3★ Íntegro no abate cuidadoso; mutante leva trait `iridescente`). Ferramentas `laco_fibra` e `sedativo_erva` (`MaterialData.tool_action`), feitas no [Tab] e usadas pela roda rápida; Alquimista vende o sedativo (12 $S). `CaptureDialog`: abate cuidadoso, estábulo (até 3, só Trotador/Planador) ou soltar. Montaria própria com o DNA do bicho e velocidade pelo porte (TT 100%, Tt 92%, tt 85%); entra no save. Bichos mortos/capturados renascem em 90 s. Teste `tests/test_capture.gd`; runner 18/18; fluxo conferido no mundo. FPS 113 (era 127; rótulos e hurtboxes dos bichos).
