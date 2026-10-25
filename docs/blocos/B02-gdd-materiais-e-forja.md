---
type: block
status: done
created: 2026-10-21
updated: 2026-10-21
tags:
  - bloco
  - gdd
  - crafting
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
agent: labu
---

# B02 — GDD: material → receita → forja

## Objetivo
Definir como qualidade e traits dos materiais (vindos da caça, mineração e botânica) se combinam numa receita e viram os stats do item forjado.

## Critérios de pronto
- [x] `MaterialData` fechado: tipo, qualidade, traits, origem (criatura/genoma) → [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06 §1]].
- [x] Regra de combinação: como N materiais viram os modificadores do item (média? dominante? slots de trait?) → [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06 §2]].
- [x] Receita: slots obrigatórios vs. livres, papel da maestria do ferreiro → [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06 §3]].
- [x] Durabilidade e destruição de itens (alimenta o B05) → [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06 §4]].
- [x] 3 receitas de exemplo ponta a ponta (criatura → parte → material → item) → [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06 §5]].
- [x] Vault atualizado.

## Contexto
- Entrada: [[03-Projects/Cepa-Selvagem/notas/GDD-03-Caca-anatomica|GDD-03]] (seção "Ponte para o crafting").
- Nota gerada: [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06 — Materiais e forja]].
- Saída usada por: [[03-Projects/Cepa-Selvagem/notas/GDD-05-Economia|GDD-05]] e [[03-Projects/Cepa-Selvagem/blocos/B03-gdd-progressao-por-uso|B03]].

## Próximo passo (uma frase)
B02 concluído; B03 ativado para definir a progressão por uso (maestria).

## Log
- 2026-10-21 — bloco criado.
- 2026-10-21 — bloco ativado após fechamento e aprovação do B01 (ADRs 0001, 0002 e 0003 aceitas).
- 2026-10-21 — regras de MaterialData, combinação por média ponderada, receita modular (núcleo, fixação, tempero), desgaste de reparo e 3 receitas de exemplo aprovadas pelo Tarciso; GDD-06 escrito; B02 concluído.
