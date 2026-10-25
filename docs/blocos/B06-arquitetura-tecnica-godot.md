---
type: block
status: done
created: 2026-10-21
updated: 2026-10-21
tags:
  - bloco
  - godot
  - arquitetura
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
agent: atlas
---

# B06 — Arquitetura técnica no Godot

## Objetivo
Transformar as decisões do GDD em estrutura de pastas, convenções de Resource/componente e esqueleto de rede, sem gameplay ainda.

## Critérios de pronto
- [x] Git iniciado no repo (com OK do Tarciso).
- [x] Estrutura de pastas definida (`scripts/core/`, `scripts/components/`, `scripts/data/`, `scripts/systems/`, `tests/`) e o protótipo atual encaixado nela.
- [x] Convenções: naming de Resources (`ModifierData`, `HitEvent`, `DamageType`, `AbilityData`), sinais no `EventBus`.
- [x] Esqueleto de rede conforme [[08-Knowledge/decisions/ADR-0002-cepa-servidor-autoritativo|ADR-0002]] (`NetworkManager` com suporte a host local autoritativo e ENet).
- [x] `StatsComponent` + `ModifierData` com teste simples e `PoolsComponent` integrado.
- [x] Vault atualizado.

## Contexto
- [[03-Projects/Cepa-Selvagem/notas/GDD-01-Combate-e-magia|GDD-01]] (componentes)
- Protótipo: `E:\dev\game-ia\godot-cepas-selvagens`

## Próximo passo (uma frase)
B06 concluído; B07 ativado para o Vertical Slice jogável (caçar criatura com partes quebráveis e forjar equipamento com os materiais).

## Log
- 2026-10-21 — bloco criado.
- 2026-10-21 — Git inicializado com commit raiz. Criados Resources puros (`ModifierData`, `DamageType`, `HitEvent`, `AbilityData`), `StatsComponent` (fórmula de modificadores e cache), `PoolsComponent` (Vida, Éter, Vigor, Postura) e `CombatResolver` (mitigação e dano a postura). Teste unitário headless passando 100%. Integrado ao Player (esquiva com tecla C, consumo de vigor) e barras de Vida/Vigor/Postura no HUD.
- 2026-10-21 — Esqueleto de rede autoritativo (`NetworkManager` com `MultiplayerAPI` e ENet loopback) e `AnatomyComponent` implementados conforme ADR-0002 e GDD-03. Autoload registrado no `project.godot`. Bateria de testes em `test_network_and_architecture.gd` e `test_stats_and_combat.gd` passando 100% no Godot 4.7 headless. B06 concluído.
