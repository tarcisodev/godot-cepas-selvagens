---
type: block
status: done
created: 2026-10-26
updated: 2026-10-26
tags:
  - bloco
  - caravanas
  - comercio
  - rotas
  - fardos
  - escolta
  - logistica
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
agent: labu
---

# B33 — Rotas Comerciais de Caravanas, Fardos de Carga & Escolta entre Assentamentos

## Objetivo
Implementar o sistema de rotas comerciais físicas, fardos de carga regionais, flutuação de oferta e demanda, bloqueio de viagem rápida com carga pesada e eventos de escolta/emboscada de caravanas entre os 4 assentamentos do vale (GDD-05 §2, §5; GDD-11; GDD-08 §6):

1. **Fardos Comerciais Regionais (`TradePackData`):**
   - Cada assentamento produz uma especialidade local comercial:
     - **Porto Bruma:** `&"fardo_pescado"` (*Fardo de Pescado Salgado e Óleo Purificado*, compra por 25 $S).
     - **Vigia do Norte:** `&"fardo_madeira_nobre"` (*Fardo de Madeira da Serra e Resina*, compra por 25 $S).
     - **Santuário Astral:** `&"fardo_astral"` (*Fardo de Quartzo-Lume e Essência Celeste*, compra por 30 $S).
     - **Vila da Esperança:** `&"fardo_manufatura"` (*Fardo de Ferramentas de Forja e Refeições*, compra por 20 $S).
   - Possuem peso (18 kg), qualidade (1★ a 3★) e traits mercantis (`selecionado`, `fino`).

2. **Cálculo de Preço & Lucro por Distância e Demanda:**
   - Fórmula: `valor_venda = (base_buy_price + (distancia_percorrida * 0.25)) * multiplicador_demanda * bonus_qualidade`.
   - Rotas longas (como Porto Bruma ➔ Vigia do Norte, ~141m de travessia) rendem lucros substanciais (+40 a +55 $S líquidos e reputação regional).
   - Devolução na mesma cidade de origem: 80% do valor (sem lucro/com taxa de devolução).
   - Saturação orgânica: a entrega de fardos em um destino reduz levemente o multiplicador de demanda local, estimulando os comerciantes a variar rotas. O tempo recupera a demanda gradualmente em direção à cotação base da região (`advance_time`).

3. **Logística e Risco no Mundo Aberto (GDD-05 §2):**
   - **Bloqueio de Viagem Rápida:** Carregar um fardo comercial nas costas ou na montaria impede expressamente a Viagem Rápida (`fast_travel_to`), forçando a travessia física a pé ou em montaria terrestre pelas estradas do vale.
   - **Prop Físico no Mundo (`WorldTradePack`):** Se o jogador soltar a carga ou cair em combate, o fardo é depositado no chão como uma caixa de madeira com cintas de cânhamo e prompt `[E] Carregar Fardo`, permitindo resgate ou saque público.

4. **Caravana Itinerante & Escolta Armada (`CaravanConvoy`):**
   - Comboio de carroça com animais de carga que viaja em marcha real entre assentamentos seguindo waypoints pelas estradas.
   - O jogador pode se alistar como escolta militar (`add_escort_player`).
   - **Eventos de Emboscada:** Ao passar perto de zonas perigosas (como a Arena de Monstros ou Covil da Besta), o comboio pode sofrer emboscada por salteadores ou predadores (`UNDER_ATTACK`).
   - Ao repelir a ameaça e conduzir a caravana segura ao entreposto final (`ARRIVED`), todos os escoltas recebem pagamento de contrato (+40 $S) e reputação da vila.
   - Caso o comboio seja destruído sem proteção (`DESTROYED`), as cargas são perdidas.

5. **Interface do Entreposto Comercial (`TradeRouteScreen`):**
   - Tela completa exibindo o fardo atualmente carregado (com valor de venda e lucro líquido em tempo real), catálogo de fardos disponíveis para compra local e tabela com cotações de mercado e distâncias para todos os outros entrepostos.

---

## Critérios de Pronto
- [x] `scripts/data/trade_pack_data.gd`:
  - Fardos regionais, fórmulas de liquidação por distância, bônus de qualidade e serialização `to_dict` / `from_dict`.
- [x] `scripts/props/world_trade_pack.gd`:
  - Modelo 3D de caixa de carga com amarras e interação física no chão do mundo.
- [x] `scripts/systems/trade_route_manager.gd`:
  - Gerenciador central de rotas, compra e venda de fardos, tabela de demanda regional com recuperação no tempo, cotações em tempo real e bloqueio de Viagem Rápida.
- [x] `scripts/systems/caravan_convoy.gd`:
  - Caravana de carroça móvel, waypoints, emboscadas dinâmicas e distribuição de recompensa de escolta.
- [x] `scripts/world/world_settlements.gd` & `scripts/ui/world_map_screen.gd`:
  - Bloqueio de Viagem Rápida quando o jogador estiver com fardo comercial (`carrying_trade_pack`).
- [x] `scripts/ui/trade_route_screen.gd`:
  - Interface completa do entreposto comercial.
- [x] `tests/test_caravans_and_trade_routes.gd`:
  - 8 suítes completas de testes unitários cobrindo precificação, compra/venda, bloqueio de fast travel, drop/pickup, saturação de mercado, marcha e emboscada de caravana, destruição e UI.

---

## Verificação
Validação executada via Godot 4.7 headless:
```bash
godot --path . --headless -s res://tests/test_caravans_and_trade_routes.gd
```
- **Resultado:** 8/8 testes passaram (100% verde).
- **Suíte Geral:** Todos os 48 arquivos de teste do projeto executados e aprovados.
