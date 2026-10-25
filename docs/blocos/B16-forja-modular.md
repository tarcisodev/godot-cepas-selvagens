---
type: block
status: done
created: 2026-10-22
updated: 2026-10-22
tags:
  - bloco
  - godot
  - forja
  - equipamento
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B16 — Forja modular com materiais de caça

## Objetivo
Implementar o [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06 §6]]: itens forjados na bigorna com núcleo, revestimento e tempero; qualidade, traits, durabilidade, Carga, reparo e desmanche; peças visíveis no personagem. O Tarciso autorizou seguir sem decisão dele.

## Critérios de pronto
- [x] `ForgedItem` (qualidade, traits, durabilidade, encaixe) e receitas do §6.
- [x] Equipar/desequipar por encaixe aplicando modificadores; durabilidade e quebra.
- [x] Tela de forja na bigorna: escolher a pilha de cada slot, prévia da qualidade, forjar, reparar, desmanchar.
- [x] Peças visíveis no corpo.
- [x] Save, testes e prints.

## Próximo passo (uma frase)
Tarciso forjar as 4 peças jogando e ajustar efeitos, Carga e custo de reparo; depois armas forjadas (a Lança do GDD-06 §5) ligadas aos estilos do B10.

## Log
- 2026-10-22 — Bloco criado (Claude), design no GDD-06 §6.
- 2026-10-22 — Implementado (Claude, sem decisão do Tarciso, como autorizado). `ForgedItem` (encaixe, ★, traits, durabilidade, materiais), `Forge` (4 receitas do GDD-06 §6, prévia, qualidade ponderada com núcleo peso 2, crítico 0,4%/nível + 10% da Forja Pública, tempero na forja 10, reparo 5 $S + 1 do revestimento com −4% do máximo, desmanche 40% com −1★). `InventoryComponent`: peças, um item por encaixe, efeitos no StatsComponent por fonte de encaixe, desgaste (−1 por golpe, −10% do máximo na queda; quebrado não protege mas pesa), save das peças. `ForgeScreen` na bigorna do acampamento ([E]; o [Tab] só forja perto dela). `GearVisual`: elmo com chifre, capuz de penas, gibão com cinto e braçadeiras com espinho, presos aos ossos pela pose de descanso; iridescente brilha. O elmo antigo virou atalho da receita nova. Teste `tests/test_forge.gd`; runner 20/20.
