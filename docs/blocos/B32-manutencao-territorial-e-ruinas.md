---
type: block
status: done
created: 2026-10-26
updated: 2026-10-26
tags:
  - bloco
  - territorio
  - rancho
  - manutencao
  - cofre
  - ruinas
  - desmanche
owner: labu
project: "[[03-Projects/Cepa-Selvagem/00-Project|Cepa-Selvagem]]"
agent: labu
---

# B32 — Manutenção Territorial do Rancho, Cofre de Proteção, Ruínas & Desmanche Público

## Objetivo
Implementar o sistema de manutenção territorial contínua, cofre de proteção com débito diário, tolerância de carência, decaimento em ruína abandonada e desmanche público para reciclagem de sucata (GDD-08 §4, §8 Decisão 7, GDD-05 §1 e §5):

1. **Cofre de Proteção Territorial (`ClaimTotem`):**
   - Atua como centro do rancho e estaca de reivindicação de base e guilda;
   - Possui cofre integrado de Dólares de Sucata (`maintenance_funds`, capacidade máxima `MAX_FUNDS = 250` $S, correspondendo a até 50 dias de proteção pré-paga);
   - Custo diário de manutenção de `DAILY_UPKEEP = 5` $S por dia de jogo (atuando como ralo de moeda contínuo da economia, conforme GDD-05 §1);
   - Métodos seguros de depósito (`deposit_maintenance`) e retirada exclusiva pelo proprietário (`withdraw_maintenance`), integrados diretamente com a carteira do jogador (`WalletComponent`).

2. **Ciclo de Estados e Decaimento em Ruína (`Status`):**
   - **`Status.ACTIVE` (🟢 Protegido):** Cofre abastecido (> 0 $S). A base permanece 100% indestrutível fora da Zona Selvagem. Cristal de topo emite brilho esmeralda brilhante (`Color(0.15, 0.95, 0.65)`), anel perimétrico ciano translúcido. Apenas o proprietário e jogadores na whitelist podem construir.
   - **`Status.VULNERABLE` (🟡 Vulnerável):** Cofre zerado (0 $S), mas dentro do período de carência (`grace_days_elapsed < GRACE_PERIOD_DAYS = 3.0` dias). Cristal emite brilho âmbar de advertência (`Color(0.95, 0.6, 0.1)`). Novas construções ficam temporariamente congeladas até o reabastecimento. Depositar $S a qualquer momento restaura `ACTIVE` e zera a carência.
   - **`Status.ABANDONED` (🔴 Ruína Abandonada):** Carência esgotada (≥ 3.0 dias sem fundos). O rancho decai oficialmente em ruínas públicas. Cristal apagado/rubro escurecido (`Color(0.3, 0.05, 0.05)`). A demarcação territorial perde a exclusividade.

3. **Desmanche Público & Saque de Ruínas (GDD-08 §8 Decisão 7):**
   - Qualquer jogador visitante pode desmontar peças e totens de territórios abandonados (`can_player_dismantle(p_name) == true`);
   - Reembolso de sucata configurado em 25% dos materiais de custo original (`fraction = 0.25`, mínimo 1 unidade de cada recurso), entregues diretamente no inventário do saqueador;
   - Serve como mecanismo orgânico de limpeza do mapa contra bases mortas/inativas e reciclagem econômica de insumos.

4. **Whitelist de Construtores (Amigos e Guilda):**
   - Lista gerenciável de jogadores autorizados a construir e interagir no rancho (`allowed_builders: Array[String]`);
   - Métodos `add_allowed_builder` e `remove_allowed_builder`;
   - ZoneManager valida a permissão via `claim.can_player_build(player_name)`.

5. **Interface Gráfica do Totem (`TerritoryScreen`):**
   - Modal com design estilizado escuro e detalhes em dourado e verde;
   - Status badge do rancho (Protegido / Vulnerável / Ruína Abandonada) e previsão de dias restantes de cobertura;
   - Barra de fundos do cofre e botões de depósito rápido (`+10 $S`, `+25 $S`, `+50 $S`, `Completar Cofre`) e retirada;
   - Gerenciador visual da whitelist de amigos;
   - Botão contextual de Desmanche de Rancho ou Saque Público de Ruína.

6. **Persistência Completa (`to_dict` / `from_dict`):**
   - `BuildingSystem.collect_structures` e `restore_structures` serializam e recuperam fundos de manutenção, status, dias de carência e whitelist de construtores sem perdas.

---

## Critérios de Pronto
- [x] `scripts/claim_totem.gd`:
  - Constantes `DAILY_UPKEEP = 5`, `MAX_FUNDS = 250`, `GRACE_PERIOD_DAYS = 3.0`;
  - Enum `Status { ACTIVE, VULNERABLE, ABANDONED }`;
  - Cofre `maintenance_funds` e controle de carência `grace_days_elapsed`;
  - Métodos `deposit_maintenance`, `withdraw_maintenance`, `advance_days`, `can_player_build`, `can_player_dismantle`;
  - Gerenciamento de whitelist (`add_allowed_builder`, `remove_allowed_builder`);
  - Atualização visual reativa do cristal, luz e anel perimétrico conforme status;
  - Serialização `to_dict` e `from_dict`.
- [x] `scripts/buildable_piece.gd`:
  - `dismantle(player, is_ruin)` e `refund_costs(costs, placed_at, player, is_ruin)` suportando 25% de sucata para ruínas.
- [x] `scripts/building_system.gd`:
  - `try_dismantle_at` permitindo que qualquer jogador desmonte peças em territórios abandonados com 25% de sucata;
  - Suporte a `player: Node` e integração com inventário;
  - Serialização e restauração do totem e suas estruturas.
- [x] `scripts/core/zone_manager.gd`:
  - Validação de `claim.can_player_build(player_name)`;
  - Mensagens claras de bloqueio para territórios vulneráveis e ruínas abandonadas.
- [x] `scripts/ui/territory_screen.gd`:
  - Tela completa de gerenciamento do cofre e território do rancho.
- [x] `tests/test_territory_and_maintenance.gd`:
  - Suíte completa com 9 testes unitários cobrindo estado inicial, depósitos/saques, débitos por passagem de tempo, carência e abandono, recuperação por depósito, permissões e whitelist, desmanche público de ruínas com 25% sucata, persistência e UI.

---

## Verificação
Validação executada via Godot 4.7 headless:
```bash
godot --path . --headless -s res://tests/test_territory_and_maintenance.gd
```
- **Resultado:** 9/9 testes passaram (100% verde).
- **Suíte Geral:** Todos os 47 arquivos de teste do projeto executados e aprovados.
