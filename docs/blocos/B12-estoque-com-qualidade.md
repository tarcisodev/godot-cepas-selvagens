---
type: block
status: done
created: 2026-10-22
updated: 2026-10-22
tags:
  - bloco
  - godot
  - materiais
  - inventario
owner: tarciso
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
---

# B12 — Estoque de materiais com qualidade (`MaterialData`)

## Objetivo
Fazer o inventário guardar **qual** material o jogador tem, não só quantos: qualidade (1–5★) e traits, como o [[03-Projects/Cepa-Selvagem/notas/GDD-06-Materiais-e-forja|GDD-06 §1]] pede. Destrava o 1★/2★ da coleta ([[03-Projects/Cepa-Selvagem/notas/GDD-08-Territorio-construcao-e-coleta|GDD-08 §8]]) e a forja com herança de traits. Decisão estrutural em [[08-Knowledge/decisions/ADR-0005-cepa-estoque-por-pilha|ADR-0005]] (proposed).

## Situação hoje (2026-10-22)
- `InventoryComponent.materials` é `id → quantidade`. Nenhum `MaterialData` existe no código.
- Qualidade só aparece no **id**: `chifre_integro` e `chifre_lascado` são dois materiais diferentes. O Elmo calcula qualidade 4 ou 2 a partir do id.
- Usam o inventário: coleta, esfola/caça (`dummy_creature`), construção (custo e reembolso), forja do elmo, menu de ações, objetivos e save.

## Proposta (detalhe na ADR-0005)
- **`MaterialData` (Resource)** em `resources/materials/`: `id`, `display_name`, `category`, `icon`, `max_gather_quality`, traits de base. Um `.tres` por material (10 da coleta + chifre, placa de carapaça).
- **Pilha** = mesmo `id` + mesma qualidade + mesmos traits. O inventário vira uma lista de pilhas.
- **API de sempre continua valendo:** `get_material_count(id)` soma todas as pilhas; `consume_materials({id: n})` gasta **da pior qualidade para a melhor** (construção não se importa com estrela). `add_material(id, n)` entra como 1★ sem traits.
- **API nova:** `add_stack(id, n, qualidade, traits)`, `get_stacks(id)`, `consume_stack(pilha, n)` — a forja escolhe a pilha.
- **Chifre:** `chifre_integro`/`chifre_lascado` viram um só `chifre_rinolito`; Íntegro = +1★ e trait conforme o GDD-03/06. O elmo passa a ler a qualidade da pilha.
- **Coleta:** sai 1★; com `coleta`/`mineracao` ≥ 25 há chance de 2★ (proposta: 10% + 0,4% por nível acima de 25, teto 2★).
- **Save:** `materials` vira lista de pilhas; save antigo (`id → n`) carrega como 1★, e `chifre_integro` antigo vira chifre 3★ com o trait de Íntegro.

## Fora do escopo
- Peso/Carga por pilha, durabilidade e desmanche (GDD-06 §4).
- Receita modular completa (núcleo/fixação/tempero) — só o elmo migra.

## Critérios de pronto
- [x] ADR-0005 aceita pelo Tarciso (2026-10-22), com as 3 respostas propostas: pilha por (id, ★, traits); construção gasta a pior qualidade primeiro; curva de 2★ como está.
- [x] `MaterialData` + `.tres` dos 13 materiais (10 da coleta, chifre, placa, tendão).
- [x] `InventoryComponent` com pilhas; contagem, consumo (pior ★ primeiro), `get_stacks`, `consume_stack`, `best_stack`, peso total.
- [x] Coleta rola 1★/2★ pela maestria; chifre quebrado em luta = 2★, esfola cuidadosa = 3★ com trait `integro`.
- [x] Elmo lê qualidade e trait da pilha usada.
- [x] Save com pilhas (sem migração: o Tarciso começa jogo novo).
- [x] Tela de inventário [I] com organizador (raridade, quantidade, peso, cor, nome; inverter), filtro por grupo e borda por raridade ou grupo.
- [x] Runner verde (13/13).
- [x] Commit `22a4284` junto com a sessão de consumíveis (suíte 14/14).

## Perguntas em aberto
1. Aceita **pilha por (id, ★, traits)** em vez de item individual com id próprio (ADR-0005)?
2. Construção gasta a **pior** qualidade primeiro — ou o jogador escolhe?
3. A curva de chance de 2★ na coleta (10% + 0,4%/nível acima de 25) serve como ponto de partida?

## Próximo passo (uma frase)
Tarciso abrir o inventário ([I]) no jogo para aprovar o visual.

## Log
- 2026-10-22 — Bloco criado pelo Claude a partir da pendência do B11 (qualidade 1★/2★ da coleta); ADR-0005 proposta.
- 2026-10-22 — Implementado (Claude). `MaterialData` (scripts/data) com categoria, ícone, cor, peso e teto de coleta; `.tres` em `resources/materials/`. `InventoryComponent` em pilhas; `chifre_integro`/`chifre_lascado` viraram `chifre_rinolito` 3★ com `integro` / 2★; placas e chifre de caça saem 2★. Coleta: `GatherableResource.roll_quality` (10% + 0,4%/nível acima de 25, teto 2★). Save grava a lista de pilhas; sem compatibilidade com save antigo (pedido do Tarciso). **Tela de inventário nova** (`scripts/ui/inventory_screen.gd`, [I] ou botão no menu de ações): grade com borda por raridade ou por grupo (faixa no topo mostra o outro critério), ícone sobre disco na cor do material, ★ e quantidade, ✦ para traits; organizar por raridade, quantidade, peso da pilha, cor (matiz; cinzas no fim) ou nome, com inverter; filtro por grupo com contagem; painel de detalhe com peso unitário/da pilha, traits e descrição; peso total no topo. Emojis Unicode 13+ (🪵🪲🫐🪨🪢) não aparecem no Windows 10 e foram trocados. `tests/test_material_stacks.gd` (4 etapas); runner 13/13. Obs.: a sessão "Sistema de itens e consumíveis" trabalhou ao mesmo tempo no mesmo checkout (categoria Consumível, `use_item`, atalhos 1/2/3 no player, botão Usar na tela).
- 2026-10-22 — Commit `22a4284` (só local) com o B12 e os consumíveis da outra sessão (baú de suprimentos, 8 consumíveis, atalhos [1]/[2]/[3], ajuste de Vigor e respawn). Suíte 14/14; mundo carrega sem erro. Atalhos 1/2/3 não brigam com o modo construção: o `BuildingSystem` trata as teclas antes do player.
- 2026-10-22 — Bloco concluído; a aprovação do visual do inventário jogando fica como pendência do Tarciso.
