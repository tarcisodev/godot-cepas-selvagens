---
type: block
status: done
created: 2026-10-21
updated: 2026-10-21
tags:
  - bloco
  - godot
  - vertical-slice
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
agent: atlas
---

# B07 — Vertical slice: caçar, quebrar, forjar

## Objetivo
Um loop jogável curto que prova os Pilares 1 e 3 juntos: lutar contra 1 criatura em ação, quebrar uma parte dela, coletar o material e forjar 1 item que muda como você luta.

## Critérios de pronto
- [x] Player com 1 arma melee + 1 cajado (2 habilidades: uma móvel, uma enraizada).
- [x] Peso do equipamento muda a mobilidade durante o cast (dá para sentir trocando armadura).
- [x] 1 criatura com ≥ 3 partes, 1 quebrável que muda o comportamento dela.
- [x] Loot condicional: parte quebrada dá material; parte intacta dá material diferente.
- [x] Forja de 1 capacete com o material; o trait dele aparece nos stats.
- [x] XP de maestria subindo por uso (arma, cajado, armadura).
- [x] Vault atualizado.

## Contexto
- Depende de B01, B02, B03 e B06.
- Código em `E:\dev\game-ia\godot-cepas-selvagens`

## Próximo passo (uma frase)
Vertical slice concluído e 100% validado em testes headless; alinhar com o Tarciso os próximos passos de roadmap do jogo.

## Log
- 2026-10-21 — bloco criado.
- 2026-10-21 — bloco ativado após conclusão e testes bem-sucedidos do B06.
- 2026-10-21 — Vertical slice completo implementado e validado headless (`test_vertical_slice.gd`) com 4/4 suites aprovadas: armas melee vs cajado enraizado, quebra anatômica e loot condicional (Íntegro vs Lascado), forja modular com traits aplicados nos stats, e progressão de maestria por uso. Bloco concluído!
