---
type: block
status: done
created: 2026-10-21
updated: 2026-10-21
tags:
  - bloco
  - gdd
  - economia
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
agent: labu
---

# B05 — GDD: economia e Mercado Negro

## Objetivo
Mapear todas as torneiras (entrada de valor) e ralos (destruição) e definir como o Mercado Negro equilibra os dois.

## Critérios de pronto
- [x] Tabela de torneiras e ralos (loot, coleta, durabilidade, morte, taxas, Mercado Negro) → [[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05 §1]].
- [x] Mercado de jogadores: ordens de compra/venda, taxas, mercados por cidade? → [[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05 §2]].
- [x] Mercado Negro: o que compra, como define preço, para onde vão os itens → [[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05 §3]].
- [x] Perda de itens na morte e zonas: duelo perde só a aposta; zona de PvP aberto é full loot (GDD-05 §4).
- [x] Regras da Zona Selvagem: tudo equipado cai, parte destruída, durabilidade perdida, 1 min de prioridade para quem matou.
- [x] Aposta de duelo: sem taxa, máximo 10% do dinheiro do personagem.
- [x] Zona Selvagem: equipado + inventário caem; saco fica até 3 h; morte para monstro = Caído, sem perda de item.
- [x] Propostas do Labu aceitas: fórmula de destruição, 15% das pilhas, −10% de durabilidade por morte, Caído 30 s / 25% Vida, crédito de abate 30 s.
- [x] Vault atualizado.

## Contexto
- [[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05 — Economia e multiplayer]]
- [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06 — Materiais e forja]]

## Próximo passo (uma frase)
B05 concluído; GDD dos 5 pilares 100% fechado! B06 ativado para formalizar e expandir a arquitetura técnica no Godot.

## Log
- 2026-10-21 — bloco criado.
- 2026-10-21 — Tarciso decidiu: duelo pode ter aposta em dinheiro (quem morre perde o valor apostado); zonas de PvP aberto são full loot.
- 2026-10-21 — Detalhes: aposta sem taxa, teto de 10% do dinheiro do personagem. Zonas de PvP aberto se chamam **Zona Selvagem**: tudo equipado cai, parte é destruída (estilo Albion), itens perdem durabilidade, quem matou tem 1 min de prioridade no saque.
- 2026-10-21 — Full loot é equipado + inventário (itens vinculados ficam para depois). Saco fica até 3 h. Morte para monstro na Zona Selvagem só deixa Caído; para jogador, perde tudo. Durabilidade: perda padrão por morte. Labu propôs fórmula de destruição e valores.
- 2026-10-21 — Tarciso aceitou todas as propostas: destruição 20% + 40% × desgaste, pilhas −15%, −10% de durabilidade por morte, Caído 30 s / 25% Vida, crédito de abate 30 s.
- 2026-10-21 — bloco ativado após conclusão do B04.
- 2026-10-21 — decisões de economia aprovadas pelo Tarciso: tabela mestra de torneiras e ralos fechada, mercados locais isolados com ordens de compra/venda (2% listagem, 4% taxa), Mercado Negro com precificação dinâmica por escassez abastecendo baús mundiais, e morte em áreas seguras sem perda de itens. GDD-05 completo; B05 concluído.
